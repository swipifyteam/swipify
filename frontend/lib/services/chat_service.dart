import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swipify/models/chat_model.dart';
import 'package:swipify/models/message_model.dart';
import 'package:swipify/services/api_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate a deterministic chat ID based on buyer, seller, and optional product.
  String generateChatId(String buyerId, String sellerId, {String? productId}) {
    // To ensure consistency, always put buyer first, then seller.
    if (productId != null && productId.isNotEmpty) {
      return '$buyerId*$sellerId*$productId';
    }
    return '$buyerId*$sellerId';
  }

  /// Create a chat if it doesn't exist, or return the existing chat ID.
  Future<String> createOrGetChat({
    required String buyerId,
    required String sellerId,
    String? productId,
    String? productName,
    String? productImage,
    String? orderId,
  }) async {
    final chatId = generateChatId(buyerId, sellerId, productId: productId);
    final chatDoc = _firestore.collection('chats').doc(chatId);

    final snapshot = await chatDoc.get();

    if (!snapshot.exists) {
      // Fetch buyer and seller names
      String buyerName = 'Unknown User';
      String sellerName = 'Unknown Store';

      try {
        final buyerDoc = await _firestore.collection('users').doc(buyerId).get();
        if (buyerDoc.exists) {
          buyerName = buyerDoc.data()?['name'] ?? 'Unknown User';
        }

        final sellerDoc = await _firestore.collection('sellers').doc(sellerId).get();
        if (sellerDoc.exists) {
          sellerName = sellerDoc.data()?['storeName'] ?? 'Unknown Store';
        }
      } catch (e) {
        print('Error fetching user names for chat: $e');
      }

      final chatModel = ChatModel(
        chatId: chatId,
        buyerId: buyerId,
        sellerId: sellerId,
        productId: productId,
        productName: productName,
        productImage: productImage,
        orderId: orderId,
        lastMessage: '',
        lastMessageTime: DateTime.now(),
        lastSenderId: '',
        participants: [buyerId, sellerId],
        unreadCount: {buyerId: 0, sellerId: 0},
        createdAt: DateTime.now(),
        buyerName: buyerName,
        sellerName: sellerName,
      );

      await chatDoc.set(chatModel.toMap());
    } else {
      // Update existing chat with product info if missing
      final data = snapshot.data() as Map<String, dynamic>;
      if (productId != null && (data['product_name'] == null || data['product_image'] == null)) {
        await chatDoc.update({
          'product_id': productId,
          'product_name': productName,
          'product_image': productImage,
        });
      }
    }

    return chatId;
  }

  /// Get stream of chats for a specific user (buyer or seller).
  Stream<List<ChatModel>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('last_message_time', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChatModel.fromFirestore(doc)).toList();
    });
  }

  /// Get stream of messages for a specific chat.
  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList();
    });
  }

  /// Get messages once (not a stream).
  Future<List<MessageModel>> getMessagesOnce(String chatId) async {
    final snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();
    return snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList();
  }

  /// Send a message in a chat.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String message,
    required String type, // 'text', 'image', 'video'
    String? mediaUrl,
    required String senderName,
  }) async {
    final chatDoc = _firestore.collection('chats').doc(chatId);
    final messagesCollection = chatDoc.collection('messages');

    final messageModel = MessageModel(
      messageId: '', // Set by Firestore auto-ID
      senderId: senderId,
      receiverId: receiverId,
      message: message,
      type: type,
      mediaUrl: mediaUrl,
      createdAt: DateTime.now(),
      status: 'sent',
    );

    // 1. Add message
    await messagesCollection.add(messageModel.toMap());

    // 2. Update chat metadata and increment unread count for receiver
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(chatDoc);
      if (!snapshot.exists) return;

      Map<String, dynamic> unreadCount = Map<String, dynamic>.from(snapshot.data()?['unread_count'] ?? {});
      unreadCount[receiverId] = (unreadCount[receiverId] ?? 0) + 1;

      transaction.update(chatDoc, {
        'last_message': type == 'text' ? message : (type == 'image' ? '📷 Image' : '📹 Video'),
        'last_message_time': FieldValue.serverTimestamp(),
        'last_sender_id': senderId,
        'unread_count': unreadCount,
      });
    });

    // 3. Trigger FCM Notification via backend API
    // Fire and forget (don't await so UI doesn't block)
    ApiService.sendChatNotification(
      receiverId: receiverId,
      senderName: senderName,
      message: type == 'text' ? message : (type == 'image' ? '📷 Image' : '📹 Video'),
    ).catchError((e) => print('Notification error: $e'));
  }

  /// Mark all messages sent by [otherUserId] in this chat as delivered.
  /// Typically called when [currentUserId] receives a message stream update but hasn't opened the chat yet.
  /// Actually, it's better to just mark messages as delivered if receiver opens the app or is active.
  /// The user requested: "IF receiver opens chat: -> update all messages: status = 'delivered'".
  /// Wait, if they open the chat, it should be 'seen'. 
  /// Let's implement markAsSeen when inside chat, and markAsDelivered if they just fetch it.
  Future<void> markMessagesAsDelivered(String chatId, String currentUserId) async {
    final messagesQuery = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiver_id', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'sent')
        .get();

    if (messagesQuery.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in messagesQuery.docs) {
      batch.update(doc.reference, {'status': 'delivered'});
    }
    await batch.commit();
  }

  /// Mark all messages sent by [otherUserId] as seen when [currentUserId] opens the chat.
  Future<void> markMessagesAsSeen(String chatId, String currentUserId) async {
    // Update messages status
    final messagesQuery = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiver_id', isEqualTo: currentUserId)
        .where('status', whereIn: ['sent', 'delivered'])
        .get();

    final batch = _firestore.batch();
    for (var doc in messagesQuery.docs) {
      batch.update(doc.reference, {'status': 'seen'});
    }
    await batch.commit();

    // Reset unread count for current user
    final chatDoc = _firestore.collection('chats').doc(chatId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(chatDoc);
      if (!snapshot.exists) return;

      Map<String, dynamic> unreadCount = Map<String, dynamic>.from(snapshot.data()?['unread_count'] ?? {});
      unreadCount[currentUserId] = 0;

      transaction.update(chatDoc, {'unread_count': unreadCount});
    });
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:swipify/models/message_model.dart';
import 'package:swipify/services/chat_service.dart';
import 'package:swipify/services/api_service.dart';
import 'package:swipify/widgets/video_player_widget.dart';
import 'package:provider/provider.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? productName;
  final String? productImage;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.productName,
    this.productImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _markMessagesAsSeen();
  }

  void _markMessagesAsSeen() {
    if (currentUserId.isNotEmpty) {
      _chatService.markMessagesAsSeen(widget.chatId, currentUserId);
    }
  }

  Future<void> _sendMessage({String type = 'text', String? mediaUrl, String text = ''}) async {
    if (text.trim().isEmpty && mediaUrl == null) return;
    
    final messageText = text.trim();
    _messageController.clear();

    final senderName = context.read<AuthProvider>().user?.displayName;
    
    await _chatService.sendMessage(
      chatId: widget.chatId,
      senderId: currentUserId,
      receiverId: widget.otherUserId,
      message: messageText,
      type: type,
      mediaUrl: mediaUrl,
      senderName: senderName?.isNotEmpty == true ? senderName! : 'User',
    );
    
    _scrollToBottom();
  }

  Future<void> _pickAndUploadMedia(bool isVideo) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: isVideo ? FileType.video : FileType.image,
      allowMultiple: false,
    );

    if (result == null) return;
    final file = result.files.single;

    setState(() => _isUploading = true);

    try {
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      final url = await ApiService.uploadChatMedia(bytes, file.name);
      
      await _sendMessage(
        type: isVideo ? 'video' : 'image',
        mediaUrl: url,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload: $e')),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0, // Because ListView is reversed
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        elevation: 1,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('chats').doc(widget.chatId).snapshots(),
        builder: (context, chatSnapshot) {
          final chatData = chatSnapshot.data?.data() as Map<String, dynamic>?;
          final pName = chatData?['product_name'] ?? widget.productName;
          final pImage = chatData?['product_image'] ?? widget.productImage;

          return Column(
            children: [
              Expanded(
                child: Column(
                  children: [
                    if (pName != null && pName.isNotEmpty)
                      _buildProductPreviewCard(pName, pImage),
                    Expanded(
                      child: StreamBuilder<List<MessageModel>>(
                        stream: _chatService.getMessages(widget.chatId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Center(
                              child: Text(
                                'No messages yet. Say hi!',
                                style: GoogleFonts.inter(color: Colors.grey),
                              ),
                            );
                          }

                          final messages = snapshot.data!;
                      
                      // Mark messages as delivered if we received new ones while screen is open
                      // In a perfect world, we'd only do this for new unread messages.
                      // For now, since we are inside the chat, we mark them as seen.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _markMessagesAsSeen();
                      });

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.senderId == currentUserId;
                          return _buildMessageBubble(message, isMe);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          _buildMessageInput(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductPreviewCard(String name, String? image) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SwipifyTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SwipifyTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (image != null && image.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                image,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(width: 50, height: 50, color: Colors.grey[200]),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're chatting about this product",
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: SwipifyTheme.accentColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SwipifyTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (message.type == 'image' && message.mediaUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    message.mediaUrl!,
                    fit: BoxFit.cover,
                  ),
                )
              else if (message.type == 'video' && message.mediaUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: VideoPlayerWidget(videoUrl: message.mediaUrl!),
                )
              else
                Text(
                  message.message,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 15,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat.jm().format(message.createdAt),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.black54,
                      fontSize: 10,
                    ),
                  ),
                  if (isMe) const SizedBox(width: 4),
                  if (isMe) _buildStatusIcon(message.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color;

    switch (status) {
      case 'seen':
        icon = Icons.done_all;
        color = Colors.blue[300]!;
        break;
      case 'delivered':
        icon = Icons.done_all;
        color = Colors.white70;
        break;
      case 'sent':
      default:
        icon = Icons.check;
        color = Colors.white70;
        break;
    }

    return Icon(icon, size: 14, color: color);
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: SwipifyTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: SwipifyTheme.borderColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.image_outlined, color: SwipifyTheme.textSecondary, size: 22),
                    onPressed: () => _pickAndUploadMedia(false),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(10),
                  ),
                  Container(width: 1, height: 20, color: SwipifyTheme.borderColor),
                  IconButton(
                    icon: const Icon(Icons.videocam_outlined, color: SwipifyTheme.textSecondary, size: 24),
                    onPressed: () => _pickAndUploadMedia(true),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: SwipifyTheme.borderColor, width: 1.5),
                ),
                child: TextField(
                  controller: _messageController,
                  style: GoogleFonts.inter(fontSize: 14, color: SwipifyTheme.primaryColor),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.inter(fontSize: 14, color: SwipifyTheme.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () => _sendMessage(text: _messageController.text),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: SwipifyTheme.accentColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swipify/models/chat_model.dart';
import 'package:swipify/services/chat_service.dart';
import 'package:intl/intl.dart';
import 'package:swipify/screens/chat_screen.dart';
import 'package:swipify/core/theme.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatListScreen extends StatefulWidget {
  final bool showAppBar;

  const ChatListScreen({super.key, this.showAppBar = true});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0 && now.day == time.day) {
      return DateFormat.jm().format(time); // e.g., 5:08 PM
    } else if (difference.inDays < 7) {
      return DateFormat.E().format(time); // e.g., Mon
    } else {
      return DateFormat.MMMd().format(time); // e.g., May 2
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId.isEmpty) {
      return Scaffold(
        backgroundColor: SwipifyTheme.backgroundColor,
        appBar: widget.showAppBar ? AppBar(
          title: Text('Chats', style: SwipifyTheme.heading2),
          elevation: 0,
          backgroundColor: SwipifyTheme.backgroundColor,
          iconTheme: const IconThemeData(color: SwipifyTheme.primaryColor),
        ) : null,
        body: Center(
          child: Text('Please log in to view chats.', style: SwipifyTheme.body),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SwipifyTheme.backgroundColor,
      appBar: widget.showAppBar ? AppBar(
        title: Text('Messages', style: SwipifyTheme.heading2),
        elevation: 0,
        backgroundColor: SwipifyTheme.backgroundColor,
        iconTheme: const IconThemeData(color: SwipifyTheme.primaryColor),
      ) : null,
      body: StreamBuilder<List<ChatModel>>(
        stream: _chatService.getUserChats(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: SwipifyTheme.accentColor));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}', style: SwipifyTheme.body),
            );
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 64, color: SwipifyTheme.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: SwipifyTheme.productTitle.copyWith(color: SwipifyTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final isBuyer = chat.buyerId == currentUserId;
              final otherUserId = isBuyer ? chat.sellerId : chat.buyerId;
              final unreadCount = chat.unreadCount[currentUserId] ?? 0;
              
              final otherUserName = isBuyer ? chat.sellerName : chat.buyerName;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: chat.chatId,
                        otherUserId: otherUserId,
                        otherUserName: otherUserName,
                        productName: chat.productName,
                        productImage: chat.productImage,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: SwipifyTheme.borderColor, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: SwipifyTheme.accentColor.withValues(alpha: 0.1),
                        child: const Icon(Icons.person, color: SwipifyTheme.accentColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  otherUserName,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: unreadCount > 0 ? FontWeight.w800 : FontWeight.w600,
                                    color: SwipifyTheme.primaryColor,
                                  ),
                                ),
                                Text(
                                  _formatTime(chat.lastMessageTime),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
                                    color: unreadCount > 0 ? SwipifyTheme.accentColor : SwipifyTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (chat.productName != null && chat.productName!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 2),
                                          child: Text(
                                            "Re: ${chat.productName}",
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: SwipifyTheme.accentColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      Text(
                                        chat.lastMessage.isEmpty ? 'Started a chat' : chat.lastMessage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                                          color: unreadCount > 0 ? SwipifyTheme.primaryColor : SwipifyTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: SwipifyTheme.accentColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      unreadCount.toString(),
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

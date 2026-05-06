// lib/features/profile/screens/ai_chat_screen.dart
// AI Customer Support Chatbot screen — Messenger-style chat UI.
// Communicates with the Swipify AI Assistant via backend API.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/services/ai_chat_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<AiChatMessage> _messages = [];
  bool _isTyping = false;
  late AnimationController _dotAnimController;

  // Quick reply suggestions
  static const List<Map<String, dynamic>> _quickReplies = [
    {'label': '📦 Track my order', 'message': 'Where is my order? Can you check my recent order status?'},
    {'label': '💰 Request refund', 'message': 'How do I request a refund for my order?'},
    {'label': '💬 Contact seller', 'message': 'How can I chat with a seller about my order?'},
    {'label': '🎟️ Use a voucher', 'message': 'How do I apply a voucher during checkout?'},
    {'label': '🎫 Create ticket', 'message': 'I want to create a support ticket'},
    {'label': '👤 My account', 'message': 'How do I update my profile information?'},
  ];

  @override
  void initState() {
    super.initState();
    _dotAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Welcome message
    _messages.add(AiChatMessage(
      role: 'assistant',
      content: 'Hi! 👋 I\'m the Swipify Assistant. I can help you with:\n\n'
          '📦 Order tracking & status\n'
          '💳 Payment questions\n'
          '🚚 Shipping information\n'
          '↩️ Refunds & returns\n'
          '💬 Seller communication\n'
          '⭐ Reviews\n'
          '🎫 Support tickets\n\n'
          'How can I help you today?',
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _dotAnimController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Add user message
    setState(() {
      _messages.add(AiChatMessage(role: 'user', content: text.trim()));
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    // Call AI backend
    final reply = await AiChatService.sendMessage(
      userId: user.uid,
      message: text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isTyping = false;
      _messages.add(reply);
    });
    _scrollToBottom();
  }

  Future<void> _clearChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear all chat history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AiChatService.clearHistory(user.uid);
      setState(() {
        _messages.clear();
        _messages.add(AiChatMessage(
          role: 'assistant',
          content: 'Chat cleared! How can I help you today? 😊',
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList()),
          if (_isTyping) _buildTypingIndicator(),
          if (_messages.length <= 1) _buildQuickReplies(),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: SwipifyTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 2,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE97B4A), Color(0xFFFF9A6C)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Swipify Assistant',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isTyping
                    ? Text('typing...', key: const ValueKey('typing'),
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white70))
                    : Text('Online', key: const ValueKey('online'),
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF4ADE80))),
              ),
            ],
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            if (value == 'clear') _clearChat();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'clear', child: Text('Clear Chat')),
          ],
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg.role == 'user';
        return _buildMessageBubble(msg, isUser);
      },
    );
  }

  Widget _buildMessageBubble(AiChatMessage msg, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFE97B4A), Color(0xFFFF9A6C)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? SwipifyTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.content,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isUser ? Colors.white : SwipifyTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(msg.timestamp),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isUser ? Colors.white60 : SwipifyTheme.textMuted,
                    ),
                  ),
                  if (msg.ticketId != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '🎫 Ticket: #${msg.ticketId!.substring(0, 8).toUpperCase()}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 34),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFE97B4A), Color(0xFFFF9A6C)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _dotAnimController,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final delay = index * 0.3;
                    final progress = (_dotAnimController.value - delay).clamp(0.0, 1.0);
                    final opacity = (1.0 - (progress - 0.5).abs() * 2).clamp(0.3, 1.0);
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: SwipifyTheme.textMuted.withValues(alpha: opacity),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Swipify Assistant is typing...',
            style: GoogleFonts.inter(fontSize: 11, color: SwipifyTheme.textMuted, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _quickReplies.map((qr) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                elevation: 1,
                child: InkWell(
                  onTap: () => _sendMessage(qr['message'] as String),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: SwipifyTheme.accentColor.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      qr['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SwipifyTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                minLines: 1,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: SwipifyTheme.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (text) {
                  if (text.trim().isNotEmpty) {
                    _sendMessage(text);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _isTyping ? Colors.grey : SwipifyTheme.accentColor,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: _isTyping
                  ? null
                  : () {
                      if (_controller.text.trim().isNotEmpty) {
                        _sendMessage(_controller.text);
                      }
                    },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$h:$minute $period';
  }
}

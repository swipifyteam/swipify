// lib/services/ai_chat_service.dart
// Service layer for communicating with the Swipify AI Assistant backend.
// All AI chat API calls go through this service.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:swipify/services/api_service.dart';

class AiChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final String? ticketId;

  AiChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.ticketId,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AiChatService {
  /// Send a message to the AI chatbot and get a response.
  static Future<AiChatMessage> sendMessage({
    required String userId,
    required String message,
  }) async {
    try {
      debugPrint('[AI_CHAT] Sending message: ${message.substring(0, message.length > 50 ? 50 : message.length)}...');

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/ai/chat'),
        headers: await ApiService.getHeaders(),
        body: json.encode({
          'user_id': userId,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('[AI_CHAT] Response received: ${data['reply'].toString().substring(0, data['reply'].toString().length > 50 ? 50 : data['reply'].toString().length)}...');
        
        return AiChatMessage(
          role: 'assistant',
          content: data['reply'] ?? 'Sorry, I could not process that.',
          ticketId: data['ticket_id'],
        );
      } else {
        debugPrint('[AI_CHAT] Error: ${response.statusCode} - ${response.body}');
        return AiChatMessage(
          role: 'assistant',
          content: 'I\'m having trouble connecting right now. Please try again later or submit a support ticket.',
        );
      }
    } catch (e) {
      debugPrint('[AI_CHAT] Exception: $e');
      return AiChatMessage(
        role: 'assistant',
        content: 'Something went wrong. Please check your connection and try again.',
      );
    }
  }

  /// Clear chat history for a user.
  static Future<bool> clearHistory(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiService.baseUrl}/ai/chat/history/$userId'),
        headers: await ApiService.getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[AI_CHAT] Error clearing history: $e');
      return false;
    }
  }
}

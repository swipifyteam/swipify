import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:swipify/services/api_service.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

class SupportService {
  static Future<void> createTicket({
    required String userId,
    required String userName,
    required String userEmail,
    required String category,
    required String subject,
    required String message,
    List<PlatformFile>? images,
  }) async {
    final url = Uri.parse('${ApiService.baseUrl}/support/tickets');
    
    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(await ApiService.getHeaders());
    
    request.fields['user_id'] = userId;
    request.fields['user_name'] = userName;
    request.fields['user_email'] = userEmail;
    request.fields['category'] = category;
    request.fields['subject'] = subject;
    request.fields['message'] = message;
    request.fields['priority'] = _determinePriority(category);
    
    if (images != null) {
      for (var file in images) {
        final bytes = file.bytes ?? await File(file.path!).readAsBytes();
        final multipartFile = http.MultipartFile.fromBytes(
          'images',
          bytes,
          filename: file.name,
        );
        request.files.add(multipartFile);
      }
    }
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to submit ticket: ${response.body}');
    }
  }

  static Future<List<dynamic>> getMyTickets(String userId) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/support/my-tickets/$userId'),
      headers: await ApiService.getHeaders(),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load tickets: ${response.body}');
    }
  }

  static String _determinePriority(String category) {
    switch (category.toLowerCase()) {
      case 'refunds & returns':
      case 'ordering & payment':
        return 'high';
      case 'account & verification':
        return 'urgent';
      default:
        return 'medium';
    }
  }
}

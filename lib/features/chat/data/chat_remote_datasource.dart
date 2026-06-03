import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/api_config.dart';

class ChatRemoteDataSource {
  // PERUBAHAN: Return type diubah menjadi Map<String, dynamic> untuk mengembalikan seluruh JSON
  Future<Map<String, dynamic>> fetchChatMessages(int transactionId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final url = '${ApiConfig.baseUrl}/chat/$transactionId';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (response.statusCode == 200) {
      // Decode dan langsung return keseluruhan data (yang berisi 'messages' dan 'order_info')
      final data = json.decode(response.body);
      return data;
    } else {
      throw Exception('Gagal memuat pesan chat: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> sendChatMessage({
    required int transactionId,
    required int senderId,
    required int receiverId,
    required String message,
    required String sentBy,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final url = '${ApiConfig.baseUrl}/chat';

    final body = jsonEncode({
      'transaction_id': transactionId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'sent_by': sentBy,
    });

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: body,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      return data['data'] ?? {};
    } else {
      throw Exception('Gagal mengirim pesan: ${response.body}');
    }
  }
}
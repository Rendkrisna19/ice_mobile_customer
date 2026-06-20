import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/api_config.dart';
import 'package:flutter/foundation.dart';

class TrackingDataSource {
  Future<Map<String, dynamic>> getTrackingData(int orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // Memastikan URL valid sesuai base url API.
      // Dari OrderRemoteDataSource: ApiConfig.customerOrders adalah bagian dari pesanan.
      // Kita gunakan ApiConfig.baseUrl untuk /v1/customer/tracking/$orderId
      final String url = '${ApiConfig.baseUrl}/customer/tracking/$orderId';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['status'] == true) {
          return decoded['data'];
        } else {
          throw Exception(decoded['message'] ?? 'Failed to get tracking data');
        }
      } else {
        throw Exception('Failed to load tracking data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error getTrackingData: $e");
      throw Exception('Failed to get tracking data: $e');
    }
  }
}

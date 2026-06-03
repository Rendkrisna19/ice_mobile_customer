import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/api_config.dart';

class ActivityService {

  // ===========================================================================
  // GET ORDER HISTORY / ACTIVITY
  // Endpoint: /api/v1/customer/orders
  // ===========================================================================
  Future<List<Map<String, dynamic>>> getActivityHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) return [];

      final response = await http.get(
        Uri.parse(ApiConfig.customerOrders),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['data'] is List) {
          return List<Map<String, dynamic>>.from(json['data']);
        } else if (json['data']['data'] is List) {
          return List<Map<String, dynamic>>.from(json['data']['data']);
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }
}

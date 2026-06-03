import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';

class OutletService {

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ===========================================================================
  // 1. GET ALL OUTLETS (Untuk Home Page)
  // ===========================================================================
  Future<List<dynamic>> getOutlets() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.outlets),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['status'] == 'success') {
          if (json['data'] is Map && json['data']['data'] != null) {
            return json['data']['data'];
          } else if (json['data'] is List) {
            return json['data'];
          }
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ===========================================================================
  // 2. GET OUTLET DETAIL + PRODUCTS (Untuk Detail Page)
  // URL: /api/v1/outlets/{id}
  // ===========================================================================
  Future<Map<String, dynamic>?> getOutletDetail(int id) async {
    try {
      final String url = "${ApiConfig.outlets}/$id";

      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 'success') {
          return json['data'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

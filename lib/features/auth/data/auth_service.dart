import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/api_config.dart';

class AuthService {

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Request OTP
  Future<Map<String, dynamic>> requestRegisterOtp(String email) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/register/request-otp'),
      headers: _headers,
      body: jsonEncode({'email': email}),
    );
    final data = jsonDecode(response.body);
    return {
      'success': response.statusCode == 200 && data['status'] == 'success',
      'message': data['message'],
    };
  }

  // Verify OTP & Register
  Future<Map<String, dynamic>> verifyOtpRegister({
    required String email,
    required String name,
    required String password,
    required String otp,
    required String phone,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/register/verify-otp'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'name': name,
        'password': password,
        'password_confirmation': password,
        'otp': otp,
        'role': 'customer',
        'phone': phone,
      }),
    );
    final data = jsonDecode(response.body);
    final isSuccess = (data['success'] == true) || (data['status'] == 'success');
    if (response.statusCode == 200 && isSuccess) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['data']['token']);
      await prefs.setString('user_data', jsonEncode(data['data']['user']));
      return {
        'success': true,
        'message': data['message'],
        'data': data['data'],
        'status': data['status'],
      };
    } else {
      return {
        'success': false,
        'message': data['message'],
        'data': data['data'],
        'status': data['status'],
      };
    }
  }

  // ===========================================================================
  // FUNGSI LOGIN
  // ===========================================================================
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      final isSuccess = (data['success'] == true) || (data['status'] == 'success');
      if (response.statusCode == 200 && isSuccess) {
        String token = data['data']['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('user_data', jsonEncode(data['data']['user']));

        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login gagal.',
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi: $e',
      };
    }
  }

  // ===========================================================================
  // FUNGSI REGISTER
  // ===========================================================================
  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.register),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
          'role': 'customer',
        }),
      );

      final data = jsonDecode(response.body);
      final isSuccess = (data['success'] == true) || (data['status'] == 'success');
      if (response.statusCode == 200 && isSuccess) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['data']['token']);
        await prefs.setString('user_data', jsonEncode(data['data']['user']));
        return {
          'success': true,
          'message': data['message'],
          'data': data['data'],
          'status': data['status'],
        };
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'message': errorData['message'] ?? 'Gagal: ${response.statusCode}',
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Server Error: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi: $e',
      };
    }
  }
}

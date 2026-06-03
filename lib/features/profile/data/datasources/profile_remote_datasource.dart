import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/api_config.dart';

class ProfileRemoteDataSource {

  static Map<String, String> _authHeaders(String token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  // 1. GET USER PROFILE
  Future<Map<String, dynamic>> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse(ApiConfig.user),
      headers: _authHeaders(token ?? ''),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['data'] ?? json;
    } else {
      throw Exception("Gagal memuat profil: ${response.statusCode}");
    }
  }

  // 2. UPDATE PROFILE (Nama, Email, HP, Password)
  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? password,
    String? passwordConfirmation,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final Map<String, dynamic> body = {};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    if (password != null) body['password'] = password;
    if (passwordConfirmation != null) body['password_confirmation'] = passwordConfirmation;

    final response = await http.post(
      Uri.parse(ApiConfig.profileUpdate),
      headers: {
        ..._authHeaders(token ?? ''),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final Map<String, dynamic> resp = jsonDecode(response.body);

    if (response.statusCode == 200 && resp['success'] == true) {
      if (resp['data'] != null) {
        await prefs.setString('user_data', jsonEncode(resp['data']));
      }
      return {'success': true, 'message': resp['message'], 'data': resp['data']};
    } else {
      return {'success': false, 'message': resp['message'] ?? 'Gagal update profil', 'data': null};
    }
  }

  // 3. UPDATE FOTO PROFIL
  Future<Map<String, dynamic>> updatePhoto(File imageFile) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.profilePhotoUpdate),
    );

    request.headers['Authorization'] = 'Bearer ${token ?? ''}';
    request.headers['Accept'] = 'application/json';

    request.files.add(
      await http.MultipartFile.fromPath('profile_image', imageFile.path),
    );

    var streamedResponse = await request.send();
    final respStr = await streamedResponse.stream.bytesToString();
    final statusCode = streamedResponse.statusCode;

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(respStr);
    } catch (_) {
      data = {'success': false, 'message': 'Invalid response', 'data': null};
    }

    if (statusCode == 200 && data['success'] == true && data['data'] != null) {
      final userData = data['data']['user'] ?? data['data'];
      await prefs.setString('user_data', jsonEncode(userData));
    }

    return {
      'success': statusCode == 200 && data['success'] == true,
      'message': data['message'] ?? 'Gagal upload foto',
      'data': data['data'],
      'statusCode': statusCode,
    };
  }

  // 4. DELETE ACCOUNT
  Future<Map<String, dynamic>> deleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.deleteAccount),
        headers: _authHeaders(token ?? ''),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await prefs.remove('token');
        await prefs.remove('user_data');
        await prefs.remove('saved_address');
        return {'success': true, 'message': 'Akun berhasil dihapus'};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Gagal menghapus akun'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan koneksi'};
    }
  }

  // 5. LOGOUT
  Future<bool> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
        headers: _authHeaders(token ?? ''),
      );
    } catch (_) {
      // Tetap lanjutkan logout lokal meski API gagal
    }

    // Hanya hapus token dan data user.
    // JANGAN gunakan prefs.clear() agar saved_address untuk lokasi Home TIDAK HILANG.
    await prefs.remove('token');
    await prefs.remove('user_data');

    return true;
  }
}

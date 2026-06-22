import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/api_config.dart'; 

class OrderRemoteDataSource {
  
  // ===========================================================================
  // 1. FUNGSI GET PRICING CONFIG
  // ===========================================================================
  Future<Map<String, dynamic>> getPricingConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // [UBAH URL INI] Menembak API publik yang baru dibuat
    final String url = '${ApiConfig.baseUrl}/config/pricing'; 

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] ?? data; 
    } else {
      return {
        'delivery_base_price': 5000,
        'delivery_base_distance': 1.0,
        'delivery_price_per_km': 2000,
        'tax_percentage': 10.0
      };
    }
  }

  // ===========================================================================
  // 2. FUNGSI CREATE ORDER
  // ===========================================================================
  Future<Map<String, dynamic>> createOrder({
    required int outletId,
    required List<Map<String, dynamic>> items,
    required String address,
    required double lat,
    required double lng,
    required double distanceReal, 
    String paymentMethod = 'cod',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); 

    if (token == null) {
      throw Exception("Sesi habis. Silakan login ulang.");
    }

    final formattedItems = items.map((item) {
      return {
        "product_id": item['id'], 
        "quantity": item['qty'],
        "variant_snap": item['note'] != null && item['note'].isNotEmpty 
            ? {"notes": item['note']} 
            : null,
      };
    }).toList();

    final payload = {
      "outlet_id": outletId,
      "delivery_address": address,
      "delivery_latitude": lat,
      "delivery_longitude": lng,
      "distance_real": distanceReal,
      "payment_method": paymentMethod,
      "items": formattedItems,
    };

    final String url = '${ApiConfig.baseUrl}/customer/orders';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      body: json.encode(payload),
    );

    if (response.statusCode == 201) {
      final jsonResponse = json.decode(response.body);
      return jsonResponse['data']; // Mengembalikan objek order utuh
    } else {
      final errorJson = json.decode(response.body);
      throw Exception(errorJson['message'] ?? 'Gagal membuat pesanan');
    }
  }

  // ===========================================================================
  // 3. FUNGSI SIMULATE PAYMENT (UNTUK SANDBOX TESTING)
  // ===========================================================================
  Future<void> simulatePayment(int orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final String url = '${ApiConfig.baseUrl}/customer/orders/$orderId/simulate-payment';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal mensimulasikan pembayaran');
    }
  }

  // ===========================================================================
  // 4. FUNGSI GET DETAIL ORDER
  // ===========================================================================
  Future<Map<String, dynamic>> getOrderDetail(int orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('${ApiConfig.customerOrders}/$orderId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'];
    } else {
      throw Exception('Gagal memuat status order: ${response.statusCode}');
    }
  }

  // ===========================================================================
  // 4. FUNGSI CANCEL ORDER
  // ===========================================================================
  Future<bool> cancelOrder(int orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.post(
      Uri.parse('${ApiConfig.customerOrders}/$orderId/cancel'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    return response.statusCode == 200;
  }

  // ===========================================================================
  // 5. FUNGSI GET ORDER AKTIF TERBARU
  // ===========================================================================
  Future<Map<String, dynamic>?> getLatestActiveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse(ApiConfig.customerOrders),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (response.statusCode != 200) {
      return null;
    }

    final decoded = json.decode(response.body);
    dynamic raw = decoded['data'];
    List<dynamic> orders = [];

    if (raw is List) {
      orders = raw;
    } else if (raw is Map<String, dynamic> && raw['data'] is List) {
      orders = raw['data'];
    }

    if (orders.isEmpty) return null;

    final mappedOrders = orders.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (mappedOrders.isEmpty) return null;

    mappedOrders.sort((a, b) {
      final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    const activeStatuses = {'pending', 'preparing', 'ready', 'on_delivery'};
    for (final order in mappedOrders) {
      final status = (order['status'] ?? '').toString().toLowerCase();
      if (activeStatuses.contains(status)) {
        return order;
      }
    }

    return null;
  }
}
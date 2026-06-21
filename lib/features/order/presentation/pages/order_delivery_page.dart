import 'dart:async';
import 'package:flutter/material.dart';
// Hapus geolocator karena kita tidak menghitung jarak lagi secara manual
import 'package:url_launcher/url_launcher.dart'; 
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/app_typography.dart';
import '../../../../core/components/app_button.dart';
import '../../data/datasources/order_remote_datasource.dart';
import 'order_completed_page.dart';
import 'package:ice_mobile_customer/features/chat/presentation/pages/order_chat_page.dart';
import '../widgets/live_tracking_map.dart';
import '../../data/datasources/tracking_datasource.dart';

class OrderDeliveryPage extends StatefulWidget {
  final int orderId;
  final double outletLat;
  final double outletLng;

  const OrderDeliveryPage({
    super.key,
    required this.orderId,
    this.outletLat = 0.0, 
    this.outletLng = 0.0,
  });

  @override
  State<OrderDeliveryPage> createState() => _OrderDeliveryPageState();
}

class _OrderDeliveryPageState extends State<OrderDeliveryPage> {
  final OrderRemoteDataSource _orderService = OrderRemoteDataSource();
  final TrackingDataSource _trackingService = TrackingDataSource();
  
  Timer? _statusTimer;
  Map<String, dynamic>? _orderData; 
  Map<String, dynamic>? _trackingData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetail(); 
    _startPolling();     
  }

  @override
  void dispose() {
    _statusTimer?.cancel(); 
    super.dispose();
  }

  Future<void> _fetchOrderDetail() async {
    try {
      final data = await _orderService.getOrderDetail(widget.orderId);
      if (mounted) {
        setState(() {
          _orderData = data;
          _isLoading = false;
        });
        
        if (data['status'] == 'completed' || data['status'] == 'delivered') {
          _goToCompletedPage();
        } else if (data['status'] == 'on_delivery') {
          _fetchTrackingData();
        }
      }
    } catch (e) {
      debugPrint("Gagal load order: $e");
    }
  }

  Future<void> _fetchTrackingData() async {
    try {
      final tracking = await _trackingService.getTrackingData(widget.orderId);
      if (mounted) {
        setState(() {
          _trackingData = tracking;
        });
      }
    } catch (e) {
      debugPrint("Gagal load tracking: $e");
    }
  }

  void _startPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchOrderDetail();
    });
  }

  void _goToCompletedPage() {
    _statusTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => OrderCompletedPage(orderId: widget.orderId)),
    );
  }

  // Helper Format Rupiah
  String _formatCurrency(num value) {
    return "Rp. ${value.ceil().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  // --- LOGIC BUKA WHATSAPP ---
  Future<void> _launchWhatsApp(String phone) async {
    String formattedPhone = phone;
    if (formattedPhone.startsWith('0')) {
      formattedPhone = "62${formattedPhone.substring(1)}";
    }
    final Uri url = Uri.parse("https://wa.me/$formattedPhone");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal membuka WhatsApp")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _orderData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9F9F9),
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final driver = _orderData!['driver'];
    final items = (_orderData!['items'] as List?) ?? [];
    
    // MENGAMBIL HITUNGAN MUTLAK DARI BACKEND LARAVEL
    double totalPrice = double.tryParse(_orderData!['total_price']?.toString() ?? '0') ?? 0.0;
    double deliveryFee = double.tryParse(_orderData!['delivery_fee']?.toString() ?? '0') ?? 0.0;
    double subTotal = double.tryParse(_orderData!['subtotal']?.toString() ?? '0') ?? 0.0;
    double tax = double.tryParse(_orderData!['tax']?.toString() ?? '0') ?? 0.0;

    // Fallback safety
    if (subTotal == 0.0 && totalPrice > 0) {
       subTotal = (totalPrice - deliveryFee) / 1.10;
       tax = subTotal * 0.10;
    }

    final isOnDelivery = _orderData?['status'] == 'on_delivery';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      extendBodyBehindAppBar: isOnDelivery, // Agar peta masuk ke bawah appbar transparan
      appBar: AppBar(
        backgroundColor: isOnDelivery ? Colors.transparent : AppColors.primary,
        elevation: 0,
        centerTitle: false,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isOnDelivery ? Colors.white : Colors.transparent,
            shape: BoxShape.circle,
            boxShadow: isOnDelivery ? [BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: isOnDelivery ? Colors.black87 : Colors.white),
            onPressed: () => Navigator.pop(context), 
          ),
        ),
        title: isOnDelivery ? null : Text(
          "Status Pesanan",
          style: AppTypography.headlineSmall.copyWith(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: isOnDelivery ? _buildFullScreenMap(driver) : _buildStandardView(driver, items, subTotal, tax, deliveryFee, totalPrice),
    );
  }

  Widget _buildFullScreenMap(dynamic driver) {
    return Stack(
      children: [
        // 1. FULLSCREEN MAP
        Positioned.fill(
          child: _trackingData != null 
            ? LiveTrackingMap(
                driverLat: double.tryParse(_trackingData!['driver']?['current_latitude']?.toString() ?? '0') ?? 0.0,
                driverLng: double.tryParse(_trackingData!['driver']?['current_longitude']?.toString() ?? '0') ?? 0.0,
                customerLat: double.tryParse(_trackingData!['destination']?['latitude']?.toString() ?? '0') ?? 0.0,
                customerLng: double.tryParse(_trackingData!['destination']?['longitude']?.toString() ?? '0') ?? 0.0,
                outletLat: widget.outletLat,
                outletLng: widget.outletLng,
                polylineEncoded: _trackingData!['route_polyline'] ?? '',
              )
            : const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),

        // 2. FLOATING INFO CARD (ETA) DI ATAS
        if (_trackingData != null)
        Positioned(
          top: 100, left: 20, right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Estimasi Tiba", style: AppTypography.bodySmall.copyWith(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text("${_trackingData!['eta_minutes'] ?? '-'} Min", style: AppTypography.headlineSmall.copyWith(fontSize: 24, fontWeight: FontWeight.black, color: AppColors.primary)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                          child: Text("${_trackingData!['distance_remaining_km'] ?? '-'} km", style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[800])),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFE8F5E9), shape: BoxShape.circle),
                  child: const Icon(Icons.delivery_dining, color: AppColors.primary, size: 28),
                )
              ],
            ),
          ),
        ),

        // 3. BOTTOM SHEET DRIVER (GOJEK STYLE)
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // DRIVER INFO
                if (driver != null)
                Row(
                  children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                      ),
                      child: ClipOval(
                        child: driver['photo'] != null 
                          ? Image.network(driver['photo'], fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.person, color: Colors.grey, size: 30))
                          : const Icon(Icons.person, color: Colors.grey, size: 30),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(driver['name'] ?? "Driver", style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text("4.9", style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Expanded(child: Text("${driver['vehicle_type'] ?? 'Motor'} • ${driver['plate_number'] ?? '-'}", style: AppTypography.bodySmall.copyWith(color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),

                // ACTION BUTTONS
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                           if (driver != null && driver['phone'] != null) {
                             _launchWhatsApp(driver['phone']);
                           }
                        },
                        icon: const Icon(Icons.phone, size: 20),
                        label: const Text("Telepon"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                           if (_orderData != null && driver != null) {
                              final transactionId = _orderData!['id'] ?? 0;
                              final senderId = _orderData!['user_id'] ?? 0;
                              final receiverId = _orderData!['driver_id'] ?? 0;
                              Navigator.push(context, MaterialPageRoute(builder: (_) => OrderChatPage(transactionId: transactionId, senderId: senderId, receiverId: receiverId, sentBy: 'customer')));
                           }
                        },
                        icon: const Icon(Icons.chat, size: 20),
                        label: const Text("Chat"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStandardView(dynamic driver, List<dynamic> items, double subTotal, double tax, double deliveryFee, double totalPrice) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // --- HEADER GAMBAR ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/delivery.png', 
                        height: 160,
                        fit: BoxFit.contain,
                        errorBuilder: (_,__,___) => const Icon(Icons.map, size: 100, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Pesanan sedang diproses...",
                        style: AppTypography.headlineSmall.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Kurir akan segera mengambil pesananmu. Mohon tunggu sebentar.",
                        style: AppTypography.bodyMedium.copyWith(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- KARTU DRIVER ---
                if (driver != null) 
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      ClipOval(
                        child: Container(
                          width: 50, height: 50,
                          color: Colors.grey[200],
                          child: const Icon(Icons.person, color: Colors.grey, size: 30),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(driver['name'] ?? "Driver", style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("${driver['vehicle_type'] ?? 'Motor'} | ${driver['plate_number'] ?? '-'}", style: AppTypography.bodySmall.copyWith(color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- DETAIL PESANAN ---
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...items.map((item) {
                        final productName = item['product_name_snap'] ?? (item['product'] != null ? item['product']['name'] : "Item");
                        double price = double.tryParse(item['price']?.toString() ?? item['product_price_snap']?.toString() ?? '0') ?? 0.0;
                        final qty = item['quantity'] ?? 0;
                        
                        return Column(
                          children: [
                            _buildOrderItem(productName, _formatCurrency(price), "${qty}x"),
                            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(thickness: 0.5)),
                          ],
                        );
                      }),
                      const SizedBox(height: 8),

                      Text("Ringkasan Pembayaran", style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildSummaryRow("Harga", _formatCurrency(subTotal)),
                      const SizedBox(height: 8),
                      _buildSummaryRow("Pajak (10%)", _formatCurrency(tax)),
                      const SizedBox(height: 8),
                      _buildSummaryRow("Biaya Pengiriman", _formatCurrency(deliveryFee)),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(thickness: 1)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Total Pembayaran", style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                          Text(_formatCurrency(totalPrice), style: AppTypography.headlineSmall.copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItem(String name, String price, String qty) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(price, style: AppTypography.bodySmall.copyWith(color: Colors.grey)),
            ],
          ),
        ),
        Text(qty, style: AppTypography.labelLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodyMedium),
        Text(value, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
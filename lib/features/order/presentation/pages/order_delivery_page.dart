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
  
  Timer? _statusTimer;
  Map<String, dynamic>? _orderData; 
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
        
        if (data['status'] == 'completed') {
          _goToCompletedPage();
        }
      }
    } catch (e) {
      debugPrint("Gagal load order: $e");
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

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context), 
        ),
        title: Text(
          "Status Pesanan",
          style: AppTypography.headlineSmall.copyWith(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (driver != null && driver['phone'] != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              onPressed: () {
                                if (_orderData != null && driver != null) {
                                  final transactionId = _orderData!['id'] ?? 0;
                                  final senderId = _orderData!['user_id'] ?? 0;
                                  final receiverId = _orderData!['driver_id'] ?? 0;
                                  if (transactionId == 0 || senderId == 0 || receiverId == 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Data chat tidak lengkap")),
                                    );
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => OrderChatPage(
                                        transactionId: transactionId,
                                        senderId: senderId,
                                        receiverId: receiverId,
                                        sentBy: 'customer',
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data order/driver tidak tersedia")));
                                }
                            },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
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
                          "Pesanan sedang diantar...",
                          style: AppTypography.headlineSmall.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Kurir sedang menuju ke lokasimu. Mohon pastikan nomor HP aktif.",
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
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
                            onPressed: () {
                              if (_orderData != null && driver != null) {
                                final transactionId = _orderData!['id'] ?? 0;
                                final senderId = _orderData!['user_id'] ?? 0;
                                final receiverId = _orderData!['driver_id'] ?? 0;
                                if (transactionId == 0 || senderId == 0 || receiverId == 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Data chat tidak lengkap")),
                                  );
                                  return;
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderChatPage(
                                      transactionId: transactionId,
                                      senderId: senderId,
                                      receiverId: receiverId,
                                      sentBy: 'customer',
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data order/driver tidak tersedia")));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                  else
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(width: 16),
                        Text("Sedang mencari driver..."),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- METODE PEMBAYARAN ---
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wallet, color: AppColors.primary, size: 24),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Metode Pembayaran", style: AppTypography.bodySmall.copyWith(color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text("Tunai (Cash)", style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- DETAIL PESANAN & RINGKASAN DARI BACKEND ---
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
                        // Loop Item
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

                        // Ringkasan
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
      ),
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
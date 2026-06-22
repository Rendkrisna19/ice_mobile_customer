import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Tambahkan url_launcher
// Hapus import geolocator karena kita tidak menghitung manual lagi
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/app_typography.dart';
import '../../data/datasources/order_remote_datasource.dart';
import 'order_delivery_page.dart';
import 'package:ice_mobile_customer/features/chat/presentation/pages/order_chat_page.dart';

class OrderStatusPage extends StatefulWidget {
  final int orderId; 

  const OrderStatusPage({
    super.key,
    required this.orderId, 
  });

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage> {
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

        // --- LOGIKA NAVIGASI OTOMATIS (KE TRACKING) ---
        if (data['status'] == 'on_delivery') {
          _statusTimer?.cancel();
          
          final outletData = data['outlet']; 
          double outletLat = 0.0;
          double outletLng = 0.0;

          if (outletData != null) {
            outletLat = double.tryParse(outletData['latitude'].toString()) ?? 0.0;
            outletLng = double.tryParse(outletData['longitude'].toString()) ?? 0.0;
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDeliveryPage(
                orderId: widget.orderId,
                outletLat: outletLat, 
                outletLng: outletLng,
              ),
            ),
          );
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

  Future<void> _simulateSandboxPayment() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Simulasi Payment Gateway"),
          content: const Text("Memproses pembayaran... (Sandbox)"),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await _orderService.simulatePayment(widget.orderId);
                  await _fetchOrderDetail(); // Refresh data
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Pembayaran Berhasil Disimulasikan!"), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Gagal simulasi: $e"), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text("Bayar Lunas"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Batal", style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint("Gagal simulate: $e");
    }
  }

  // Helper Format Rupiah
  String _formatCurrency(num value) {
    return "Rp. ${value.ceil().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  // --- LOGIC BUKA WHATSAPP OUTLET ---
  Future<void> _launchWhatsAppOutlet() async {
    if (_orderData == null) return;
    final outlet = _orderData!['outlet'];
    final customer = _orderData!['customer'];
    if (outlet == null) return;

    // Ambil nomor WA outlet atau phone biasa
    String phone = outlet['whatsapp_number'] ?? outlet['phone'] ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nomor kontak outlet tidak tersedia")));
      return;
    }

    String formattedPhone = phone;
    if (formattedPhone.startsWith('0')) {
      formattedPhone = "62${formattedPhone.substring(1)}";
    }
    
    String custName = customer?['name'] ?? 'Customer';
    String message = "Halo Outlet, saya $custName.\nSaya ingin konfirmasi mengenai pesanan saya dengan Nomor Order #${widget.orderId}.";
    
    final Uri url = Uri.parse("https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}");
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

    final items = (_orderData!['items'] as List?) ?? []; 
    
    // --- 1. MENGAMBIL HITUNGAN MUTLAK DARI BACKEND LARAVEL ---
    double totalPrice = double.tryParse(_orderData!['total_price']?.toString() ?? '0') ?? 0.0;
    double deliveryFee = double.tryParse(_orderData!['delivery_fee']?.toString() ?? '0') ?? 0.0;
    double subTotal = double.tryParse(_orderData!['subtotal']?.toString() ?? '0') ?? 0.0;
    double tax = double.tryParse(_orderData!['tax']?.toString() ?? '0') ?? 0.0;

    // Fallback jika API belum mengembalikan subtotal & tax dengan format yang benar
    if (subTotal == 0.0 && totalPrice > 0) {
       subTotal = (totalPrice - deliveryFee) / 1.10;
       tax = subTotal * 0.10;
    }

    // --- 2. UI WIDGETS ---
    List<Widget> itemWidgets = [];
    for (var i = 0; i < items.length; i++) {
      var item = items[i];
      String productName = item['product_name_snap'] ?? (item['product'] != null ? item['product']['name'] : "Menu Item");
      double price = double.tryParse(item['price']?.toString() ?? item['product_price_snap']?.toString() ?? '0') ?? 0.0;
      int qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;

      itemWidgets.add(
        Column(
          children: [
            _buildOrderItem(
              name: productName,
              price: _formatCurrency(price),
              qty: "${qty}x",
            ),
            if (i < items.length - 1) 
              const Divider(height: 24, thickness: 0.5, color: Colors.grey),
          ],
        )
      );
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
          IconButton(
            onPressed: _launchWhatsAppOutlet,
            icon: Image.asset('assets/icons/whatsapp.png', width: 24, height: 24, color: Colors.white, errorBuilder: (_,__,___) => const Icon(Icons.wechat, color: Colors.white, size: 24)),
            tooltip: 'Chat WA Outlet',
          ),
          IconButton(
            onPressed: () {
              if (_orderData == null) return;
              final transactionId = _orderData!['id'] ?? 0;
              final senderId = _orderData!['user_id'] ?? 0;
              final receiverId = _orderData!['driver_id'] ?? 0;
              final driver = _orderData!['driver'];
              final driverName = driver != null ? (driver['name'] ?? '') : '';
              final driverPlate = driver != null ? (driver['plate_number'] ?? '') : '';
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
                    driverName: driverName,
                    driverPlate: driverPlate,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // --- HEADER STATUS ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(bottom: 30, left: 24, right: 24, top: 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/order_status.png', 
                          height: 160, 
                          fit: BoxFit.contain,
                          errorBuilder: (_,__,___) => const Icon(Icons.fastfood, size: 100, color: Colors.orange),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _orderData!['status'] == 'preparing' ? "Sedang disiapkan..." : "Menunggu konfirmasi...",
                          style: AppTypography.headlineSmall.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Outlet sudah menerima pesananmu. Estimasi tiba dalam 15-20 menit.",
                          style: AppTypography.bodyMedium.copyWith(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- LIST MENU ---
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      children: itemWidgets.isNotEmpty ? itemWidgets : [const Text("Memuat item...")], 
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- METODE PEMBAYARAN ---
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.wallet, color: AppColors.primary, size: 28),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Metode Pembayaran", style: AppTypography.bodySmall.copyWith(color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _orderData!['payment_method'] == 'online' ? "Transfer / E-Wallet" : "Tunai (Cash)", 
                                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _orderData!['payment_status'] == 'paid' ? Colors.green.shade50 : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _orderData!['payment_status'] == 'paid' ? "LUNAS" : "BELUM BAYAR",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _orderData!['payment_status'] == 'paid' ? Colors.green : Colors.orange,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                        
                        // TOMBOL SIMULASI PEMBAYARAN JIKA ONLINE & UNPAID
                        if (_orderData!['payment_method'] == 'online' && _orderData!['payment_status'] != 'paid') ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _simulateSandboxPayment(),
                              child: const Text("Simulasi Pembayaran (Sandbox)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          )
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- RINGKASAN PEMBAYARAN (DARI BACKEND) ---
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Ringkasan Pembayaran", style: AppTypography.headlineSmall.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        
                        _buildSummaryRow("Harga Menu", _formatCurrency(subTotal)),
                        const SizedBox(height: 8),
                        _buildSummaryRow("Pajak (10%)", _formatCurrency(tax)),
                        const SizedBox(height: 8),
                        _buildSummaryRow("Biaya Pengiriman", _formatCurrency(deliveryFee)),
                        const Divider(height: 24, thickness: 0.5),
                        _buildSummaryRow("Total Pembayaran", _formatCurrency(totalPrice), isTotal: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem({required String name, required String price, required String qty}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(price, style: AppTypography.bodySmall.copyWith(color: Colors.grey)),
            ],
          ),
        ),
        Text(qty, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
      ],
    );
  }

  Widget _buildSummaryRow(String title, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: isTotal ? AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold) : AppTypography.bodyMedium.copyWith(color: Colors.grey[700])),
        Text(value, style: isTotal ? AppTypography.headlineSmall.copyWith(fontSize: 16, fontWeight: FontWeight.bold) : AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
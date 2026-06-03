import 'package:flutter/material.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/app_typography.dart';
import '../../../../core/components/app_button.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../data/datasources/order_remote_datasource.dart';
import '../../../restaurant/presentation/pages/restaurant_detail_page.dart'; 

class OrderCompletedPage extends StatefulWidget {
  final int orderId;

  const OrderCompletedPage({
    super.key,
    required this.orderId, 
  });

  @override
  State<OrderCompletedPage> createState() => _OrderCompletedPageState();
}

class _OrderCompletedPageState extends State<OrderCompletedPage> {
  final OrderRemoteDataSource _orderService = OrderRemoteDataSource();
  
  Map<String, dynamic>? _orderData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCompletedOrder();
  }

  Future<void> _fetchCompletedOrder() async {
    try {
      final data = await _orderService.getOrderDetail(widget.orderId);
      if (mounted) {
        setState(() {
          _orderData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Gagal load history: $e");
    }
  }

  String _formatCurrency(num value) {
    return "Rp. ${value.ceil().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
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
    final outlet = _orderData!['outlet']; 

    // MENGAMBIL HITUNGAN MUTLAK DARI BACKEND LARAVEL
    double totalPrice = double.tryParse(_orderData!['total_price']?.toString() ?? '0') ?? 0.0;
    double deliveryFee = double.tryParse(_orderData!['delivery_fee']?.toString() ?? '0') ?? 0.0;
    double subTotal = double.tryParse(_orderData!['subtotal']?.toString() ?? '0') ?? 0.0;
    double tax = double.tryParse(_orderData!['tax']?.toString() ?? '0') ?? 0.0;

    // Fallback jika API tidak mengirim subtotal & tax dengan benar
    if (subTotal == 0.0 && totalPrice > 0) {
       subTotal = (totalPrice - deliveryFee) / 1.10;
       tax = subTotal * 0.10;
    }

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
              qty: "${qty}x"
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
          onPressed: () => Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (_) => const HomePage()), 
            (r) => false
          ),
        ),
        title: Text(
          "Rincian Pesanan",
          style: AppTypography.headlineSmall.copyWith(color: Colors.white, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // --- TOP SECTION ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/compleate.png', 
                          height: 160,
                          fit: BoxFit.contain,
                          errorBuilder: (_,__,___) => const Icon(Icons.check_circle, size: 100, color: AppColors.primary),
                        ),
                        const SizedBox(height: 24),
                        Text("Selamat menikmati...", style: AppTypography.headlineSmall.copyWith(fontSize: 20)),
                        const SizedBox(height: 8),
                        Text(
                          "Pesananmu sudah selesai diantar. Terima kasih telah memesan di ZAD Apps!",
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.neutral),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // --- DRIVER CARD ---
                        if (driver != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                            border: Border.all(color: AppColors.neutral.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              ClipOval(
                                child: Container(
                                  width: 50, height: 50, color: Colors.grey[200],
                                  child: const Icon(Icons.person, color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(driver['name'] ?? "Driver", style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(driver['plate_number'] ?? "Mitra Pengemudi", style: AppTypography.bodySmall.copyWith(color: AppColors.neutral)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- LIST MENU & SUMMARY ---
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...itemWidgets,
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(thickness: 1)),

                        Row(
                          children: [
                            const Icon(Icons.wallet, color: AppColors.primary, size: 24),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Metode Pembayaran", style: AppTypography.bodySmall.copyWith(fontSize: 10, color: AppColors.neutral)),
                                Text("Tunai (Cash)", style: AppTypography.titleMedium.copyWith(fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        Text("Ringkasan Pembayaran", style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        
                        // RINCIAN HARGA BACKEND
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
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))],
            ),
            child: AppButton(
              text: "Pesan Lagi",
              type: ButtonType.primary,
              onPressed: () {
                if (outlet != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RestaurantDetailPage(
                        outletId: outlet['id'],
                        merchantName: outlet['name'] ?? "Restoran",
                        coverImage: outlet['image_url'] ?? "assets/images/merchant_1.png", 
                      ),
                    ),
                  );
                } else {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const HomePage()),
                    (route) => false,
                  );
                }
              },
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
              Text(name, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(price, style: AppTypography.bodySmall.copyWith(color: AppColors.neutral)),
            ],
          ),
        ),
        Text(qty, style: AppTypography.labelLarge.copyWith(color: AppColors.primary)),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodyMedium),
        Text(
          value, 
          style: isTotal 
            ? AppTypography.headlineSmall.copyWith(fontSize: 16, fontWeight: FontWeight.bold) 
            : AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
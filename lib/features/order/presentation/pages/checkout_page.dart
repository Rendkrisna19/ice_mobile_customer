import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/app_typography.dart';
import '../../../../core/components/app_button.dart';
import '../../data/datasources/order_remote_datasource.dart';
import './checkout_waiting_page.dart';

class CheckoutPage extends StatefulWidget {
  final int outletId;
  final List<Map<String, dynamic>> items;
  final double outletLat;
  final double outletLng;

  const CheckoutPage({
    super.key,
    required this.outletId,
    required this.items,
    required this.outletLat,
    required this.outletLng,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final OrderRemoteDataSource _orderService = OrderRemoteDataSource();

  late List<Map<String, dynamic>> _cartItems;

  double _apiBasePrice = 5000.0;
  double _apiBaseDistance = 1.0;
  double _apiExtraPrice = 2000.0;
  double _apiTaxPercent = 10.0;

  int _deliveryFee = 0;
  double _distanceKm = 0.0;

  String _deliveryAddress = "Memuat alamat...";
  double _userLat = 0.0;
  double _userLng = 0.0;

  bool _isLoading = false;
  bool _isLoadingConfig = true;

  String _paymentMethod = 'cod'; // Default: COD

  @override
  void initState() {
    super.initState();
    _cartItems = List.from(widget.items);
    _loadPricingAndAddress();
  }

  Future<void> _loadPricingAndAddress() async {
    try {
      final pricing = await _orderService.getPricingConfig();
      if (mounted) {
        setState(() {
          _apiBasePrice = double.tryParse(
                  pricing['delivery_base_price']?.toString() ??
                      pricing['base_price']?.toString() ??
                      '5000') ??
              5000;
          _apiBaseDistance = double.tryParse(
                  pricing['delivery_base_distance']?.toString() ??
                      pricing['base_distance']?.toString() ??
                      '1') ??
              1.0;
          _apiExtraPrice = double.tryParse(
                  pricing['delivery_price_per_km']?.toString() ??
                      pricing['extra_price_per_km']?.toString() ??
                      '2000') ??
              2000;
          _apiTaxPercent = double.tryParse(
                  pricing['tax_percentage']?.toString() ??
                      pricing['tax']?.toString() ??
                      '10') ??
              10.0;
        });
      }
    } catch (e) {
      debugPrint("Gagal load pricing: $e");
    }

    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _deliveryAddress =
            prefs.getString('saved_address') ?? "Alamat belum dipilih.";
        _userLat = prefs.getDouble('saved_lat') ?? 0.0;
        _userLng = prefs.getDouble('saved_lng') ?? 0.0;
        _isLoadingConfig = false;
      });
      _calculateDeliveryFee();
    }
  }

  void _calculateDeliveryFee() {
    if (_userLat == 0 ||
        _userLng == 0 ||
        widget.outletLat == 0 ||
        widget.outletLng == 0) return;

    double distanceInMeters = Geolocator.distanceBetween(
        _userLat, _userLng, widget.outletLat, widget.outletLng);

    double distanceInKm = distanceInMeters / 1000;

    double fee = _apiBasePrice;
    if (distanceInKm > _apiBaseDistance) {
      // [FIX] Bulatkan extraKm ke 2 desimal untuk hindari floating point error
      double extraKm = distanceInKm - _apiBaseDistance;
      double extraKmRounded = (extraKm * 100).round() / 100;
      fee += extraKmRounded * _apiExtraPrice;
    }

    setState(() {
      _distanceKm = distanceInKm;
      _deliveryFee = fee.ceil(); // [FIX] ceil() pastikan tidak ada koma
    });
  }

  void _updateQty(int index, int delta) {
    setState(() {
      int currentQty = _cartItems[index]['qty'];
      int newQty = currentQty + delta;

      if (newQty <= 0) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index]['qty'] = newQty;
      }
    });

    if (_cartItems.isEmpty) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Keranjang kosong, pesanan dibatalkan.")),
      );
    }
  }

  // [FIX] Format currency - selalu integer, tidak ada desimal
  String _formatCurrency(num value) {
    final intValue = value.ceil(); // pastikan bulat ke atas
    return "Rp. ${intValue.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}";
  }

  // [FIX] _itemsTotal - handle jika price dari API berupa double
  int get _itemsTotal => _cartItems.fold(0, (sum, item) {
        final price = (item['price'] is double)
            ? (item['price'] as double).round()
            : (item['price'] as num).toInt();
        final qty = (item['qty'] as num).toInt();
        return sum + (price * qty);
      });

  // [FIX] _taxAmount - hindari floating point error (misal 8000.0000000001)
  int get _taxAmount {
    final taxPercent = _apiTaxPercent.round(); // 10.0 → 10 (int)
    return ((_itemsTotal * taxPercent) / 100).ceil();
  }

  int get _grandTotal => _itemsTotal + _taxAmount + _deliveryFee;

  Future<void> _processOrder() async {
    FocusScope.of(context).unfocus();

    if (_userLat == 0.0 || _userLng == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mohon pilih alamat pengiriman dulu.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final orderResponse = await _orderService.createOrder(
        outletId: widget.outletId,
        items: _cartItems,
        address: _deliveryAddress,
        lat: _userLat,
        lng: _userLng,
        distanceReal: _distanceKm,
        paymentMethod: _paymentMethod,
      );

      final int newOrderId = orderResponse['id'];

      if (!mounted) return;

      if (_paymentMethod == 'online') {
        // Tampilkan dialog simulasi Midtrans Sandbox
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("Simulasi Payment Gateway (Sandbox)"),
            content: Text("Berhasil mendapatkan Snap Token: \n\n${orderResponse['snap_token']}\n\nKlik 'Bayar Lunas' untuk mensimulasikan pembayaran berhasil dari Midtrans."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _isLoading = false);
                },
                child: const Text("Batal"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);
                  try {
                    await _orderService.simulatePayment(newOrderId);
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CheckoutWaitingPage(
                            orderId: newOrderId,
                            totalBill: _grandTotal.toDouble(),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Gagal simulasi: $e")),
                      );
                    }
                    setState(() => _isLoading = false);
                  }
                },
                child: const Text("Bayar Lunas"),
              )
            ],
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CheckoutWaitingPage(
              orderId: newOrderId,
              totalBill: _grandTotal.toDouble(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Gagal pesan: $e"),
              backgroundColor: AppColors.error),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingConfig) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9F9F9),
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
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
          "Konfirmasi Pesanan",
          style: AppTypography.headlineSmall
              .copyWith(color: Colors.white, fontSize: 18),
        ),
      ),
      body: _cartItems.isEmpty
          ? const Center(child: Text("Keranjang Kosong"))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- KARTU ALAMAT ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on,
                            color: AppColors.primary, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Alamat Pengantaran",
                                  style: AppTypography.bodySmall
                                      .copyWith(color: AppColors.neutral)),
                              const SizedBox(height: 4),
                              Text(
                                _deliveryAddress,
                                style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_distanceKm > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    "Jarak: ${_distanceKm.toStringAsFixed(2)} km",
                                    style: AppTypography.labelSmall
                                        .copyWith(color: AppColors.primary),
                                  ),
                                )
                              else
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    "Menghitung jarak...",
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- LIST ITEM MENU ---
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10)
                      ],
                    ),
                    child: Column(
                      children: List.generate(_cartItems.length, (index) {
                        final item = _cartItems[index];
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['name'],
                                              style: AppTypography.titleMedium
                                                  .copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatCurrency(item['price']),
                                              style: AppTypography.bodySmall
                                                  .copyWith(
                                                      color:
                                                          AppColors.neutral),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          _buildCounterButton(
                                              icon: Icons.remove,
                                              onTap: () =>
                                                  _updateQty(index, -1)),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12),
                                            child: Text("${item['qty']}",
                                                style:
                                                    AppTypography.labelLarge),
                                          ),
                                          _buildCounterButton(
                                              icon: Icons.add,
                                              onTap: () =>
                                                  _updateQty(index, 1)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    style: AppTypography.bodySmall,
                                    onChanged: (value) =>
                                        _cartItems[index]['note'] = value,
                                    decoration: InputDecoration(
                                      hintText: "Catatan...",
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.all(12),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (index < _cartItems.length - 1)
                              const Divider(height: 1),
                          ],
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- METODE PEMBAYARAN ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.wallet,
                                color: AppColors.primary, size: 24),
                            const SizedBox(width: 12),
                            Text("Metode Pembayaran",
                                style: AppTypography.bodySmall
                                    .copyWith(color: AppColors.neutral)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _paymentMethod = 'cod'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _paymentMethod == 'cod' ? AppColors.primary.withOpacity(0.1) : Colors.white,
                                    border: Border.all(
                                      color: _paymentMethod == 'cod' ? AppColors.primary : AppColors.neutral.withOpacity(0.2),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text("Tunai (COD)", 
                                    style: AppTypography.titleMedium.copyWith(
                                      color: _paymentMethod == 'cod' ? AppColors.primary : AppColors.neutral,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    )
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _paymentMethod = 'online'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _paymentMethod == 'online' ? AppColors.primary.withOpacity(0.1) : Colors.white,
                                    border: Border.all(
                                      color: _paymentMethod == 'online' ? AppColors.primary : AppColors.neutral.withOpacity(0.2),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text("Transfer / E-Wallet", 
                                    style: AppTypography.titleMedium.copyWith(
                                      color: _paymentMethod == 'online' ? AppColors.primary : AppColors.neutral,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    )
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- RINGKASAN PEMBAYARAN ---
                  Text("Ringkasan Pembayaran",
                      style:
                          AppTypography.headlineSmall.copyWith(fontSize: 16)),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow("Harga Menu", _itemsTotal),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                "Biaya Pengiriman (${_distanceKm.toStringAsFixed(1)} km)",
                                style: AppTypography.bodyMedium),
                            Text(
                              _formatCurrency(_deliveryFee),
                              style: AppTypography.bodyMedium
                                  .copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                            "Pajak (${_apiTaxPercent.toStringAsFixed(0)}%)",
                            _taxAmount),
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider()),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Total Pembayaran",
                                style: AppTypography.titleMedium
                                    .copyWith(fontWeight: FontWeight.bold)),
                            Text(
                              _formatCurrency(_grandTotal),
                              style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.black),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Total Pembayaran",
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.neutral)),
                  Text(
                    _formatCurrency(_grandTotal),
                    style: AppTypography.headlineMedium
                        .copyWith(color: AppColors.black, fontSize: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : AppButton(
                      text: "Pesan Sekarang",
                      type: ButtonType.primary,
                      onPressed: _processOrder,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterButton(
      {required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.neutral.withOpacity(0.5))),
        child: Icon(icon, size: 16, color: AppColors.black),
      ),
    );
  }

  Widget _buildSummaryRow(String label, int value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodyMedium),
        Text(
          _formatCurrency(value),
          style:
              AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // [WAJIB] Import untuk hitung jarak
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/app_typography.dart';
import '../../../../core/components/app_button.dart';
// [WAJIB] Import halaman Restoran untuk fitur "Pesan Lagi"
import '../../../restaurant/presentation/pages/restaurant_detail_page.dart'; 

// Extension untuk capitalize string (pindah ke bawah)
extension StringCasingExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}

class ActivityDetailPage extends StatelessWidget {
  // Menerima Data Lengkap dari ActivityPage
  final Map<String, dynamic> orderData;

  const ActivityDetailPage({
    super.key,
    required this.orderData,
  });

  // Helper Format Rupiah
  String _formatCurrency(dynamic value) {
    if (value == null) return "Rp 0";
    double price = double.tryParse(value.toString()) ?? 0;
    return "Rp. ${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  // Helper Parsing Harga Item (Agar tidak 0)
  double _parseItemPrice(Map<String, dynamic> item) {
    double? price = double.tryParse(item['price'].toString());
    if ((price == null || price == 0) && item['product'] != null) {
      price = double.tryParse(item['product']['price'].toString());
    }
    if (price == null || price == 0) {
      price = double.tryParse(item['product_price_snap'].toString());
    }
    return price ?? 0.0;
  }

  // [LOGIC PENTING] Hitung Ulang Ongkir Berdasarkan Jarak
  double _calculateRealDeliveryFee() {
    try {
      // 1. Ambil Koordinat Pengiriman (Snapshot saat order)
      double userLat = double.tryParse(orderData['delivery_latitude'].toString()) ?? 0.0;
      double userLng = double.tryParse(orderData['delivery_longitude'].toString()) ?? 0.0;

      // 2. Ambil Koordinat Outlet
      final outlet = orderData['outlet'];
      double outletLat = 0.0;
      double outletLng = 0.0;
      if (outlet != null) {
        outletLat = double.tryParse(outlet['latitude'].toString()) ?? 0.0;
        outletLng = double.tryParse(outlet['longitude'].toString()) ?? 0.0;
      }

      // Jika koordinat tidak lengkap, kembalikan nilai dari DB (fallback)
      if (userLat == 0 || outletLat == 0) {
        return double.tryParse(orderData['delivery_fee'].toString()) ?? 8000.0;
      }

      // 3. Hitung Jarak (Meter -> KM)
      double distanceInMeters = Geolocator.distanceBetween(userLat, userLng, outletLat, outletLng);
      double distanceInKm = distanceInMeters / 1000;

      // 4. Rumus Harga (Sama seperti Checkout)
      double fee = 8000; // Base Fee 2km
      if (distanceInKm > 2) {
        double extraKm = distanceInKm - 2;
        fee += (extraKm * 2000);
      }

      return fee.ceilToDouble(); // Bulatkan ke atas
    } catch (e) {
      return double.tryParse(orderData['delivery_fee'].toString()) ?? 8000.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- 1. PARSING DATA ---
    final String status = orderData['status'] ?? 'pending';
    final bool isCancelled = status == 'cancelled';
    final bool isOnDelivery = status == 'on_delivery';
    final bool isCompleted = status == 'completed';
    final bool isPending = status == 'pending';
    final bool isPreparing = status == 'preparing' || status == 'ready';

    final items = (orderData['items'] as List?) ?? [];
    final driver = orderData['driver'];
    final outlet = orderData['outlet'];

    // --- 2. HITUNG KEUANGAN (Recalculate Logic) ---
    
    // A. Ongkir (Hitung Ulang agar sesuai jarak)
    double realDeliveryFee = _calculateRealDeliveryFee();
    
    // B. Subtotal (Hitung Manual Item)
    double subTotal = 0;
    for (var item in items) {
      double p = _parseItemPrice(item);
      int q = int.tryParse(item['quantity'].toString()) ?? 1;
      subTotal += (p * q);
    }

    // C. Total Bayar (Subtotal + Ongkir Real)
    double realTotalAmount = subTotal + realDeliveryFee;

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
                  // --- TOP SECTION (Ilustrasi & Status) ---
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
                        // Ilustrasi sesuai status
                        Image.asset(
                          isCancelled
                              ? 'assets/images/logo_waiting.png'
                              : isOnDelivery
                                  ? 'assets/images/illustration_delivery.png'
                                  : 'assets/images/illustration_party.png',
                          height: 160,
                          fit: BoxFit.contain,
                          color: isCancelled ? Colors.grey : null,
                          errorBuilder: (_, __, ___) => const Icon(Icons.receipt_long, size: 80, color: AppColors.primary),
                        ),
                        const SizedBox(height: 24),
                        // Judul status
                        Text(
                          isCancelled
                              ? "Pesanan Dibatalkan"
                              : isOnDelivery
                                  ? "Pesanan Sedang Diantar"
                                  : isPreparing
                                      ? "Pesanan Diproses"
                                      : isPending
                                          ? "Pesanan Menunggu"
                                          : isCompleted
                                              ? "Pesanan Selesai"
                                              : status.capitalize(),
                          style: AppTypography.headlineSmall.copyWith(
                            fontSize: 20,
                            color: isCancelled
                                ? AppColors.error
                                : isOnDelivery
                                    ? Colors.blue
                                    : isPreparing
                                        ? Colors.orange
                                        : isPending
                                            ? Colors.grey
                                            : isCompleted
                                                ? AppColors.success
                                                : AppColors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Deskripsi status
                        Text(
                          isCancelled
                              ? "Pesanan ini telah dibatalkan."
                              : isOnDelivery
                                  ? "Kurir sedang menuju ke lokasimu. Mohon pastikan nomor HP aktif."
                                  : isPreparing
                                      ? "Pesananmu sedang diproses oleh merchant."
                                      : isPending
                                          ? "Pesananmu sedang menunggu konfirmasi."
                                          : isCompleted
                                              ? "Pesananmu sudah selesai diantar. Terima kasih!"
                                              : "Status pesanan: ${status.capitalize()}",
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.neutral),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // --- DRIVER CARD ---
                        if (driver != null && !isCancelled)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                            border: Border.all(color: AppColors.neutral.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              ClipOval(
                                child: Container(
                                  width: 50, height: 50,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.person, color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      driver['name'] ?? "Driver", 
                                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      driver['email'] ?? "Mitra Pengemudi", 
                                      style: AppTypography.bodySmall.copyWith(color: AppColors.neutral)
                                    ),
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
                        // Nama Merchant
                        Text(
                          outlet != null ? outlet['name'] : "Merchant",
                          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        // ID Pesanan
                        Text(
                          "ID Pesanan: #${orderData['id']}", 
                          style: AppTypography.bodySmall.copyWith(color: AppColors.neutral)
                        ),
                        
                        const Divider(height: 24),

                        // --- ITEM LIST ---
                        if (items.isEmpty)
                          const Text("Tidak ada detail item.")
                        else
                          ...items.map((item) {
                            final name = item['product_name_snap'] ?? (item['product'] != null ? item['product']['name'] : "Item");
                            final qty = item['quantity'] ?? 0;
                            final double price = _parseItemPrice(item);
                            
                            return Column(
                              children: [
                                _buildOrderItem(name, _formatCurrency(price), "${qty}x"),
                                const SizedBox(height: 16),
                              ],
                            );
                          }),
                        
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(thickness: 1),
                        ),

                        // Payment Info
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
                        
                        // Rincian Biaya (Menggunakan Hasil Hitung Ulang)
                        _buildSummaryRow("Harga Menu", _formatCurrency(subTotal)),
                        const SizedBox(height: 8),
                        _buildSummaryRow("Biaya Pengiriman", _formatCurrency(realDeliveryFee)),
                        
                        const Divider(height: 24),
                        
                        // Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Total Pembayaran", style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                            Text(
                              _formatCurrency(realTotalAmount), 
                              style: AppTypography.headlineSmall.copyWith(fontSize: 18, color: AppColors.primary)
                            ),
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

          // --- TOMBOL PESAN LAGI ---
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
                // Logic Navigasi ke RestaurantDetailPage
                if (outlet != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RestaurantDetailPage(
                        outletId: int.parse(outlet['id'].toString()),
                        merchantName: outlet['name'] ?? "Restoran",
                        coverImage: outlet['image_url'] ?? "",
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Data toko tidak ditemukan.")),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // Widget Helper Item
  Widget _buildOrderItem(String name, String price, String qty) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name, 
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 14)
              ),
              const SizedBox(height: 4),
              Text(price, style: AppTypography.bodySmall.copyWith(color: AppColors.neutral)),
            ],
          ),
        ),
        Text(
          qty, 
          style: AppTypography.labelLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)
        ),
      ],
    );
  }

  // Widget Helper Summary
  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodyMedium),
        Text(value, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
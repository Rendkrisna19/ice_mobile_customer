import '../../../order/presentation/pages/order_status_page.dart';
import '../../../order/presentation/pages/order_delivery_page.dart';
import '../../../order/presentation/pages/order_completed_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Pastikan package intl terinstall
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/app_typography.dart';
// [WAJIB] Import Service Baru
import '../../data/activity_service.dart'; 
import 'activity_detail_page.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  // Gunakan Service Baru
  final ActivityService _activityService = ActivityService();
  
  late Future<List<Map<String, dynamic>>> _activityFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _activityFuture = _activityService.getActivityHistory();
    });
  }

  // Helper: Format Tanggal
  String _formatDate(String? dateStr) {
    if (dateStr == null) return "-";
    try {
      DateTime dt = DateTime.parse(dateStr);
      return DateFormat("d MMM, HH:mm").format(dt); 
    } catch (e) {
      return dateStr;
    }
  }

  // Helper: Format Ringkasan Item
  String _formatItemsSummary(List<dynamic>? items) {
    if (items == null || items.isEmpty) return "Tidak ada detail item";
    
    List<String> names = items.map((item) {
      if (item['product_name_snap'] != null) return item['product_name_snap'].toString();
      if (item['product'] != null) return item['product']['name'].toString();
      return "Item";
    }).toList();

    String summary = names.join(", ");
    if (summary.length > 35) {
      return "${summary.substring(0, 32)}...";
    }
    return summary;
  }

  // Helper: Config Status (Warna & Text)
  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return {'text': 'Selesai', 'color': AppColors.success, 'bg': AppColors.success.withOpacity(0.1)};
      case 'cancelled':
        return {'text': 'Dibatalkan', 'color': AppColors.error, 'bg': AppColors.error.withOpacity(0.1)};
      case 'on_delivery':
        return {'text': 'Diantar', 'color': Colors.blue, 'bg': Colors.blue.withOpacity(0.1)};
      case 'preparing':
      case 'ready':
        return {'text': 'Diproses', 'color': Colors.orange, 'bg': Colors.orange.withOpacity(0.1)};
      case 'pending':
        return {'text': 'Menunggu', 'color': Colors.grey, 'bg': Colors.grey.withOpacity(0.1)};
      default:
        return {'text': status, 'color': Colors.black, 'bg': Colors.grey.withOpacity(0.1)};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          "Aktivitas",
          style: AppTypography.headlineMedium.copyWith(color: AppColors.black),
        ),
        automaticallyImplyLeading: false, // Hilangkan tombol back di menu utama
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        color: AppColors.primary,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _activityFuture,
          builder: (context, snapshot) {
            // 1. Loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }

            // 2. Error / Data Null
            if (snapshot.hasError) {
              return Center(child: Text("Terjadi kesalahan memuat data."));
            }

            // 3. Data Kosong
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo_waiting.png', 
                      height: 100, 
                      color: Colors.grey[300],
                      errorBuilder: (_,__,___) => const Icon(Icons.history, size: 80, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Text("Belum ada riwayat pesanan", style: AppTypography.bodyMedium.copyWith(color: Colors.grey)),
                  ],
                ),
              );
            }

            final activities = snapshot.data!;

            // 4. List Data
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: activities.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                // Balik urutan agar pesanan terbaru ada di paling atas (opsional)
                // final item = activities[activities.length - 1 - index];
                final item = activities[index];

                // Parsing Data
                final statusConfig = _getStatusConfig(item['status'] ?? 'pending');
                // Pakai logic harga yang sama: total_price atau total_amount
                final rawPrice = item['total_price'] ?? item['total_amount'];
                final double price = double.tryParse(rawPrice.toString()) ?? 0;
                
                final outletName = item['outlet']?['name'] ?? "Unknown Merchant";
                final outletImage = item['outlet']?['image_url']; // URL Foto Toko
                
                return _buildActivityCard(
                  context,
                  merchantName: outletName,
                  statusText: statusConfig['text'],
                  statusColor: statusConfig['color'],
                  statusBg: statusConfig['bg'],
                  date: _formatDate(item['created_at']),
                  price: price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.'),
                  items: _formatItemsSummary(item['items']),
                  imageUrl: outletImage,
                  onTap: () {
                    final status = (item['status'] ?? '').toString();
                    final orderId = int.tryParse(item['id'].toString()) ?? 0;
                    if (status == 'preparing' || status == 'ready' || status == 'pending') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrderStatusPage(orderId: orderId),
                        ),
                      );
                    } else if (status == 'on_delivery') {
                      final outlet = item['outlet'];
                      double outletLat = 0.0;
                      double outletLng = 0.0;
                      if (outlet != null) {
                        outletLat = double.tryParse(outlet['latitude'].toString()) ?? 0.0;
                        outletLng = double.tryParse(outlet['longitude'].toString()) ?? 0.0;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrderDeliveryPage(
                            orderId: orderId,
                            outletLat: outletLat,
                            outletLng: outletLng,
                          ),
                        ),
                      );
                    } else if (status == 'completed') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrderCompletedPage(orderId: orderId),
                        ),
                      );
                    } else {
                      // Fallback ke detail lama
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActivityDetailPage(orderData: item),
                        ),
                      );
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // Widget Helper Card
  Widget _buildActivityCard(
    BuildContext context, {
    required String merchantName,
    required String statusText,
    required Color statusColor,
    required Color statusBg,
    required String date,
    required String price,
    required String items,
    required VoidCallback onTap,
    String? imageUrl,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: AppColors.neutral.withOpacity(0.1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar Merchant
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 60,
                height: 60,
                color: Colors.grey[100],
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_,__,___) => const Icon(Icons.store, color: AppColors.primary),
                      )
                    : const Icon(Icons.store, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            
            // Detail Teks
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          merchantName,
                          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "Rp $price",
                        style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        date,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.neutral, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusText,
                          style: AppTypography.labelSmall.copyWith(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    items,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.neutral),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'dart:async'; // Untuk Timer
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/app_typography.dart';
import '../../data/datasources/order_remote_datasource.dart'; // Import Service
// [WAJIB] Import halaman tujuan selanjutnya
import 'order_status_page.dart';

class CheckoutWaitingPage extends StatefulWidget {
  // Menerima Data Order ID & Total Harga (Sebagai nilai awal)
  final int orderId;
  final double totalBill;

  const CheckoutWaitingPage({
    super.key,
    required this.orderId,
    required this.totalBill,
  });

  @override
  State<CheckoutWaitingPage> createState() => _CheckoutWaitingPageState();
}

class _CheckoutWaitingPageState extends State<CheckoutWaitingPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final OrderRemoteDataSource _orderService = OrderRemoteDataSource();
  
  Timer? _statusCheckTimer;
  bool _isCancelled = false;
  
  // [TAMBAHAN] State untuk menyimpan harga mutlak dari backend
  late double _displayTotal;

  @override
  void initState() {
    super.initState();
    
    // Set harga awal dari halaman checkout
    _displayTotal = widget.totalBill;

    // 1. Setup Animasi Putar (Loading visual)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // 2. Mulai Polling (Cek Status Berkala)
    _startPollingOrderStatus();
  }

  // Helper Format Rupiah
  String _formatCurrency(num value) {
    return "Rp. ${value.ceil().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  // [LOGIC] Polling ke API setiap 5 detik
  void _startPollingOrderStatus() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        // Panggil API Detail Order
        final orderData = await _orderService.getOrderDetail(widget.orderId);
        final String status = orderData['status'];

        if (mounted) {
          setState(() {
            // [SINKRONISASI HARGA] Timpa harga tampilan dengan harga asli dari database Laravel!
            _displayTotal = double.tryParse(orderData['total_price']?.toString() ?? '0') ?? _displayTotal;
          });
        }

        // [ALUR LOGIKA]
        // Jika status masih 'pending', berarti Admin belum ACC -> Timer jalan terus.
        // Jika status BUKAN 'pending', berarti ada perubahan (di-ACC atau ditolak).
        if (status != 'pending') {
          timer.cancel(); // Stop timer agar tidak memanggil API terus menerus
          
          if (status == 'cancelled') {
             // Jika ditolak admin / dibatalkan
             _handleOrderCancelled();
          } else {
             // Jika status berubah jadi 'preparing', 'ready', atau 'on_delivery'
             // Kita arahkan ke OrderStatusPage (Halaman "Sedang Disiapkan")
             _navigateToStatusPage();
          }
        }
      } catch (e) {
        debugPrint("Error checking status: $e");
        // Jangan stop timer jika error koneksi (internet putus nyambung), coba lagi di tick berikutnya
      }
    });
  }

  // [FIX] Navigasi ke OrderStatusPage
  void _navigateToStatusPage() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          // Kirim orderId agar halaman sana bisa load data ulang
          builder: (context) => OrderStatusPage(
            orderId: widget.orderId, 
          ), 
        ),
      );
    }
  }

  void _handleOrderCancelled() {
    if (mounted) {
      setState(() => _isCancelled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pesanan dibatalkan atau ditolak.")),
      );
      Navigator.pop(context); // Kembali ke Home/Menu
    }
  }

  // [LOGIC] Batalkan Pesanan Manual oleh User (Saat masih waiting)
  Future<void> _cancelOrder() async {
    // Stop timer dulu biar logic navigasi gak tabrakan
    _statusCheckTimer?.cancel();

    try {
      final success = await _orderService.cancelOrder(widget.orderId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Pesanan berhasil dibatalkan")),
        );
        Navigator.pop(context); // Kembali
      } else {
        // Jika gagal cancel (misal internet error), nyalakan timer lagi
        _startPollingOrderStatus();
        if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gagal membatalkan pesanan")),
          );
        }
      }
    } catch (e) {
      _startPollingOrderStatus(); // Resume timer jika error
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _statusCheckTimer?.cancel(); // [WAJIB] Matikan timer saat keluar halaman
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // 1. ORDER ID CHIP
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.neutral.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Order #${widget.orderId}",
                    style: AppTypography.labelSmall.copyWith(color: AppColors.black),
                  ),
                ),
              ),

              const Spacer(),

              // 2. ANIMASI LOADING & LOGO
              SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // A. Lingkaran Titik-Titik (Berputar)
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (_, child) {
                        return Transform.rotate(
                          angle: _controller.value * 2 * pi,
                          child: child,
                        );
                      },
                      child: const MerchantFindingLoader(),
                    ),
                    
                    // B. Logo Tengah (Diam)
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05), 
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20), 
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo_waiting.png', // Pastikan aset ada
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.store, size: 40, color: AppColors.primary),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // 3. TEXT STATUS
              Text(
                "Menghubungi outlet...",
                style: AppTypography.headlineSmall.copyWith(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "Mohon tunggu sebentar, pesananmu sedang diteruskan ke outlet untuk konfirmasi.",
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.neutral),
                  textAlign: TextAlign.center,
                ),
              ),

              const Spacer(),

              // 4. INFO PEMBAYARAN
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05), 
                      blurRadius: 10, 
                      offset: const Offset(0, 4)
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wallet, color: AppColors.primary, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          "Tunai (Cash)", 
                          style: AppTypography.titleMedium.copyWith(fontSize: 14, fontWeight: FontWeight.bold)
                        ),
                      ],
                    ),
                    Text(
                      // Format Rupiah yang sudah dinamis pakai data backend
                      _formatCurrency(_displayTotal), 
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 5. TOMBOL BATAL (Selama masih pending)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _cancelOrder,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFF8A8A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    foregroundColor: AppColors.error,
                  ),
                  child: Text(
                    "Batalkan pesanan",
                    style: AppTypography.labelLarge.copyWith(color: const Color(0xFFFF8A8A)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- WIDGET CUSTOM: Animasi Loading ---
class MerchantFindingLoader extends StatelessWidget {
  const MerchantFindingLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(12, (index) {
        final double angle = (index * 30) * pi / 180;
        const double radius = 90; 
        const double center = 120;
        const double dotSize = 10;

        return Positioned(
          left: center + radius * cos(angle) - (dotSize / 2),
          top: center + radius * sin(angle) - (dotSize / 2),
          child: Container(
            width: index % 3 == 0 ? 12 : 8, 
            height: index % 3 == 0 ? 12 : 8,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity((index + 1) / 12), 
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
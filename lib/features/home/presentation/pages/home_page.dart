import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/app_typography.dart';
import '../../../restaurant/presentation/widgets/merchant_card.dart';
import '../widget/location_bottom_sheet.dart'; 
import '../../../restaurant/presentation/pages/restaurant_detail_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../activity/presentation/pages/activity_page.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../restaurant/data/outlet_service.dart';
import '../../../profile/data/datasources/profile_remote_datasource.dart';
import '../../../order/data/datasources/order_remote_datasource.dart';
import '../../../order/presentation/pages/order_status_page.dart';
import '../../../order/presentation/pages/order_delivery_page.dart';
import 'package:ice_mobile_customer/core/config/api_config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  int _lastSelectedIndex = 0;
  
  // State Lokasi
  String _currentLocation = "Memuat lokasi..."; 
  double _currentLat = 0.0;
  double _currentLong = 0.0;

  // Future & Data User
  Future<List<dynamic>>? _outletsFuture;
  String? _userName;
  final ProfileRemoteDataSource _profileService = ProfileRemoteDataSource();
  final OrderRemoteDataSource _orderService = OrderRemoteDataSource();
  Map<String, dynamic>? _activeOrder;
  Timer? _activeOrderTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();
    _outletsFuture = OutletService().getOutlets();
    _fetchUserNameFromProfile();
    _fetchActiveOrder();
    _startActiveOrderPolling();
  }

  @override
  void dispose() {
    _activeOrderTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchUserNameFromProfile();
    // Tambahkan ini agar outlet selalu fresh saat halaman home dibuka
    _outletsFuture = OutletService().getOutlets();
  }

  void _startActiveOrderPolling() {
    _activeOrderTimer?.cancel();
    _activeOrderTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchActiveOrder();
    });
  }

  Future<void> _fetchActiveOrder() async {
    try {
      final activeOrder = await _orderService.getLatestActiveOrder();
      if (!mounted) return;
      setState(() {
        _activeOrder = activeOrder;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activeOrder = null;
      });
    }
  }

  String _activeOrderStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'on_delivery':
        return 'Pesanan sedang diantar';
      case 'preparing':
      case 'ready':
        return 'Pesanan sedang disiapkan';
      case 'pending':
        return 'Menunggu konfirmasi pesanan';
      default:
        return 'Lihat status pesanan';
    }
  }

  Future<void> _openActiveOrderFlow(Map<String, dynamic> order) async {
    final status = (order['status'] ?? '').toString().toLowerCase();
    final orderId = int.tryParse(order['id'].toString()) ?? 0;
    if (orderId == 0) return;

    if (status == 'on_delivery') {
      final outlet = order['outlet'];
      double outletLat = 0.0;
      double outletLng = 0.0;
      if (outlet != null) {
        outletLat = double.tryParse(outlet['latitude'].toString()) ?? 0.0;
        outletLng = double.tryParse(outlet['longitude'].toString()) ?? 0.0;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDeliveryPage(
            orderId: orderId,
            outletLat: outletLat,
            outletLng: outletLng,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderStatusPage(orderId: orderId),
        ),
      );
    }

    _fetchActiveOrder();
  }

  Widget _buildActiveOrderCard() {
    if (_activeOrder == null) return const SizedBox.shrink();

    final status = (_activeOrder!['status'] ?? '').toString();
    final statusText = _activeOrderStatusText(status);
    final outletName = _activeOrder!['outlet']?['name']?.toString() ?? 'Pesanan Aktif';
    final total = double.tryParse(_activeOrder!['total_price']?.toString() ?? '0') ?? 0;

    return GestureDetector(
      onTap: () => _openActiveOrderFlow(_activeOrder!),
      child: Container(
        width: MediaQuery.of(context).size.width - 32,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    outletName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(color: Colors.white.withOpacity(0.95)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "Rp. ${total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\\d{1,3})(?=(\\d{3})+(?!\\d))'), (Match m) => '${m[1]}.')}",
              style: AppTypography.labelLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- LOGIC: AMBIL NAMA USER DARI API ---
  Future<void> _fetchUserNameFromProfile() async {
    try {
      final data = await _profileService.getUserProfile();
      if (mounted && data['name'] != null) {
        setState(() {
          _userName = data['name'];
        });
      }
    } catch (e) {
      // Abaikan jika error, nanti fallback pakai greeting tanpa nama
    }
  }

  // --- LOGIC: MEMUAT LOKASI YANG TERSIMPAN ---
  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAddress = prefs.getString('saved_address');
    final savedLat = prefs.getDouble('saved_lat');
    final savedLng = prefs.getDouble('saved_lng');

    if (mounted) {
      setState(() {
        if (savedAddress != null && savedAddress.isNotEmpty) {
          _currentLocation = savedAddress;
          _currentLat = savedLat ?? 0.0;
          _currentLong = savedLng ?? 0.0;
        } else {
          _currentLocation = "Kisaran Barat, Asahan"; 
          _currentLat = 2.98433; 
          _currentLong = 99.6230607;
          
          prefs.setString('saved_address', _currentLocation);
          prefs.setDouble('saved_lat', _currentLat);
          prefs.setDouble('saved_lng', _currentLong);
        }
      });
    }
  }

  // --- LOGIC: GENERATE UCAPAN SESUAI WAKTU ---
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) {
      return 'Selamat Pagi';
    } else if (hour >= 11 && hour < 15) {
      return 'Selamat Siang';
    } else if (hour >= 15 && hour < 18) {
      return 'Selamat Sore';
    } else {
      return 'Selamat Malam';
    }
  }

  bool? _parseOpenFlag(dynamic raw) {
    if (raw == null) return null;
    if (raw is bool) return raw;
    if (raw is num) return raw == 1;

    final value = raw.toString().trim().toLowerCase();
    if (value.isEmpty) return null;
    if (value == '1' || value == 'true' || value == 'open' || value == 'opened' || value == 'buka') {
      return true;
    }
    if (value == '0' || value == 'false' || value == 'closed' || value == 'close' || value == 'tutup') {
      return false;
    }
    return null;
  }

  int? _parseMinuteOfDay(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    // Support format: HH:mm atau HH:mm:ss
    final parts = text.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour * 60) + minute;
  }

  bool? _isOpenFromHours(dynamic openingHour, dynamic closingHour) {
    final openMinute = _parseMinuteOfDay(openingHour);
    final closeMinute = _parseMinuteOfDay(closingHour);
    if (openMinute == null || closeMinute == null) return null;

    final now = DateTime.now();
    final nowMinute = (now.hour * 60) + now.minute;

    // Jika jam tutup lebih kecil, berarti melewati tengah malam.
    if (closeMinute < openMinute) {
      return nowMinute >= openMinute || nowMinute <= closeMinute;
    }

    return nowMinute >= openMinute && nowMinute <= closeMinute;
  }

  String _normalizeHourLabel(dynamic raw) {
    if (raw == null) return '';
    final text = raw.toString().trim();
    if (text.isEmpty) return '';
    final parts = text.split(':');
    if (parts.length < 2) return text;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return text;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return text;

    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _getOutletOpenLabel(Map<String, dynamic> outlet) {
    final fromFlag = _parseOpenFlag(outlet['is_open']) ??
        _parseOpenFlag(outlet['open']) ??
        _parseOpenFlag(outlet['isOpen']) ??
        _parseOpenFlag(outlet['status']);

    if (fromFlag != null) {
      return fromFlag ? 'Buka' : 'Tutup';
    }

    final fromHours = _isOpenFromHours(outlet['opening_hour'], outlet['closing_hour']);
    if (fromHours != null) {
      return fromHours ? 'Buka' : 'Tutup';
    }

    return 'Tutup';
  }

  // --- LOGIC GANTI HALAMAN ---
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent(); 
      case 1:
        return const ActivityPage(); 
      case 2:
        return const ProfilePage(); 
      default:
        return _buildHomeContent();
    }
  }

  // --- TAMPILAN HOME ---
  Widget _buildHomeContent() {
    return Column(
      children: [
        // 1. HEADER HIJAU
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            bottom: 16,
            left: 20,
            right: 20,
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              
              // INTERAKSI KLIK LOKASI
              Expanded(
                child: GestureDetector(
                  onTap: _showLocationPicker, 
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _currentLocation,
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. LIST MERCHANT API
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _outletsFuture ?? OutletService().getOutlets(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              if (snapshot.hasError) {
                return Center(child: Text("Gagal memuat data: ${snapshot.error}"));
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("Belum ada outlet tersedia."));
              }

              final outlets = snapshot.data!;

              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: outlets.length + 1, 
                separatorBuilder: (context, index) => const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // [PERBAIKAN KONFLIK GIT] Sapaan digabung agar tidak error Text Widget
                        Text(
                          "${_getGreeting()}${_userName != null && _userName!.isNotEmpty ? ", $_userName" : "!"} 👋",
                          style: AppTypography.headlineMedium.copyWith(color: AppColors.black),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Mau pesan makan dari outlet mana hari ini?",
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.neutral),
                        ),
                        const SizedBox(height: 4), 
                      ],
                    );
                  }

                  final outlet = outlets[index - 1];
                  String imageUrl = outlet['image_url'] ?? "assets/images/merchant_1.png";
                  String logoPath = outlet['logo'] ?? '';
                  String bannerPath = outlet['banner'] ?? '';
                  String getFullUrl(String? path) {
                    if (path == null || path.isEmpty) return '';
                    if (path.startsWith('http')) return path;
                    return "${ApiConfig.domain}/$path";
                  }

                  String coverImage = getFullUrl(bannerPath);
                  String logoImage = getFullUrl(logoPath);
                    final outletMap = Map<String, dynamic>.from(outlet);
                    final openLabel = _getOutletOpenLabel(outletMap);
                    final openHourLabel = _normalizeHourLabel(outletMap['opening_hour']);
                    final durationLabel = openLabel == 'Buka'
                      ? 'Buka'
                      : (openHourLabel.isEmpty ? 'Tutup' : 'Tutup, buka pukul $openHourLabel');
                  final isOpen = openLabel == 'Buka';

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RestaurantDetailPage(
                            outletId: outlet['id'],
                            merchantName: outlet['name'],
                            coverImage: imageUrl,
                          ),
                        ),
                      );
                    },
                    child: MerchantCard(
                      name: outlet['name'] ?? "Unknown Outlet",
                      distance: "1.2 km", 
                      duration: durationLabel,
                      rating: 4.8, 
                      coverImage: coverImage, 
                      logoImage: logoImage,
                      isOpen: isOpen,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- LOGIC: MEMBUKA LOKASI & TERIMA DATA ---
  void _showLocationPicker() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) => const LocationBottomSheet(),
    );

    if (result != null) {
      String newAddress = "Kisaran Barat, Asahan";
      double newLat = 0.0;
      double newLng = 0.0;

      if (result is Map) {
        newAddress = result['address'];
        newLat = result['latitude'];
        newLng = result['longitude'];
      } else if (result is String) {
        newAddress = result;
      }

      setState(() {
        _currentLocation = newAddress;
        _currentLat = newLat;
        _currentLong = newLng;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_address', newAddress);
      await prefs.setDouble('saved_lat', newLat);
      await prefs.setDouble('saved_lng', newLng);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedIndex == 0 && _lastSelectedIndex != 0) {
      _fetchUserNameFromProfile();
    }
    _lastSelectedIndex = _selectedIndex;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _buildBody(),
          if (_selectedIndex == 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _activeOrder == null
                      ? const SizedBox.shrink()
                      : Container(
                          key: ValueKey<int>(_activeOrder!['id'] ?? 0),
                          child: _buildActiveOrderCard(),
                        ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.neutral.withOpacity(0.4),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          selectedLabelStyle: AppTypography.labelSmall,
          unselectedLabelStyle: AppTypography.labelSmall,
          onTap: (index) async {
            if (index != 0) {
              final navigator = Navigator.of(context);
              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('token');
              if (token == null || token.isEmpty) {
                navigator.push(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
                return;
              }
            }
            setState(() => _selectedIndex = index);
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Beranda'),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Aktivitas'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Akun'),
          ],
        ),
      ),
    );
  }
}
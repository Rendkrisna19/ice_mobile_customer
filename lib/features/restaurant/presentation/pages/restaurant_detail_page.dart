import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/app_typography.dart';
import '../widgets/menu_card.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../order/presentation/pages/checkout_page.dart';
import '../../data/outlet_service.dart';
import 'package:ice_mobile_customer/core/config/api_config.dart';

class RestaurantDetailPage extends StatefulWidget {
  final int outletId;
  final String merchantName;
  final String coverImage;

  const RestaurantDetailPage({
    super.key,
    required this.outletId,
    required this.merchantName,
    required this.coverImage,
  });

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage> {
  // --- STATE ---
  int _totalItems = 0;
  int _totalPrice = 0;
  bool _isSearching = false;

  // Status Toko
  bool _isOpen = false;
  String _statusText = "Memuat...";

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late Future<Map<String, dynamic>?> _outletDetailFuture;
  final Map<int, int> _cart = {};

  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _outletDetailFuture = OutletService().getOutletDetail(widget.outletId);

    _searchController.addListener(() => setState(() {}));

    _scrollController.addListener(() {
      if (_scrollController.offset > 180 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 180 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });
  }

  void _updateCart(int productId, int price, int deltaQty) {
    if (!_isOpen && deltaQty > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Maaf, toko sedang tutup tidak bisa memesan."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      int currentQty = _cart[productId] ?? 0;
      int newQty = currentQty + deltaQty;

      if (newQty < 0) newQty = 0;

      if (deltaQty > 0) {
        _totalItems++;
        _totalPrice += price;
      } else if (deltaQty < 0 && currentQty > 0) {
        _totalItems--;
        _totalPrice -= price;
      }

      _cart[productId] = newQty;
    });
  }

  String getFullUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return "${ApiConfig.domain}/$path";
  }

  Widget _buildImage(String? path, String defaultAsset) {
    if (path != null && path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) =>
            Image.asset(defaultAsset, fit: BoxFit.cover),
      );
    } else {
      return Image.asset(path ?? defaultAsset, fit: BoxFit.cover);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _outletDetailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF014421)),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Gagal memuat detail outlet."));
          }

          final outletData = snapshot.data!;

          // --- LOGIC STATUS TOKO ---
          bool isForceClosed =
              outletData['is_force_closed'] == 1 ||
              outletData['is_force_closed'] == true;
          String openStr = outletData['opening_hour'] ?? "08:00:00";
          String closeStr = outletData['closing_hour'] ?? "22:00:00";

          bool localIsOpen = false;
          String localStatusText = "";

          try {
            DateTime now = DateTime.now();
            DateTime openTime = DateFormat("HH:mm:ss").parse(openStr);
            openTime = DateTime(now.year, now.month, now.day, openTime.hour, openTime.minute);

            DateTime closeTime = DateFormat("HH:mm:ss").parse(closeStr);
            closeTime = DateTime(now.year, now.month, now.day, closeTime.hour, closeTime.minute);

            if (isForceClosed) {
              localIsOpen = false;
              localStatusText = "Tutup Sementara";
            } else if (now.isAfter(openTime) && now.isBefore(closeTime)) {
              localIsOpen = true;
              localStatusText = "Buka";
            } else {
              localIsOpen = false;
              localStatusText = "Tutup";
            }
          } catch (e) {
            localIsOpen = true;
          }

          _isOpen = localIsOpen;

          // --- LOGIC FILTER PRODUK ---
          final List allProductsRaw = outletData['products'] ?? [];
          final List availableProducts = allProductsRaw.where((product) {
            return product['is_available'] == 1 || product['is_available'] == true;
          }).toList();

          final String query = _searchController.text.toLowerCase();
          final List displayedProducts = availableProducts.where((product) {
            final String name = product['name'].toString().toLowerCase();
            return name.contains(query);
          }).toList();

          return Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // --- HEADER GAMBAR ---
                  SliverAppBar(
                    expandedHeight: 220.0, // Sedikit ditinggikan agar gambar lebih jelas
                    pinned: true,
                    backgroundColor: const Color(0xFF014421),
                    elevation: 0,
                    title: _isScrolled
                        ? Text(
                            outletData['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'DM Sans',
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                    leading: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    actions: [
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.search, color: Colors.black, size: 20),
                          onPressed: () {
                            setState(() => _isSearching = true);
                            Future.delayed(const Duration(milliseconds: 100), () {
                              if (mounted) {
                                FocusScope.of(context).requestFocus(_searchFocusNode);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildImage(
                            getFullUrl(outletData['banner']),
                            "assets/images/merchant_1.png",
                          ),
                          // Efek gradient gelap di bagian bawah gambar agar menyatu dengan card
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black45],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- KONTEN BAWAH ---
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      transform: Matrix4.translationValues(0, -20, 0), // Menarik konten ke atas gambar
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // INFO MERCHANT CARD
                          if (!_isSearching && _searchController.text.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              outletData['name'],
                                              style: const TextStyle(
                                                color: Color(0xFF111827),
                                                fontSize: 20,
                                                fontFamily: 'DM Sans',
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              outletData['address'] ?? "Alamat tidak tersedia",
                                              style: const TextStyle(
                                                color: Color(0xFF6B7280),
                                                fontSize: 12,
                                                fontFamily: 'DM Sans',
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: localIsOpen ? const Color(0xFF014421) : Colors.grey.shade400,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.white, size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              localIsOpen ? "4.8" : "Tutup",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time_filled, size: 18, color: Color(0xFF014421)),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              localStatusText,
                                              style: TextStyle(
                                                color: localIsOpen ? const Color(0xFF014421) : Colors.red,
                                                fontSize: 12,
                                                fontFamily: 'DM Sans',
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              "Jam Operasional: ${openStr.substring(0, 5)} - ${closeStr.substring(0, 5)}",
                                              style: const TextStyle(
                                                color: Color(0xFF6B7280),
                                                fontSize: 10,
                                                fontFamily: 'DM Sans',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Divider(color: Color(0xFFE5E7EB), height: 1, thickness: 1),
                                ],
                              ),
                            ),

                          // LIST MENU HEADER
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: Text(
                              _searchController.text.isNotEmpty ? "Hasil Pencarian" : "Daftar Menu",
                              style: const TextStyle(
                                color: Color(0xFF111827),
                                fontSize: 18,
                                fontFamily: 'DM Sans',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          // LIST MENU ITEMS
                          if (displayedProducts.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: Text(
                                  "Menu tidak tersedia saat ini", 
                                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: displayedProducts.length,
                              separatorBuilder: (context, index) => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Divider(color: Color(0xFFE5E7EB), height: 1, thickness: 1),
                              ),
                              itemBuilder: (context, index) {
                                final product = displayedProducts[index];
                                final int price = double.parse(product['price'].toString()).toInt();
                                final int qty = _cart[product['id']] ?? 0;

                                return Opacity(
                                  opacity: localIsOpen ? 1.0 : 0.6,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product['name'],
                                              style: const TextStyle(
                                                color: Color(0xFF111827),
                                                fontSize: 15,
                                                fontFamily: 'DM Sans',
                                                fontWeight: FontWeight.w700,
                                                height: 1.3,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              product['description'] ?? "Deskripsi tidak tersedia.",
                                              style: const TextStyle(
                                                color: Color(0xFF6B7280),
                                                fontSize: 11,
                                                fontFamily: 'DM Sans',
                                                height: 1.4,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              "Rp ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}",
                                              style: const TextStyle(
                                                color: Color(0xFF111827),
                                                fontSize: 14,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            
                                            // DESAIN BARU TOMBOL TAMBAH & COUNTER
                                            if (qty == 0)
                                              InkWell(
                                                onTap: () => _updateCart(product['id'], price, 1),
                                                borderRadius: BorderRadius.circular(20),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    border: Border.all(color: const Color(0xFF014421)),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: const Text(
                                                    'Tambah',
                                                    style: TextStyle(
                                                      color: Color(0xFF014421),
                                                      fontSize: 12,
                                                      fontFamily: 'DM Sans',
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            else
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  border: Border.all(color: const Color(0xFF014421)),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    InkWell(
                                                      onTap: () => _updateCart(product['id'], price, -1),
                                                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                                                      child: const Padding(
                                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                        child: Icon(Icons.remove, size: 16, color: Color(0xFF014421)),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                                      child: Text(
                                                        '$qty',
                                                        style: const TextStyle(
                                                          color: Color(0xFF014421), 
                                                          fontSize: 12, 
                                                          fontWeight: FontWeight.w700
                                                        ),
                                                      ),
                                                    ),
                                                    InkWell(
                                                      onTap: () => _updateCart(product['id'], price, 1),
                                                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                                                      child: const Padding(
                                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                        child: Icon(Icons.add, size: 16, color: Color(0xFF014421)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // DESAIN BARU GAMBAR MENU (Lebih Proporsional)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: SizedBox(
                                          width: 90,
                                          height: 90,
                                          child: _buildImage(
                                            getFullUrl(product['image_url']),
                                            "assets/images/merchant_1.png",
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                          // Space ekstra di bawah agar tidak tertutup floating cart
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // --- SEARCH OVERLAY ---
              if (_isSearching)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _isSearching = false;
                      FocusScope.of(context).unfocus();
                    }),
                    child: Container(
                      color: Colors.black45,
                      alignment: Alignment.topCenter,
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 10,
                        left: 16, right: 16,
                      ),
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
                          ]
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.grey, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Cari menu...",
                                  hintStyle: TextStyle(fontSize: 14)
                                ),
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () => _searchController.clear(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // --- FLOATING CART (Desain Baru, ala GoFood/GrabFood) ---
              if (_totalItems > 0 && !_isSearching)
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: GestureDetector(
                    onTap: () async {
                      if (!localIsOpen) return;

                      final navigator = Navigator.of(context);

                      // Cek login sebelum ke checkout
                      final prefs = await SharedPreferences.getInstance();
                      final token = prefs.getString('token');

                      if (!mounted) return;

                      if (token == null || token.isEmpty) {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Login Diperlukan"),
                            content: const Text(
                              "Silakan login atau daftar terlebih dahulu untuk melanjutkan pesanan.",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => navigator.pop(),
                                child: const Text("Batal"),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  navigator.pop();
                                  navigator.push(
                                    MaterialPageRoute(builder: (_) => const LoginPage()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                ),
                                child: const Text("Login Sekarang", style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        return;
                      }

                      List<Map<String, dynamic>> selectedItems = [];
                      for (var product in outletData['products']) {
                        int id = product['id'];
                        int qty = _cart[id] ?? 0;
                        if (qty > 0) {
                          selectedItems.add({
                            "id": id,
                            "product_id": id,
                            "name": product['name'],
                            "price": double.parse(product['price'].toString()).toInt(),
                            "qty": qty,
                            "image_url": product['image_url'],
                          });
                        }
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CheckoutPage(
                            outletId: widget.outletId,
                            items: selectedItems,
                            outletLat: double.tryParse(outletData['latitude'].toString()) ?? 0.0,
                            outletLng: double.tryParse(outletData['longitude'].toString()) ?? 0.0,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: localIsOpen ? const Color(0xFF014421) : Colors.grey,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26, 
                            blurRadius: 10, 
                            offset: Offset(0, 4)
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_totalItems',
                              style: const TextStyle(
                                color: Colors.white, 
                                fontSize: 14, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "Keranjang",
                                  style: TextStyle(
                                    color: Colors.white, 
                                    fontSize: 14, 
                                    fontWeight: FontWeight.w600
                                  ),
                                ),
                                Text(
                                  outletData['name'] ?? 'Outlet',
                                  style: const TextStyle(
                                    color: Colors.white70, 
                                    fontSize: 10
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "Rp ${_totalPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}",
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 16, 
                              fontFamily: 'Inter', 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
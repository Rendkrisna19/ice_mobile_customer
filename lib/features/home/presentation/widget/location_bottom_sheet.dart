import 'dart:async'; // Untuk Timer (Debounce)
import 'dart:convert'; // Untuk JSON decode
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // Request API
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/app_typography.dart';
import '../pages/map_page.dart';

class LocationBottomSheet extends StatefulWidget {
  const LocationBottomSheet({super.key});

  @override
  State<LocationBottomSheet> createState() => _LocationBottomSheetState();
}

class _LocationBottomSheetState extends State<LocationBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  bool _isGettingLocation = false;
  
  // State Pencarian
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce; // Penunda request saat mengetik

  // Cache Lokasi
  String? _savedAddress;
  double? _savedLat;
  double? _savedLng;

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();
  }

  @override
  void dispose() {
    _debounce?.cancel(); // Hapus timer saat widget ditutup
    _searchController.dispose();
    super.dispose();
  }

  // --- 1. LOGIC SEARCH (OSM NOMINATIM) ---
  
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    // Tunggu 500ms setelah user berhenti mengetik baru request
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.length > 2) {
        _searchPlaces(query);
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _searchPlaces(String query) async {
    setState(() => _isSearching = true);

    try {
      // URL API Nominatim (OpenStreetMap)
      // q = query
      // countrycodes = id (Hanya Indonesia)
      // limit = 5 (Maksimal 5 hasil)
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&countrycodes=id&limit=5'
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'FlutterApp' // Wajib untuk kebijakan OSM
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _searchResults = data;
        });
      }
    } catch (e) {
      debugPrint("Error Search: $e");
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // --- 2. LOGIC SIMPAN & LOAD LOKASI ---

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedAddress = prefs.getString('saved_address');
      _savedLat = prefs.getDouble('saved_lat');
      _savedLng = prefs.getDouble('saved_lng');
    });
  }

  Future<void> _saveAndReturn(String address, double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_address', address);
    await prefs.setDouble('saved_lat', lat);
    await prefs.setDouble('saved_lng', lng);

    if (mounted) {
      Navigator.pop(context, {
        'address': address,
        'latitude': lat,
        'longitude': lng,
      });
    }
  }

  // --- 3. LOGIC GPS CURRENT LOCATION ---

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS mati');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Izin ditolak');
      }

      Position position = await Geolocator.getCurrentPosition();
      
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, position.longitude
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Format alamat yang lebih rapi
        String street = place.street ?? "";
        String subLocality = place.subLocality ?? "";
        String locality = place.locality ?? "";
        
        String fullAddress = "$street, $subLocality, $locality";
        if (fullAddress.startsWith(", ")) fullAddress = fullAddress.substring(2);

        await _saveAndReturn(fullAddress, position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint("Error GPS: $e");
      // Opsional: Tampilkan snackbar error
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cek apakah user sedang mengetik pencarian
    bool isSearchingMode = _searchController.text.isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // UI Handle
          const SizedBox(height: 12),
          Container(height: 4, width: 40, color: Colors.grey[300]),
          const SizedBox(height: 24),
          
          Text("Pilih Lokasi", style: AppTypography.headlineSmall),
          
          const SizedBox(height: 24),

          // --- SEARCH BAR ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged, // Trigger pencarian saat mengetik
              decoration: InputDecoration(
                hintText: "Cari alamat di Indonesia...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: isSearchingMode 
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged(""); // Reset pencarian
                      },
                    )
                  : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // --- CONTENT (SWITCHABLE) ---
          Expanded(
            child: isSearchingMode 
              ? _buildSearchResults() // Tampilkan hasil cari jika ada teks
              : _buildDefaultOptions(), // Tampilkan menu default jika kosong
          ),
        ],
      ),
    );
  }

  // Tampilan Default (GPS, History, Peta)
  Widget _buildDefaultOptions() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        // 1. Lokasi Terakhir (Cache)
        if (_savedAddress != null) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history, color: Colors.orange),
            title: const Text("Lokasi Terakhir"),
            subtitle: Text(_savedAddress!, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.pop(context, {
              'address': _savedAddress,
              'latitude': _savedLat,
              'longitude': _savedLng,
            }),
          ),
          const Divider(),
        ],

        // 2. GPS Saat Ini
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _isGettingLocation 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.my_location, color: AppColors.primary),
          title: const Text("Gunakan lokasi saat ini"),
          subtitle: const Text("Akurasi tinggi dari GPS"),
          onTap: _isGettingLocation ? null : _getCurrentLocation,
        ),

        const Divider(),

        // 3. Buka Peta
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.map_outlined, color: AppColors.primary),
          title: const Text("Pilih lewat peta"),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MapPage()),
            );
            if (result != null && mounted) {
              await _saveAndReturn(result['address'], result['latitude'], result['longitude']);
            }
          },
        ),
      ],
    );
  }

  // Tampilan Hasil Pencarian
  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              "Alamat tidak ditemukan", 
              style: AppTypography.bodyMedium.copyWith(color: Colors.grey)
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _searchResults.length,
      separatorBuilder: (ctx, index) => const Divider(height: 1),
      itemBuilder: (ctx, index) {
        final place = _searchResults[index];
        final String displayName = place['display_name'] ?? "Alamat tidak diketahui";
        
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
          title: Text(
            displayName.split(",")[0], // Ambil bagian depan alamat (Nama jalan/tempat)
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            displayName, // Alamat lengkap
            maxLines: 2, 
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () {
            // Ambil lat/lng dari hasil pencarian
            double lat = double.parse(place['lat']);
            double lng = double.parse(place['lon']);
            _saveAndReturn(displayName, lat, lng);
          },
        );
      },
    );
  }
}
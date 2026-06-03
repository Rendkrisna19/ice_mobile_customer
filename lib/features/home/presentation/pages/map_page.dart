import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Package Peta Gratis
import 'package:latlong2/latlong.dart';      // Package Koordinat
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/app_typography.dart';
import '../../../../core/components/app_button.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // Controller untuk menggerakkan peta
  final MapController _mapController = MapController();

  // Lokasi Default (Monas) - Fallback jika GPS mati
  LatLng _currentPosition = const LatLng(-6.175392, 106.827153);
  
  String _address = "Mencari alamat...";
  String _district = "-";
  bool _isLoading = true;
  bool _hasMovedToUserLocation = false;

  @override
  void initState() {
    super.initState();
    // Cek GPS setelah tampilan siap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _determinePosition();
    });
  }

  // --- 1. FUNGSI MENCARI LOKASI GPS (Start Awal) ---
  Future<void> _determinePosition() async {
    setState(() => _isLoading = true);

    bool serviceEnabled;
    LocationPermission permission;

    // Cek Servis GPS Hidup/Mati
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackbar('Aktifkan GPS Anda agar peta akurat');
      setState(() => _isLoading = false);
      return;
    }

    // Cek Izin Aplikasi
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackbar('Izin lokasi ditolak');
        setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackbar('Izin lokasi ditolak permanen. Buka pengaturan HP.');
      setState(() => _isLoading = false);
      return;
    }

    // Ambil Koordinat HP
    try {
      Position position = await Geolocator.getCurrentPosition();
      LatLng newPos = LatLng(position.latitude, position.longitude);

      // Pindahkan Peta ke Lokasi User
      _mapController.move(newPos, 17.0); 

      setState(() {
        _currentPosition = newPos;
        _hasMovedToUserLocation = true;
      });
      
      // Cari nama jalan dari koordinat tersebut
      _getAddressFromLatLng(newPos);
      
    } catch (e) {
      debugPrint("Error GPS: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- 2. FUNGSI UBAH KOORDINAT JADI ALAMAT (Reverse Geocoding) ---
  Future<void> _getAddressFromLatLng(LatLng position) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Menggunakan Geocoding bawaan HP (Gratis)
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          // Format Alamat
          _address = place.street ?? "Jalan tanpa nama";
          if (_address.contains('+') || _address.length < 3) {
             _address = place.subLocality ?? "Lokasi Terpilih";
          }
          
          _district = "${place.subLocality}, ${place.locality}, ${place.subAdministrativeArea}";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _address = "Geser pin sedikit...";
          _district = "Gagal memuat detail alamat";
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // --------------------------------------------------
          // LAYER 1: PETA (FLUTTER MAP)
          // --------------------------------------------------
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition,
              initialZoom: 15.0,
              // Update variabel posisi saat digeser, tapi jangan load alamat dulu (biar ringan)
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  _currentPosition = position.center!;
                }
              },
              // Load alamat HANYA saat peta BERHENTI digeser (Hemat kuota & kinerja)
              onMapEvent: (MapEvent event) {
                if (event is MapEventMoveEnd) {
                  _getAddressFromLatLng(_currentPosition);
                }
              },
            ),
            children: [
              TileLayer(
                // --------------------------------------------------------
                // SOLUSI ANTI BLOKIR: Menggunakan CartoDB Voyager
                // Tampilan bersih, gratis, dan jarang kena blokir
                // --------------------------------------------------------
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'], // Load balancer
                
                // WAJIB ISI INI AGAR TIDAK DIANGGAP BOT
                userAgentPackageName: 'id.zadify.icemobile',
                
                maxZoom: 19,
              ),
            ],
          ),

          // --------------------------------------------------
          // LAYER 2: PIN TENGAH (FIXED)
          // --------------------------------------------------
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40), // Agar ujung pin pas di tengah
              child: Icon(Icons.location_on, size: 50, color: AppColors.primary),
            ),
          ),

          // --------------------------------------------------
          // LAYER 3: TOMBOL KEMBALI (POJOK KIRI ATAS)
          // --------------------------------------------------
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black),
              ),
            ),
          ),

          // --------------------------------------------------
          // LAYER 4: TOMBOL MY LOCATION (POJOK KANAN)
          // --------------------------------------------------
          Positioned(
            bottom: 260, // Di atas panel bawah
            right: 16,
            child: FloatingActionButton(
              heroTag: "gps_btn_osm",
              backgroundColor: Colors.white,
              elevation: 4,
              onPressed: () {
                _determinePosition(); // Panggil fungsi GPS lagi
              },
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),

          // --------------------------------------------------
          // LAYER 5: PANEL INFO ALAMAT (BAWAH)
          // --------------------------------------------------
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Konfirmasi Lokasi", style: AppTypography.headlineSmall),
                  const SizedBox(height: 16),
                  
                  // Baris Alamat
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nama Jalan (Skeleton Loading jika loading)
                            _isLoading
                                ? Container(height: 20, width: 150, color: Colors.grey[200])
                                : Text(
                                    _address, 
                                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold), 
                                    maxLines: 2, 
                                    overflow: TextOverflow.ellipsis
                                  ),
                            
                            const SizedBox(height: 6),
                            
                            // Kecamatan/Kota
                            _isLoading
                                ? Container(height: 14, width: 250, color: Colors.grey[200])
                                : Text(
                                    _district, 
                                    style: AppTypography.bodySmall.copyWith(color: AppColors.neutral), 
                                    maxLines: 2, 
                                    overflow: TextOverflow.ellipsis
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Tombol Pilih
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      text: "Pilih Lokasi Ini",
                      type: ButtonType.primary,
                      onPressed: () {
                        // Kirim Data Balik
                        Navigator.pop(context, {
                          'address': "$_address, $_district",
                          'latitude': _currentPosition.latitude,
                          'longitude': _currentPosition.longitude,
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/style/app_colors.dart';

class LiveTrackingMap extends StatefulWidget {
  final double driverLat;
  final double driverLng;
  final double customerLat;
  final double customerLng;
  final double outletLat;
  final double outletLng;
  final String polylineEncoded;

  const LiveTrackingMap({
    super.key,
    required this.driverLat,
    required this.driverLng,
    required this.customerLat,
    required this.customerLng,
    required this.outletLat,
    required this.outletLng,
    this.polylineEncoded = '',
  });

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap> {
  final MapController _mapController = MapController();

  List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) return [];
    
    try {
      List<dynamic> jsonList = jsonDecode(encoded);
      return jsonList.map((point) {
        if (point is List && point.length >= 2) {
          return LatLng(
            double.tryParse(point[0].toString()) ?? 0.0,
            double.tryParse(point[1].toString()) ?? 0.0,
          );
        }
        return const LatLng(0, 0);
      }).where((latLng) => latLng.latitude != 0 && latLng.longitude != 0).toList();
    } catch (e) {
      debugPrint("Error decoding polyline JSON: \$e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverPos = LatLng(widget.driverLat, widget.driverLng);
    final customerPos = LatLng(widget.customerLat, widget.customerLng);
    final outletPos = LatLng(widget.outletLat, widget.outletLng);
    final routePoints = _decodePolyline(widget.polylineEncoded);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
      ),
      child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: driverPos,
            initialZoom: 15.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.zadapps.icemobilecustomer',
            ),
            if (routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    strokeWidth: 8.0,
                    color: const Color(0xFF10B981).withOpacity(0.9), // Hijau Gojek
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                // Outlet Marker
                if (widget.outletLat != 0.0)
                  Marker(
                    point: outletPos,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.store, color: Colors.orange, size: 24),
                    ),
                  ),
                // Customer Marker
                if (widget.customerLat != 0.0)
                  Marker(
                    point: customerPos,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.home, color: AppColors.primary, size: 24),
                    ),
                  ),
                // Driver Marker
                if (widget.driverLat != 0.0)
                  Marker(
                    point: driverPos,
                    width: 48,
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A534B), // Hijau Gelap
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: const Icon(Icons.two_wheeler, color: Colors.white, size: 28),
                    ),
                  ),
              ],
            ),
          ],
        ),
    );
  }
}

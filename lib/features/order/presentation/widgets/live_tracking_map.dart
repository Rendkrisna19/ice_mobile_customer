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
    
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble()));
    }
    return points;
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

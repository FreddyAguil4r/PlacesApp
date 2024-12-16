import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteMapScreen extends StatelessWidget {
  final List<LatLng> routePoints;
  final LatLng destination;

  const RouteMapScreen({
    super.key,
    required this.routePoints,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shortest Route'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: destination,
          zoom: 14,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('destination'),
            position: destination,
          ),
        },
        polylines: {
          Polyline(
            polylineId: const PolylineId('route'),
            points: routePoints,
            color: Colors.blue,
            width: 5,
          ),
        },
      ),
    );
  }
}

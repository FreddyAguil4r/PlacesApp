import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as location;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/place.dart';

class AllPlacesMapScreen extends StatefulWidget {
  final List<Place> places;

  const AllPlacesMapScreen({super.key, required this.places});

  @override
  State<AllPlacesMapScreen> createState() => _AllPlacesMapScreenState();
}

class _AllPlacesMapScreenState extends State<AllPlacesMapScreen> {
  List<LatLng> routePoints = [];
  LatLng? initialLocation;
  LatLng? currentPosition;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _determineCurrentPosition();
  }

  Future<void> _determineCurrentPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentPosition = LatLng(position.latitude, position.longitude);
        initialLocation = currentPosition;
        isLoading = false;
      });

      if (widget.places.isNotEmpty) {
        await _calculateRoute();
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorDialog('Failed to determine current location: $e');
    }
  }

  Future<void> _calculateRoute() async {
    if (widget.places.isEmpty || currentPosition == null) return;

    final today = DateTime.now().weekday;
    final prioritizedPlaces = widget.places.toList()
      ..sort((a, b) {
        if (today == DateTime.sunday) {
          return a.type == PlaceType.home && b.type == PlaceType.business
              ? -1
              : 1;
        } else {
          return a.type == PlaceType.business && b.type == PlaceType.home
              ? -1
              : 1;
        }
      });

    final List<LatLng> waypoints = prioritizedPlaces
        .map((place) => LatLng(place.location.latitude, place.location.longitude))
        .toList();

    waypoints.insert(0, currentPosition!);

    final calculatedRoute = await _fetchRoute(waypoints);
    setState(() {
      routePoints = calculatedRoute;
    });
  }

  Future<List<LatLng>> _fetchRoute(List<LatLng> waypoints) async {
    const apiKey = 'AIzaSyDpdae-3Rbj4LgF-FLu8x3n46iT86izy2I';
    if (waypoints.length < 2) return [];

    final origin = '${waypoints.first.latitude},${waypoints.first.longitude}';
    final destination = '${waypoints.last.latitude},${waypoints.last.longitude}';
    final intermediatePoints = waypoints
        .sublist(1, waypoints.length - 1)
        .map((point) => '${point.latitude},${point.longitude}')
        .join('|');

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$origin'
          '&destination=$destination'
          '&waypoints=optimize:true|$intermediatePoints'
          '&key=$apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'].isNotEmpty) {
          final polyline = data['routes'][0]['overview_polyline']['points'];
          final points = PolylinePoints().decodePolyline(polyline);
          return points.map((point) => LatLng(point.latitude, point.longitude)).toList();
        } else {
          _showErrorDialog('No routes found.');
        }
      } else {
        _showErrorDialog('Failed to fetch route: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('Error fetching route: $e');
    }
    return [];
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Okay'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || initialLocation == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final markers = widget.places.map((place) {
      // Asigna colores dependiendo del tipo de lugar
      final markerColor = place.type == PlaceType.business
          ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed) // Rojo para negocios
          : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue); // Azul para casas

      return Marker(
        markerId: MarkerId(place.id),
        position: LatLng(place.location.latitude, place.location.longitude),
        infoWindow: InfoWindow(
          title: place.title,
          snippet: place.location.address,
        ),
        icon: markerColor,
      );
    }).toSet();

    if (currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_position'),
          position: currentPosition!,
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Places with Route'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: initialLocation!,
          zoom: 10,
        ),
        markers: markers,
        polylines: {
          if (routePoints.isNotEmpty)
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

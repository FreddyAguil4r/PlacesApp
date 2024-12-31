import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/place.dart';

class AllPlacesMapScreen extends StatelessWidget {
  const AllPlacesMapScreen({super.key, required this.places});

  final List<Place> places;

  @override
  Widget build(BuildContext context) {
    Set<Marker> markers = places
        .map(
          (place) => Marker(
            markerId: MarkerId(place.id),
            position: LatLng(
              place.location.latitude,
              place.location.longitude,
            ),
            infoWindow: InfoWindow(
              title: place.title,
              snippet: place.location.address,
            ),
          ),
        )
        .toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Places'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: places.isNotEmpty
              ? LatLng(
                  places[0].location.latitude,
                  places[0].location.longitude,
                )
              : const LatLng(0, 0),
          zoom: 10,
        ),
        markers: markers,
      ),
    );
  }
}

import 'package:favorite_places_app/screens/places_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/place.dart';
import '../providers/user_places.dart';
import '../screens/route_map.dart';

class PlacesList extends StatelessWidget {
  const PlacesList({super.key, required this.places, required this.ref});

  final List<Place> places;
  final WidgetRef ref;

  Future<void> _showShortestRoute(BuildContext context, Place place) async {
    bool serviceEnabled;
    LocationPermission permission;

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Location disabled'),
            content: const Text(
                'Location service is disabled. Please enable it in settings.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Location permission denied.'),
            ),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
                'Location permission permanently denied. Please enable it in settings.'),
          ),
        );
      }
      return;
    }

    try {
      final userLocation = await Geolocator.getCurrentPosition();
      final userLatLng = LatLng(userLocation.latitude, userLocation.longitude);

      final routePoints = await ref.read(userPlacesProvider.notifier).calculateShortestRoute(
        userLatLng,
        LatLng(place.location.latitude, place.location.longitude),
      );

      if (context.mounted) {
        navigator.push(
          MaterialPageRoute(
            builder: (ctx) => RouteMapScreen(
              routePoints: routePoints,
              destination: LatLng(place.location.latitude, place.location.longitude),
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to get location. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) {
      return Center(
        child: Text(
          'No places added yet',
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: places.length,
      itemBuilder: (ctx, index) => ListTile(
        leading: CircleAvatar(
          radius: 26,
          backgroundImage: FileImage(places[index].image),
        ),
        title: Text(
          places[index].title,
          style: Theme.of(context).textTheme.titleMedium!.copyWith(
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.directions,
                color: Colors.blue,
              ),
              onPressed: () => _showShortestRoute(context, places[index]),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete,
                color: Colors.red,
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete place?'),
                    content: const Text(
                        'Are you sure you want to delete this location? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(userPlacesProvider.notifier).removePlace(
                            places[index].id,
                          );
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Yes'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => PlaceDetailScreen(place: places[index]),
            ),
          );
        },
      ),
    );
  }
}
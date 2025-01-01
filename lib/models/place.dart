import 'dart:io';

import 'package:uuid/uuid.dart';

const uuid = Uuid();
enum PlaceStatus { pending, cleared }
enum PlaceType { home, business }

class PlaceLocation {
  const PlaceLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final double latitude;
  final double longitude;
  final String address;
}

class Place {
  Place({
    required this.title,
    required this.image,
    required this.location,
    this.type = PlaceType.home,
    this.status = PlaceStatus.pending,
    String? id,
  }) : id = id ?? uuid.v4();

  final String id;
  final String title;
  final File image;
  final PlaceLocation location;
  final PlaceType type;
  PlaceStatus status;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'image': image.path,
      'lat': location.latitude,
      'lng': location.longitude,
      'address': location.address,
      'type': type == PlaceType.home ? 0 : 1,
      'status': status == PlaceStatus.pending ? 0 : 1,
    };
  }

  factory Place.fromMap(Map<String, dynamic> map) {
    return Place(
      id: map['id'] as String,
      title: map['title'] as String,
      image: File(map['image'] as String),
      location: PlaceLocation(
        latitude: map['lat'] as double,
        longitude: map['lng'] as double,
        address: map['address'] as String,
      ),
      type: map['type'] == 0 ? PlaceType.home : PlaceType.business,
      status: map['status'] == 0 ? PlaceStatus.pending : PlaceStatus.cleared,
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;

import 'package:favorite_places_app/models/place.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart' as syspaths;
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sql;
import 'package:sqflite/sqlite_api.dart';

Future<Database> _getDatabase() async {
  final dbPath = await sql.getDatabasesPath();
  final db = await sql.openDatabase(
    path.join(dbPath, 'places.db'),
    onCreate: (db, version) {
      return db.execute(
          'CREATE TABLE user_places(id TEXT PRIMARY KEY, title TEXT, image TEXT, lat REAL, lng REAL, address TEXT,status INTEGER DEFAULT 0)');
    },
    version: 1,
  );
  return db;
}

//StateNotifier es una clase de Riverpod que te permite administrar un estado mutable
class UserPlacesNotifier extends StateNotifier<List<Place>> {
  UserPlacesNotifier() : super(const []);

  Future<void> loadPlaces() async {
    final db = await _getDatabase();
    final data = await db.query('user_places');
    final places = data.map((row) => Place.fromMap(row)).toList();
    state = places;
  }

  void addPlace(String title, File image, PlaceLocation location) async {
    final appDir = await syspaths.getApplicationDocumentsDirectory();
    final filename = path.basename(image.path);
    final copiedImage = await image.copy('${appDir.path}/$filename');

    final newPlace = Place(
      title: title,
      image: copiedImage,
      location: location,
    );

    final db = await _getDatabase();
    db.insert('user_places', newPlace.toMap());
    state = [newPlace, ...state];
  }

  Future<void> removePlace(String id) async {
    final db = await _getDatabase();
    await db.delete('user_places', where: 'id = ?', whereArgs: [id]);
    state = state.where((place) => place.id != id).toList();
  }

  Future<void> togglePlaceStatus(String id) async {
    final db = await _getDatabase();
    final place = state.firstWhere((place) => place.id == id);
    final newStatus = place.status == PlaceStatus.pending
        ? PlaceStatus.cleared
        : PlaceStatus.pending;

    await db.update(
      'user_places',
      {'status': newStatus == PlaceStatus.pending ? 0 : 1},
      where: 'id = ?',
      whereArgs: [id],
    );

    state = state.map((p) {
      if (p.id == id) {
        return Place(
          id: p.id,
          title: p.title,
          image: p.image,
          location: p.location,
          status: newStatus, // Cambiar solo el estado
        );
      }
      return p; // Devolver los demás lugares sin cambios
    }).toList();
  }

  Future<List<LatLng>> calculateShortestRoute(
      LatLng currentLocation, LatLng destination) async {
    const apiKey = 'AIzaSyDpdae-3Rbj4LgF-FLu8x3n46iT86izy2I';

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${currentLocation.latitude},${currentLocation.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&key=$apiKey',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['routes'].isNotEmpty) {
        final polyline = data['routes'][0]['overview_polyline']['points'];
        final points = PolylinePoints().decodePolyline(polyline);

        return points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
      }
    }
    return [];
  }
}

final userPlacesProvider =
    StateNotifierProvider<UserPlacesNotifier, List<Place>>(
  (ref) => UserPlacesNotifier(),
);

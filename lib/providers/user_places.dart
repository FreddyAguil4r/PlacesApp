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

//Configura y abre la base de datos SQLite
Future<Database> _getDatabase() async {
  final dbPath = await sql.getDatabasesPath();
  final db = await sql.openDatabase(
    path.join(dbPath, 'places.db'),
    onCreate: (db, version) {
      return db.execute(
          'CREATE TABLE user_places(id TEXT PRIMARY KEY, title TEXT, image TEXT, lat REAL, lng REAL, address TEXT)');
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
    final data = await db.query('user_places'); //consulta de todos los registros
    final places = data
        .map(
          (row) => Place(
            id: row['id'] as String,
            title: row['title'] as String,
            image: File(row['image'] as String),
            location: PlaceLocation(
              latitude: row['lat'] as double,
              longitude: row['lng'] as double,
              address: row['address'] as String,
            ),
          ),
        )
        .toList();

    state = places;
  }

  void addPlace(String title, File image, PlaceLocation location) async {
    final appDir = await syspaths.getApplicationDocumentsDirectory();
    final filename = path.basename(image.path);
    final copiedImage = await image.copy('${appDir.path}/$filename');

    final newPlace =
        Place(title: title, image: copiedImage, location: location);

    final db = await _getDatabase();
    db.insert('user_places', {
      'id': newPlace.id,
      'title': newPlace.title,
      'image': newPlace.image.path,
      'lat': newPlace.location.latitude,
      'lng': newPlace.location.longitude,
      'address': newPlace.location.address,
    });

    state = [newPlace, ...state];
  }

  Future<void> removePlace(String id) async {
    final db = await _getDatabase();
    await db.delete('user_places', where: 'id = ?', whereArgs: [id]);

    // Actualizar el estado eliminando el lugar correspondiente
    state = state.where((place) => place.id != id).toList();
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

//StateNotifierProvider es un tipo de proveedor que se usa para exponer.
//un StateNotifier a tu aplicación.
//UserPlacesNotifier es el tipo del StateNotifier.
//List<Place> es el tipo del estado que el StateNotifier expone.
final userPlacesProvider =
    StateNotifierProvider<UserPlacesNotifier, List<Place>>(
  (ref) => UserPlacesNotifier(),
);

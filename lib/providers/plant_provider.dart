import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/plant.dart';

class PlantProvider extends ChangeNotifier {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('plants');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Plant> _plants = [];
  List<Plant> get plants => _plants;

  PlantProvider() {
    fetchPlants();
  }

  void fetchPlants() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _plants = [];
      notifyListeners();
      return;
    }

    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
      _plants.clear();

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            final plant = Plant.fromMap(key.toString(), value);
            // Sadece bu kullanıcıya ait bitkileri al (Güvenli Veritabanı İzolasyonu)
            if (plant.userId == userId) {
              _plants.add(plant);
            }
          }
        });
      }
      notifyListeners();
    });
  }

  Future<void> addPlant({
    required String name,
    required String type,
    required String sensorId,
    required int minMoisture,
    required String imageUrl,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final newPlantRef = _dbRef.push();
    await newPlantRef.set({
      'userId': userId,
      'name': name,
      'type': type,
      'sensorId': sensorId,
      'moistureLevel': 50.0, // Başlangıç varsayılan nemi
      'minMoisture': minMoisture,
      'temperature': 24.0,
      'lightLevel': 60.0,
      'isPumpOn': false,
      'imageUrl': imageUrl,
    });
  }

  Future<void> deletePlant(String plantId) async {
    await _dbRef.child(plantId).remove();
  }

  Future<void> togglePump(String plantId, bool currentState) async {
    await _dbRef.child(plantId).update({'isPumpOn': currentState});
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/plant.dart';

class PlantProvider extends ChangeNotifier {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('plants');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Plant> _plants = [];
  List<Plant> get plants => _plants;

  StreamSubscription<DatabaseEvent>? _plantsSubscription;
  StreamSubscription<User?>? _authSubscription;

  PlantProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _listenToPlants(user.uid);
      } else {
        _clearPlants();
      }
    });
  }

  void _listenToPlants(String userId) {
    _plantsSubscription?.cancel();

    _plantsSubscription = _dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
      final List<Plant> loaded = [];

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            final plant = Plant.fromMap(key.toString(), value);
            if (plant.userId == userId) {
              loaded.add(plant);
            }
          }
        });
      }
      _plants = loaded;
      notifyListeners();
    }, onError: (error) {
      debugPrint("Bitki dinleme hatası: $error");
    });
  }

  void _clearPlants() {
    _plantsSubscription?.cancel();
    _plantsSubscription = null;
    _plants = [];
    notifyListeners();
  }

  Future<bool> addPlant({
    required String name,
    required String type,
    required String sensorId,
    required int minMoisture,
    required String imageUrl,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      final newPlantRef = _dbRef.push();
      await newPlantRef.set({
        'userId': userId,
        'name': name,
        'type': type,
        'sensorId': sensorId,
        'moistureLevel': 50.0,
        'minMoisture': minMoisture,
        'temperature': 24.0,
        'lightLevel': 60.0,
        'isPumpOn': false,
        'imageUrl': imageUrl,
      });
      return true;
    } catch (e) {
      debugPrint("Bitki ekleme hatası: $e");
      return false;
    }
  }

  // 4.2.7 Sensör ID'sini değiştirebilme
  Future<bool> updateSensorId(String plantId, String newSensorId) async {
    final trimmed = newSensorId.trim();
    if (trimmed.isEmpty) return false;

    final isUsed = _plants.any(
      (p) => p.id != plantId && p.sensorId.toLowerCase() == trimmed.toLowerCase(),
    );
    if (isUsed) return false;

    try {
      await _dbRef.child(plantId).update({'sensorId': trimmed});
      return true;
    } catch (e) {
      debugPrint("Sensör ID güncelleme hatası: $e");
      return false;
    }
  }

  Future<void> deletePlant(String plantId) async {
    try {
      await _dbRef.child(plantId).remove();
    } catch (e) {
      debugPrint("Bitki silme hatası: $e");
    }
  }

  Future<void> togglePump(String plantId, bool currentState) async {
    try {
      await _dbRef.child(plantId).update({'isPumpOn': currentState});
    } catch (e) {
      debugPrint("Pompa güncelleme hatası: $e");
    }
  }

  @override
  void dispose() {
    _plantsSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/plant.dart';

class PlantProvider extends ChangeNotifier {
  final DatabaseReference _rootRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Plant> _plants = [];
  List<Plant> get plants => _plants;

  bool _useLegacyPath = false;
  StreamSubscription<DatabaseEvent>? _plantsSubscription;
  StreamSubscription<User?>? _authSubscription;

  PlantProvider() {
    _initAuthListener();
  }

  DatabaseReference _userPlantsRef(String userId) {
    if (_useLegacyPath) {
      return _rootRef.child('plants');
    }
    return _rootRef.child('users').child(userId).child('plants');
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

    _plantsSubscription = _userPlantsRef(userId).onValue.listen((event) {
      final data = event.snapshot.value;
      final List<Plant> loaded = [];

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            final plant = Plant.fromMap(key.toString(), value);
            if (!_useLegacyPath || plant.userId == userId) {
              loaded.add(plant);
            }
          }
        });
      }

      // Kullanıcı düğümü henüz boşsa eski '/plants' düğümündeki bitkileri otomatik taşı
      if (loaded.isEmpty && !_useLegacyPath) {
        _migrateLegacyPlantsIfNeeded(userId);
      }

      _plants = loaded;
      notifyListeners();
    }, onError: (error) {
      // Güvenlik kuralları henüz güncellenmediyse kesintisiz olarak legacy yola dön
      if (!_useLegacyPath) {
        _useLegacyPath = true;
        _listenToPlants(userId);
      }
    });
  }

  Future<void> _migrateLegacyPlantsIfNeeded(String userId) async {
    try {
      final snapshot = await _rootRef.child('plants').get();
      if (snapshot.exists && snapshot.value is Map) {
        final map = snapshot.value as Map;
        for (final entry in map.entries) {
          if (entry.value is Map && entry.value['userId'] == userId) {
            await _rootRef
                .child('users')
                .child(userId)
                .child('plants')
                .child(entry.key.toString())
                .set(entry.value);
          }
        }
      }
    } catch (_) {}
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

    final profile = Plant.defaultProfileForType(type);
    final payload = {
      'userId': userId,
      'name': name,
      'type': type,
      'sensorId': sensorId,
      'moistureLevel': 50.0,
      'minMoisture': minMoisture,
      'maxMoisture': profile['maxMoisture'],
      'temperature': 24.0,
      'minTemp': profile['minTemp'],
      'maxTemp': profile['maxTemp'],
      'lightLevel': 60.0,
      'minLight': profile['minLight'],
      'maxLight': profile['maxLight'],
      'isPumpOn': false,
      'imageUrl': imageUrl,
    };

    try {
      await _userPlantsRef(userId).push().set(payload);
      return true;
    } catch (e) {
      // Fallback: users/$uid izni henüz yoksa mevcut /plants altına yaz
      try {
        _useLegacyPath = true;
        await _rootRef.child('plants').push().set(payload);
        _listenToPlants(userId);
        return true;
      } catch (inner) {
        debugPrint("Bitki ekleme hatası: $inner");
        return false;
      }
    }
  }

  Future<bool> updateSensorId(String plantId, String newSensorId) async {
    final userId = _auth.currentUser?.uid;
    final trimmed = newSensorId.trim();
    if (userId == null || trimmed.isEmpty) return false;

    final isUsed = _plants.any(
      (p) => p.id != plantId && p.sensorId.toLowerCase() == trimmed.toLowerCase(),
    );
    if (isUsed) return false;

    try {
      await _userPlantsRef(userId).child(plantId).update({'sensorId': trimmed});
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> deletePlant(String plantId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    try {
      await _userPlantsRef(userId).child(plantId).remove();
    } catch (e) {
      debugPrint("Bitki silme hatası: $e");
    }
  }

  Future<void> togglePump(String plantId, bool currentState) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    try {
      await _userPlantsRef(userId).child(plantId).update({'isPumpOn': currentState});
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
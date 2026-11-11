import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/plant.dart';

class PlantProvider extends ChangeNotifier {
  final DatabaseReference _rootRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Plant> _plants = [];
  String? _lastError;

  List<Plant> get plants => _plants;
  String? get lastError => _lastError;

  StreamSubscription<DatabaseEvent>? _plantsSubscription;
  StreamSubscription<User?>? _authSubscription;

  PlantProvider() {
    _initAuthListener();
  }

  DatabaseReference _userPlantsRef(String userId) {
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
      _lastError = null;
      final data = event.snapshot.value;
      final List<Plant> loaded = [];

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            loaded.add(Plant.fromMap(key.toString(), value));
          }
        });
      }
      _plants = loaded;
      notifyListeners();
    }, onError: (error) {
      _lastError = "Veritabanı erişim hatası (Firebase Rules kontrol edin): $error";
      debugPrint(_lastError);
      notifyListeners();
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
      _lastError = "Bitki kaydedilemedi: $e";
      debugPrint(_lastError);
      return false;
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
      // Bitki silindiğinde ilişkili otomatik görevleri de temizle
      final todosSnap = await _rootRef.child('users').child(userId).child('todos').get();
      if (todosSnap.exists && todosSnap.value is Map) {
        final map = todosSnap.value as Map;
        for (final entry in map.entries) {
          if (entry.value is Map && entry.value['plantId'] == plantId) {
            await _rootRef
                .child('users')
                .child(userId)
                .child('todos')
                .child(entry.key.toString())
                .remove();
          }
        }
      }
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
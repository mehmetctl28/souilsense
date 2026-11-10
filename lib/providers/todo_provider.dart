import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/todo.dart';
import '../models/plant.dart';
import '../models/sensor_data.dart';

class TodoProvider extends ChangeNotifier {
  final DatabaseReference _rootRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Todo> _todos = [];
  List<Todo> get todos => _todos;

  bool _useLegacyPath = false;
  bool _isSyncingAuto = false;
  String _lastEvaluatedSignature = '';

  StreamSubscription<DatabaseEvent>? _todosSubscription;
  StreamSubscription<User?>? _authSubscription;

  TodoProvider() {
    _initAuthListener();
  }

  DatabaseReference _userTodosRef(String userId) {
    if (_useLegacyPath) {
      return _rootRef.child('todos');
    }
    return _rootRef.child('users').child(userId).child('todos');
  }

  void _initAuthListener() {
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _listenToTodos(user.uid);
      } else {
        _clearTodos();
      }
    });
  }

  void _listenToTodos(String userId) {
    _todosSubscription?.cancel();

    _todosSubscription = _userTodosRef(userId).onValue.listen((event) {
      final data = event.snapshot.value;
      final List<Todo> loaded = [];

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            final todo = Todo.fromMap(key.toString(), value);
            if (!_useLegacyPath || todo.userId == userId) {
              loaded.add(todo);
            }
          }
        });
      }
      _todos = loaded;
      notifyListeners();
    }, onError: (error) {
      if (!_useLegacyPath) {
        _useLegacyPath = true;
        _listenToTodos(userId);
      }
    });
  }

  void _clearTodos() {
    _todosSubscription?.cancel();
    _todosSubscription = null;
    _todos = [];
    _lastEvaluatedSignature = '';
    notifyListeners();
  }

  // 2.C: Yalnızca sensör nemi veya bitki eşiği değiştiğinde tetiklenir
  void onTelemetryOrPlantsUpdated(List<Plant> plants, Map<String, SensorData> sensors) {
    if (plants.isEmpty) return;

    final buffer = StringBuffer();
    for (final p in plants) {
      final m = sensors[p.sensorId]?.moisture ?? p.moistureLevel;
      final isThirsty = m < p.minMoisture;
      buffer.write('${p.id}:${p.minMoisture}:$isThirsty|');
    }

    final currentSignature = buffer.toString();
    if (currentSignature == _lastEvaluatedSignature) {
      return; // Hiçbir bitkinin eşik durumu değişmedi, gereksiz işlem yapma
    }

    _lastEvaluatedSignature = currentSignature;
    syncAutoTasks(plants, sensors);
  }

  Future<void> syncAutoTasks(List<Plant> plants, [Map<String, SensorData>? sensors]) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || _isSyncingAuto) return;

    _isSyncingAuto = true;
    try {
      for (var plant in plants) {
        final liveMoisture = sensors != null && sensors.containsKey(plant.sensorId)
            ? sensors[plant.sensorId]!.moisture
            : plant.moistureLevel;

        final bool isThirsty = liveMoisture < plant.minMoisture;

        final existingActiveAutoTodo = _todos.firstWhere(
          (t) => t.plantId == plant.id && t.isAuto && !t.isCompleted,
          orElse: () => Todo(id: '', userId: '', title: ''),
        );

        if (isThirsty && existingActiveAutoTodo.id.isEmpty) {
          await _userTodosRef(userId).push().set({
            'userId': userId,
            'title': 'Sula: ${plant.name}',
            'isCompleted': false,
            'isAuto': true,
            'plantId': plant.id,
            'category': 'Sulama',
            'priority': 'Yüksek',
            'dueDate': 'Bugün',
            'description':
                'Toprak nemi %${liveMoisture.toInt()} seviyesine düştü (Minimum sınır: %${plant.minMoisture}).',
          });
        } else if (!isThirsty && existingActiveAutoTodo.id.isNotEmpty) {
          await _userTodosRef(userId).child(existingActiveAutoTodo.id).update({
            'isCompleted': true,
            'description': 'Sulama tamamlandı, nem referans aralığına ulaştı.',
          });
        }
      }
    } catch (e) {
      debugPrint("Otomatik görev senkronizasyon uyarısı: $e");
    } finally {
      _isSyncingAuto = false;
    }
  }

  Future<bool> addTodo(
    String title, {
    String category = 'Sulama',
    String priority = 'Normal',
    String dueDate = 'Bugün',
    String description = '',
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || title.trim().isEmpty) return false;

    final payload = {
      'userId': userId,
      'title': title.trim(),
      'isCompleted': false,
      'isAuto': false,
      'category': category,
      'priority': priority,
      'dueDate': dueDate,
      'description': description,
    };

    try {
      await _userTodosRef(userId).push().set(payload);
      return true;
    } catch (e) {
      try {
        _useLegacyPath = true;
        await _rootRef.child('todos').push().set(payload);
        _listenToTodos(userId);
        return true;
      } catch (inner) {
        return false;
      }
    }
  }

  Future<void> toggleTodo(String todoId, bool currentStatus) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    try {
      await _userTodosRef(userId).child(todoId).update({'isCompleted': !currentStatus});
    } catch (e) {
      debugPrint("Görev güncelleme hatası: $e");
    }
  }

  Future<void> deleteTodo(String todoId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    try {
      await _userTodosRef(userId).child(todoId).remove();
    } catch (e) {
      debugPrint("Görev silme hatası: $e");
    }
  }

  @override
  void dispose() {
    _todosSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
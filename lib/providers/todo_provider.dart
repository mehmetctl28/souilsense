import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/todo.dart';
import '../models/plant.dart';
import '../models/sensor_data.dart';

class TodoProvider extends ChangeNotifier {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('todos');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Todo> _todos = [];
  List<Todo> get todos => _todos;

  StreamSubscription<DatabaseEvent>? _todosSubscription;
  StreamSubscription<User?>? _authSubscription;
  bool _isSyncingAuto = false;

  TodoProvider() {
    _initAuthListener();
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

    _todosSubscription = _dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
      final List<Todo> loaded = [];

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            final todo = Todo.fromMap(key.toString(), value);
            if (todo.userId == userId) {
              loaded.add(todo);
            }
          }
        });
      }
      _todos = loaded;
      notifyListeners();
    }, onError: (error) {
      debugPrint("Görev dinleme hatası: $error");
    });
  }

  void _clearTodos() {
    _todosSubscription?.cancel();
    _todosSubscription = null;
    _todos = [];
    notifyListeners();
  }

  // 6. Bölüm: Olay tabanlı (Event-driven) otomatik görev senkronizasyonu
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
          await _dbRef.push().set({
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
          await _dbRef.child(existingActiveAutoTodo.id).update({
            'isCompleted': true,
            'description': 'Sulama tamamlandı, nem ideal seviyeye ulaştı.',
          });
        }
      }
    } catch (e) {
      debugPrint("Otomatik görev senkronizasyon hatası: $e");
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

    try {
      await _dbRef.push().set({
        'userId': userId,
        'title': title.trim(),
        'isCompleted': false,
        'isAuto': false,
        'category': category,
        'priority': priority,
        'dueDate': dueDate,
        'description': description,
      });
      return true;
    } catch (e) {
      debugPrint("Görev ekleme hatası: $e");
      return false;
    }
  }

  Future<void> toggleTodo(String todoId, bool currentStatus) async {
    try {
      await _dbRef.child(todoId).update({'isCompleted': !currentStatus});
    } catch (e) {
      debugPrint("Görev güncelleme hatası: $e");
    }
  }

  Future<void> deleteTodo(String todoId) async {
    try {
      await _dbRef.child(todoId).remove();
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
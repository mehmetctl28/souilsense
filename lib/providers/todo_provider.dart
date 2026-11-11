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

  // Aktif, Otomatik Geçmiş ve Manuel Geçmiş listeleri ayrı sunulur
  List<Todo> get activeTodos => _todos.where((t) => !t.isCompleted).toList();
  List<Todo> get completedAutoTodos =>
      _todos.where((t) => t.isCompleted && t.isAuto).toList();
  List<Todo> get completedManualTodos =>
      _todos.where((t) => t.isCompleted && !t.isAuto).toList();

  bool _isInitialLoadComplete = false;
  bool _isSyncingAuto = false;
  String _lastEvaluatedSignature = '';

  StreamSubscription<DatabaseEvent>? _todosSubscription;
  StreamSubscription<User?>? _authSubscription;

  TodoProvider() {
    _initAuthListener();
  }

  DatabaseReference _userTodosRef(String userId) {
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
    _isInitialLoadComplete = false;

    _todosSubscription = _userTodosRef(userId).onValue.listen((event) {
      final data = event.snapshot.value;
      final List<Todo> loaded = [];

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            loaded.add(Todo.fromMap(key.toString(), value));
          }
        });
      }
      loaded.sort((a, b) => a.dueTimestamp.compareTo(b.dueTimestamp));
      _todos = loaded;
      _isInitialLoadComplete = true;
      notifyListeners();
    }, onError: (error) {
      debugPrint("Görev dinleme hatası: $error");
    });
  }

  void _clearTodos() {
    _todosSubscription?.cancel();
    _todosSubscription = null;
    _todos = [];
    _isInitialLoadComplete = false;
    _lastEvaluatedSignature = '';
    notifyListeners();
  }

  void onTelemetryOrPlantsUpdated(List<Plant> plants, Map<String, SensorData> sensors) {
    if (!_isInitialLoadComplete) return;

    final buffer = StringBuffer();
    for (final p in plants) {
      final m = (sensors[p.sensorId]?.moisture ?? p.moistureLevel).round();
      final isThirsty = m < p.minMoisture;
      buffer.write('${p.id}:${p.minMoisture}:$isThirsty:$m|');
    }

    final currentSignature = buffer.toString();
    if (currentSignature == _lastEvaluatedSignature) return;

    _lastEvaluatedSignature = currentSignature;
    syncAutoTasks(plants, sensors);
  }

  Future<void> syncAutoTasks(List<Plant> plants, [Map<String, SensorData>? sensors]) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || !_isInitialLoadComplete || _isSyncingAuto) return;

    _isSyncingAuto = true;
    try {
      final activePlantIds = plants.map((p) => p.id).toSet();

      // Bitki silindiyse ilişkili otomatik görevleri temizle
      for (final t in List<Todo>.from(_todos)) {
        if (t.isAuto && t.plantId != null && !activePlantIds.contains(t.plantId)) {
          await _userTodosRef(userId).child(t.id).remove();
        }
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;

      for (final plant in plants) {
        final liveMoisture = sensors != null && sensors.containsKey(plant.sensorId)
            ? sensors[plant.sensorId]!.moisture
            : plant.moistureLevel;

        final bool isThirsty = liveMoisture < plant.minMoisture;
        final String autoTaskKey = 'auto_water_${plant.id}';

        final existingActiveAutoTodo = _todos.firstWhere(
          (t) => (t.id == autoTaskKey || t.plantId == plant.id) && t.isAuto && !t.isCompleted,
          orElse: () => Todo(id: '', userId: '', title: '', dueTimestamp: nowMs),
        );

        final String updatedDesc =
            'Toprak nemi %${liveMoisture.toInt()} seviyesinde (Alt eşik: %${plant.minMoisture}).';

        if (isThirsty && existingActiveAutoTodo.id.isEmpty) {
          await _userTodosRef(userId).child(autoTaskKey).set({
            'userId': userId,
            'title': 'Sula: ${plant.name}',
            'isCompleted': false,
            'isAuto': true,
            'plantId': plant.id,
            'category': 'Sulama',
            'priority': 'Yüksek',
            'dueTimestamp': nowMs,
            'description': updatedDesc,
          });
        } else if (isThirsty &&
            existingActiveAutoTodo.id.isNotEmpty &&
            existingActiveAutoTodo.description != updatedDesc) {
          await _userTodosRef(userId).child(existingActiveAutoTodo.id).update({
            'description': updatedDesc,
          });
        } else if (!isThirsty && existingActiveAutoTodo.id.isNotEmpty) {
          // Otomatik görevi silmek yerine arşiv/geçmiş için tamamlandı işaretler ve yeni arşiv kaydına taşır
          final completedPayload = existingActiveAutoTodo.toMap()
            ..['isCompleted'] = true
            ..['completedAt'] = nowMs
            ..['description'] =
                'Sulama tamamlandı, nem %${liveMoisture.toInt()} ile referans aralığına ulaştı.';

          await _userTodosRef(userId).push().set(completedPayload);
          await _userTodosRef(userId).child(existingActiveAutoTodo.id).remove();
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
    DateTime? dueDate,
    String description = '',
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || title.trim().isEmpty) return false;

    final targetDate = dueDate ?? DateTime.now();

    try {
      await _userTodosRef(userId).push().set({
        'userId': userId,
        'title': title.trim(),
        'isCompleted': false,
        'isAuto': false,
        'category': category,
        'priority': priority,
        'dueTimestamp': targetDate.millisecondsSinceEpoch,
        'description': description,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> toggleTodo(String todoId, bool currentStatus) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    try {
      await _userTodosRef(userId).child(todoId).update({
        'isCompleted': !currentStatus,
        'completedAt': !currentStatus ? DateTime.now().millisecondsSinceEpoch : null,
      });
    } catch (_) {}
  }

  Future<void> deleteTodo(String todoId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    try {
      await _userTodosRef(userId).child(todoId).remove();
    } catch (_) {}
  }

  @override
  void dispose() {
    _todosSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
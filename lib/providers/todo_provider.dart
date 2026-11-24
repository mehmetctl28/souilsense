import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/realtime_store.dart';
import '../models/todo.dart';
import '../models/plant.dart';
import '../models/sensor_data.dart';

class TodoProvider extends ChangeNotifier {
  final RealtimeStore _store;
  List<Todo> _live = [], _simulation = [];
  bool _hardwareMode = false,
      _loaded = false,
      _syncing = false,
      _disposed = false;
  String? _uid;
  int _epoch = 0;
  StreamSubscription<Object?>? _todosSubscription;
  StreamSubscription<String?>? _authSubscription;
  String _signature = '';
  List<Plant> _latestPlants = [];
  Map<String, SensorData> _latestSensors = {};
  List<Todo> get todos =>
      List.unmodifiable(_hardwareMode ? _live : _simulation);
  List<Todo> get activeTodos => todos.where((t) => !t.isCompleted).toList();
  List<Todo> get completedAutoTodos =>
      todos.where((t) => t.isCompleted && t.isAuto).toList();
  List<Todo> get completedManualTodos =>
      todos.where((t) => t.isCompleted && !t.isAuto).toList();

  TodoProvider({RealtimeStore? store})
      : _store = store ?? FirebaseRealtimeStore() {
    _uid = _store.uid;
    _authSubscription = _store.authChanges.listen((uid) {
      if (uid == _uid) return;
      _uid = uid;
      _epoch++;
      _signature = '';
      _loaded = false;
      _todosSubscription?.cancel();
      _live = [];
      _simulation = [];
      _latestPlants = [];
      _latestSensors = {};
      if (_hardwareMode) _listen();
      _notify();
    });
  }
  void _notify() => scheduleMicrotask(() {
        if (!_disposed) notifyListeners();
      });
  bool _current(int epoch, String? uid) =>
      !_disposed && epoch == _epoch && uid != null && uid == _store.uid;

  void _listen() {
    _todosSubscription?.cancel();
    _loaded = false;
    final epoch = _epoch, uid = _uid;
    if (uid == null) return;
    _todosSubscription = _store.watch('users/$uid/todos').listen((v) {
      if (!_current(epoch, uid) || !_hardwareMode) return;
      _live = v is Map
          ? v.entries
              .where((e) => e.value is Map)
              .map((e) => Todo.fromMap(e.key.toString(), e.value as Map))
              .toList()
          : [];
      _live.sort((a, b) => a.dueTimestamp.compareTo(b.dueTimestamp));
      _loaded = true;
      onTelemetryOrPlantsUpdated(_latestPlants, _latestSensors,
          isHardwareMode: true);
      _notify();
    }, onError: (Object _) {
      _loaded = false;
      _notify();
    });
  }

  void onTelemetryOrPlantsUpdated(
      List<Plant> plants, Map<String, SensorData> sensors,
      {bool isHardwareMode = false}) {
    if (_hardwareMode != isHardwareMode) {
      _hardwareMode = isHardwareMode;
      _epoch++;
      _signature = '';
      if (isHardwareMode) {
        _listen();
      } else {
        _todosSubscription?.cancel();
        _loaded = false;
      }
      _notify();
    }
    _latestPlants = List.of(plants);
    _latestSensors = Map.of(sensors);
    final eligible = plants.where((p) {
      final s = sensors[p.sensorId];
      return p.userId == _uid &&
          s != null &&
          s.isOnline &&
          s.isSimulated != _hardwareMode;
    }).toList();
    final signature = eligible
        .map((p) =>
            '${p.id}:${p.minMoisture}:${sensors[p.sensorId]!.moisture.round()}')
        .join('|');
    if (signature == _signature) return;
    if (!_hardwareMode) {
      final retained =
          _simulation.where((t) => !t.isAuto || t.isCompleted).toList();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final p in eligible) {
        final s = sensors[p.sensorId]!;
        if (s.moisture < p.minMoisture) {
          retained.add(Todo(
              id: 'sim_auto_${p.id}',
              userId: _uid ?? '',
              title: '[Simülasyon] Sula: ${p.name}',
              plantId: p.id,
              isAuto: true,
              dueTimestamp: now));
        } else {
          for (final t in _simulation
              .where((t) => t.isAuto && !t.isCompleted && t.plantId == p.id)) {
            retained.add(Todo.fromMap(
                'sim_done_${_store.newKey()}',
                t.toMap()
                  ..['isCompleted'] = true
                  ..['completedAt'] = now));
          }
        }
      }
      _simulation = retained;
      _signature = signature;
      _notify();
    } else if (_loaded && !_syncing) {
      _signature = signature;
      syncAutoTasks(eligible, sensors);
    }
  }

  Future<void> syncAutoTasks(List<Plant> plants,
      [Map<String, SensorData>? sensors]) async {
    final epoch = _epoch, uid = _uid;
    if (!_hardwareMode || !_loaded || _syncing || uid == null) return;
    _syncing = true;
    bool success = false;
    try {
      for (final p in plants) {
        if (!_current(epoch, uid) || !_hardwareMode) return;
        final s = sensors?[p.sensorId];
        if (p.userId != uid || s == null || s.isSimulated || !s.isOnline) {
          continue;
        }
        final key = 'auto_water_${p.id}';
        final matches =
            _live.where((t) => t.isAuto && !t.isCompleted && t.plantId == p.id);
        final existing = matches.isEmpty ? null : matches.first;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (s.moisture < p.minMoisture && existing == null) {
          await _store.set(
              'users/$uid/todos/$key',
              Todo(
                      id: key,
                      userId: uid,
                      title: 'Sula: ${p.name}',
                      plantId: p.id,
                      isAuto: true,
                      dueTimestamp: now,
                      description: 'Toprak nemi %${s.moisture.toInt()}')
                  .toMap());
        } else if (s.moisture >= p.minMoisture && existing != null) {
          // Archive and remove together; a mode/account change is checked before
          // the single write, rather than between two dependent writes.
          await _store.update('users/$uid/todos', {
            _store.newKey(): existing.toMap()
              ..['isCompleted'] = true
              ..['completedAt'] = now,
            existing.id: null,
          });
        }
      }
      success = true;
    } catch (_) {
      if (_current(epoch, uid)) _signature = '';
    } finally {
      _syncing = false;
      if (success && _current(epoch, uid)) {
        onTelemetryOrPlantsUpdated(_latestPlants, _latestSensors,
            isHardwareMode: _hardwareMode);
      }
    }
  }

  Future<bool> addTodo(String title,
      {String category = 'Sulama',
      String priority = 'Normal',
      DateTime? dueDate,
      String description = ''}) async {
    final uid = _uid;
    if (uid == null || title.trim().isEmpty) return false;
    final id = _store.newKey();
    final todo = Todo(
        id: id,
        userId: uid,
        title: title.trim(),
        category: category,
        priority: priority,
        dueTimestamp: (dueDate ?? DateTime.now()).millisecondsSinceEpoch,
        description: description);
    if (!_hardwareMode) {
      _simulation.add(todo);
      _notify();
      return true;
    }
    try {
      await _store.set('users/$uid/todos/$id', todo.toMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleTodo(String id, bool currentStatus) async {
    if (!_hardwareMode) {
      _simulation = _simulation
          .map((t) => t.id == id
              ? Todo.fromMap(
                  id,
                  t.toMap()
                    ..['isCompleted'] = !currentStatus
                    ..['completedAt'] = !currentStatus
                        ? DateTime.now().millisecondsSinceEpoch
                        : null)
              : t)
          .toList();
      _notify();
      return;
    }
    final uid = _uid;
    if (uid != null) {
      await _store.update('users/$uid/todos/$id', {
        'isCompleted': !currentStatus,
        'completedAt':
            !currentStatus ? DateTime.now().millisecondsSinceEpoch : null,
      });
    }
  }

  Future<void> deleteTodo(String id) async {
    if (!_hardwareMode) {
      _simulation.removeWhere((t) => t.id == id);
      _notify();
      return;
    }
    final uid = _uid;
    if (uid != null) await _store.set('users/$uid/todos/$id', null);
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _todosSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}

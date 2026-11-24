import 'dart:async';
import 'package:demo_app/services/realtime_store.dart';

class FakeStore implements RealtimeStore {
  String? _uid = 'user-a';
  final root = <String, Object?>{};
  final writes = <String>[];
  final _auth = StreamController<String?>.broadcast();
  final _watchers = <String, StreamController<Object?>>{};
  Completer<void>? transactionGate;
  bool failWrites = false;
  int _keys = 0;
  @override
  String? get uid => _uid;
  @override
  Stream<String?> get authChanges => _auth.stream;
  void login(String? value) {
    _uid = value;
    _auth.add(value);
  }

  Object? value(String path) {
    Object? v = root;
    for (final key in path.split('/')) {
      v = v is Map ? v[key] : null;
    }
    return v;
  }

  void seed(String path, Object? value) {
    Map<String, Object?> node = root;
    final parts = path.split('/');
    for (final key in parts.take(parts.length - 1)) {
      if (node[key] is! Map<String, Object?>) node[key] = <String, Object?>{};
      node = node[key] as Map<String, Object?>;
    }
    if (value == null) {
      node.remove(parts.last);
    } else {
      node[parts.last] = value;
    }
    for (final entry in _watchers.entries) {
      if (path == entry.key ||
          path.startsWith('${entry.key}/') ||
          entry.key.startsWith('$path/')) {
        entry.value.add(this.value(entry.key));
      }
    }
  }

  @override
  Stream<Object?> watch(String path) async* {
    final changes = _watchers.putIfAbsent(
        path, () => StreamController<Object?>.broadcast());
    yield value(path);
    yield* changes.stream;
  }

  @override
  Future<Object?> read(String path) async => value(path);
  @override
  Future<void> set(String path, Object? data) async {
    if (failWrites) throw StateError('offline');
    writes.add(path);
    seed(path, data);
  }

  @override
  Future<void> update(String path, Map<String, Object?> data) async {
    if (failWrites) throw StateError('offline');
    writes.add(path);
    data.forEach((key, v) => seed('$path/$key', v));
  }

  @override
  Future<bool> transaction(
      String path, Object? Function(Object?) transform) async {
    if (transactionGate != null) await transactionGate!.future;
    if (failWrites) throw StateError('offline');
    final next = transform(value(path));
    if (next == null) return false;
    writes.add(path);
    seed(path, next);
    return true;
  }

  @override
  String newKey() => 'test-command-${(++_keys).toString().padLeft(8, '0')}';
  Future<void> close() async {
    await _auth.close();
    for (final c in _watchers.values) {
      await c.close();
    }
  }
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 15));

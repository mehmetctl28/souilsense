import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// The I/O boundary also lets provider tests run without a live Firebase project.
abstract class RealtimeStore {
  String? get uid;
  Stream<String?> get authChanges;
  Stream<Object?> watch(String path);
  Future<Object?> read(String path);
  Future<void> set(String path, Object? value);
  Future<void> update(String path, Map<String, Object?> value);
  Future<bool> transaction(
      String path, Object? Function(Object? current) transform);
  String newKey();
}

class FirebaseRealtimeStore implements RealtimeStore {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _root = FirebaseDatabase.instance.ref();

  @override
  String? get uid => _auth.currentUser?.uid;
  @override
  Stream<String?> get authChanges =>
      _auth.authStateChanges().map((u) => u?.uid);
  @override
  Stream<Object?> watch(String path) =>
      _root.child(path).onValue.map((e) => e.snapshot.value);
  @override
  Future<Object?> read(String path) async =>
      (await _root.child(path).get()).value;
  @override
  Future<void> set(String path, Object? value) => _root.child(path).set(value);
  @override
  Future<void> update(String path, Map<String, Object?> value) =>
      _root.child(path).update(value);
  @override
  String newKey() => _root.push().key!;
  @override
  Future<bool> transaction(
      String path, Object? Function(Object? current) transform) async {
    final result = await _root.child(path).runTransaction((current) {
      final next = transform(current);
      return next == null ? Transaction.abort() : Transaction.success(next);
    }, applyLocally: false);
    return result.committed;
  }
}

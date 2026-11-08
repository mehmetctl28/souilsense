import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/todo.dart';
import '../models/plant.dart';

class TodoProvider extends ChangeNotifier {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('todos');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Todo> _todos = [];
  List<Todo> get todos => _todos;

  TodoProvider() {
    fetchTodos();
  }

  void fetchTodos() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _todos = [];
      notifyListeners();
      return;
    }

    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
      _todos.clear();

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            final todo = Todo.fromMap(key.toString(), value);
            if (todo.userId == userId) {
              _todos.add(todo);
            }
          }
        });
      }
      notifyListeners();
    });
  }

  // Bitkilerin nem durumuna göre otomatik sula görevi oluştur
  void syncAutoTasks(List<Plant> plants) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    for (var plant in plants) {
      bool isThirsty = plant.moistureLevel < plant.minMoisture;
      
      // Bu bitki için daha önce eklenmiş otomatik görev var mı?
      final existingAutoTodo = _todos.firstWhere(
        (t) => t.plantId == plant.id && t.isAuto,
        orElse: () => Todo(id: '', userId: '', title: ''),
      );

      if (isThirsty && existingAutoTodo.id.isEmpty) {
        // Susamış ve henüz görevi yok -> Otomatik görev ekle
        await _dbRef.push().set({
          'userId': userId,
          'title': 'Sula: ${plant.name}',
          'isCompleted': false,
          'isAuto': true,
          'plantId': plant.id,
        });
      } else if (!isThirsty && existingAutoTodo.id.isNotEmpty) {
        // Artık susuz değil -> Otomatik görevi kaldır
        await _dbRef.child(existingAutoTodo.id).remove();
      }
    }
  }

  Future<void> addTodo(String title) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || title.trim().isEmpty) return;

    await _dbRef.push().set({
      'userId': userId,
      'title': title.trim(),
      'isCompleted': false,
      'isAuto': false,
    });
  }

  Future<void> toggleTodo(String todoId, bool currentStatus) async {
    await _dbRef.child(todoId).update({'isCompleted': !currentStatus});
  }

  Future<void> deleteTodo(String todoId) async {
    await _dbRef.child(todoId).remove();
  }
}
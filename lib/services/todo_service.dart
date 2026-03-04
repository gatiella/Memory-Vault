import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/todo.dart';
import 'drive_service.dart';

class TodoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DriveService _driveService = DriveService();

  // ── Stream: real-time todos ───────────────────────────────────
  Stream<List<Todo>> getTodos() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Todo.fromFirestore(doc)).toList());
  }

  // ── Fetch all todos once ──────────────────────────────────────
  Future<List<Todo>> getAllTodos() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .get();

    return snapshot.docs.map((doc) => Todo.fromFirestore(doc)).toList();
  }

  // ── Add a new todo ────────────────────────────────────────────
  Future<Todo> addTodo(Todo todo) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final docRef = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .add(todo.toMap());

    final saved = todo.copyWith(id: docRef.id);
    _syncAllTodosToDrive();
    return saved;
  }

  // ── Update an existing todo ───────────────────────────────────
  Future<void> updateTodo(Todo todo) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .doc(todo.id)
        .update(todo.toMap());

    _syncAllTodosToDrive();
  }

  // ── Delete a single todo ──────────────────────────────────────
  Future<void> deleteTodo(String todoId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .doc(todoId)
        .delete();

    _syncAllTodosToDrive();
  }

  // ── Delete all completed todos ────────────────────────────────
  Future<void> deleteCompletedTodos() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final batch = _firestore.batch();
    final completedTodos = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .where('isCompleted', isEqualTo: true)
        .get();

    for (var doc in completedTodos.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    _syncAllTodosToDrive();
  }

  // ── Remove reminder from a todo ───────────────────────────────
  Future<void> removeReminderFromTodo(String todoId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .doc(todoId)
        .update({'reminderTime': null});

    _syncAllTodosToDrive();
  }

  // ── Fire-and-forget: fetch latest todos then push to Drive ────
  //
  // We always push the full list so todos.json in Drive stays
  // consistent with Firestore without needing per-item Drive files.
  void _syncAllTodosToDrive() {
    getAllTodos().then((todos) {
      _driveService.saveTodos(todos).catchError((e) {
        print('Drive sync error (saveTodos): $e');
      });
    }).catchError((e) {
      print('Drive sync error (getAllTodos): $e');
    });
  }
}
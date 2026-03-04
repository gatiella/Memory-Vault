import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/note.dart';
import 'drive_service.dart';

class NoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DriveService _driveService = DriveService();

  // ── Stream: real-time notes for the logged-in user ───────────
  Stream<List<Note>> getNotes() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notes')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Note.fromFirestore(doc)).toList());
  }

  // ── Fetch all notes once ──────────────────────────────────────
  Future<List<Note>> getAllNotes() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notes')
          .get();

      return snapshot.docs.map((doc) => Note.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error retrieving notes: $e');
      return [];
    }
  }

  // ── Upsert with pre-generated ID (prevents offline duplicates) ──
  Future<void> saveNote(Note note) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notes')
        .doc(note.id)
        .set({
      'title': note.title,
      'content': note.content,
      'color': note.color,
      'createdAt': Timestamp.fromDate(note.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _syncNoteToDrive(note.copyWith(updatedAt: DateTime.now()));
  }

  // ── Add a new note ────────────────────────────────────────────
  Future<DocumentReference<Map<String, dynamic>>> addNote(Note note) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final docRef = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notes')
        .add({
      'title': note.title,
      'content': note.content,
      'color': note.color,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Sync to Drive in the background — Firebase is the source of truth
    _syncNoteToDrive(note.copyWith(id: docRef.id, updatedAt: DateTime.now()));

    return docRef;
  }

  // ── Update an existing note ───────────────────────────────────
  Future<void> updateNote(Note note) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notes')
        .doc(note.id)
        .update({
      'title': note.title,
      'content': note.content,
      'color': note.color,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _syncNoteToDrive(note.copyWith(updatedAt: DateTime.now()));
  }

  // ── Delete a note ─────────────────────────────────────────────
  Future<void> deleteNote(String noteId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notes')
        .doc(noteId)
        .delete();

    _deleteNoteFromDrive(noteId);
  }

  // ── Fire-and-forget Drive helpers ─────────────────────────────
  void _syncNoteToDrive(Note note) {
    _driveService.saveNote(note).catchError((e) {
      print('Drive sync error (saveNote): $e');
    });
  }

  void _deleteNoteFromDrive(String noteId) {
    _driveService.deleteNote(noteId).catchError((e) {
      print('Drive sync error (deleteNote): $e');
    });
  }
}
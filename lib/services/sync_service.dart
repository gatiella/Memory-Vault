import 'note_service.dart';
import 'todo_service.dart';
import 'drive_service.dart';

/// SyncService pushes the current Firebase data to Google Drive.
/// Drive is a backup — Firebase is always the source of truth.
/// There is no two-way conflict resolution needed.
class SyncService {
  final NoteService _noteService = NoteService();
  final TodoService _todoService = TodoService();
  final DriveService _driveService = DriveService();

  /// Push all notes from Firebase → Drive (full resync).
  Future<void> syncNotes() async {
    final notes = await _noteService.getAllNotes();
    for (final note in notes) {
      await _driveService.saveNote(note);
    }
  }

  /// Push all todos from Firebase → Drive (full resync).
  Future<void> syncTodos() async {
    final todos = await _todoService.getAllTodos();
    await _driveService.saveTodos(todos);
  }

  /// Push everything at once — useful on login or app resume.
  Future<void> syncAll() async {
    await Future.wait([
      syncNotes(),
      syncTodos(),
    ]);
  }
}
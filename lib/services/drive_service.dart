import 'dart:async';
import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/note.dart';
import '../models/todo.dart';

// ─────────────────────────────────────────────────────────────
//  Auth client (unchanged from your original)
// ─────────────────────────────────────────────────────────────
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

// ─────────────────────────────────────────────────────────────
//  DriveService
// ─────────────────────────────────────────────────────────────
class DriveService {
  // Use drive.file so files are visible in Google Drive (not hidden appdata)
  static const _scopes = [drive.DriveApi.driveFileScope];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '1078261651972-jaf3lbafgt4998em1ihbvejeb64du9ss.apps.googleusercontent.com'
        : null,
    scopes: _scopes,
  );

  // Folder IDs are cached for the session to avoid repeated API lookups
  String? _myNotesFolderId;
  String? _notesFolderId;
  String? _todosFolderId;

  // ── Internal: get an authenticated Drive API client ──────────
  Future<drive.DriveApi> _getDriveApi() async {
    GoogleSignInAccount? account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    account ??= await _googleSignIn.signIn();
    if (account == null) throw Exception('Google sign-in failed or was cancelled');

    final auth = await account.authHeaders;
    return drive.DriveApi(GoogleAuthClient(auth));
  }

  // ── Internal: find a folder by name under a given parent ─────
  Future<String?> _findFolder(
    drive.DriveApi api, {
    required String name,
    required String parentId,
  }) async {
    final result = await api.files.list(
      q: "mimeType='application/vnd.google-apps.folder' "
          "and name='$name' "
          "and '$parentId' in parents "
          "and trashed=false",
      $fields: 'files(id)',
      spaces: 'drive',
    );
    return result.files?.isNotEmpty == true ? result.files!.first.id : null;
  }

  // ── Internal: create a folder under a given parent ───────────
  Future<String> _createFolder(
    drive.DriveApi api, {
    required String name,
    required String parentId,
  }) async {
    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = [parentId];
    final created = await api.files.create(folder, $fields: 'id');
    return created.id!;
  }

  // ── Internal: get-or-create a folder, caching the result ─────
  Future<String> _getOrCreateFolder(
    drive.DriveApi api, {
    required String name,
    required String parentId,
  }) async {
    final existing = await _findFolder(api, name: name, parentId: parentId);
    return existing ?? await _createFolder(api, name: name, parentId: parentId);
  }

  // ── Internal: ensure MyNotes/Notes and MyNotes/Todos exist ───
  Future<void> _ensureFolders(drive.DriveApi api) async {
    if (_notesFolderId != null && _todosFolderId != null) return;

    // Root-level MyNotes folder
    _myNotesFolderId ??= await _getOrCreateFolder(
      api,
      name: 'MyNotes',
      parentId: 'root',
    );

    // Notes subfolder
    _notesFolderId ??= await _getOrCreateFolder(
      api,
      name: 'Notes',
      parentId: _myNotesFolderId!,
    );

    // Todos subfolder
    _todosFolderId ??= await _getOrCreateFolder(
      api,
      name: 'Todos',
      parentId: _myNotesFolderId!,
    );
  }

  // ── Internal: find a file by name inside a folder ────────────
  Future<String?> _findFile(
    drive.DriveApi api, {
    required String name,
    required String parentId,
  }) async {
    final result = await api.files.list(
      q: "name='$name' and '$parentId' in parents and trashed=false",
      $fields: 'files(id)',
      spaces: 'drive',
    );
    return result.files?.isNotEmpty == true ? result.files!.first.id : null;
  }

  // ── Internal: upload raw bytes, creating or overwriting a file
  Future<String> _uploadFile(
    drive.DriveApi api, {
    required String name,
    required String parentId,
    required List<int> bytes,
    required String mimeType,
  }) async {
    final existingId = await _findFile(api, name: name, parentId: parentId);
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: mimeType,
    );

    if (existingId != null) {
      // Overwrite existing file (no parent change needed on update)
      await api.files.update(
        drive.File()..name = name,
        existingId,
        uploadMedia: media,
        $fields: 'id',
      );
      return existingId;
    } else {
      // Create new file
      final file = drive.File()
        ..name = name
        ..parents = [parentId];
      final created = await api.files.create(
        file,
        uploadMedia: media,
        $fields: 'id',
      );
      return created.id!;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  PUBLIC API — Notes
  // ─────────────────────────────────────────────────────────────

  /// Save (create or overwrite) a single note in MyNotes/Notes/<title>.txt
  Future<void> saveNote(Note note) async {
    try {
      final api = await _getDriveApi();
      await _ensureFolders(api);

      // File name uses the note's Firestore ID so renames don't duplicate files
      final fileName = '${note.id}.txt';

      // Store title + content separated by a line so we can reconstruct it
      final fileContent = jsonEncode({
        'id': note.id,
        'title': note.title,
        'content': note.content,
        'color': note.color,
        'createdAt': note.createdAt.toIso8601String(),
        'updatedAt': note.updatedAt.toIso8601String(),
      });

      await _uploadFile(
        api,
        name: fileName,
        parentId: _notesFolderId!,
        bytes: utf8.encode(fileContent),
        mimeType: 'text/plain',
      );
    } catch (e) {
      debugPrint('DriveService.saveNote error: $e');
      rethrow;
    }
  }

  /// Delete a note file from MyNotes/Notes/
  Future<void> deleteNote(String noteId) async {
    try {
      final api = await _getDriveApi();
      await _ensureFolders(api);

      final fileId = await _findFile(
        api,
        name: '$noteId.txt',
        parentId: _notesFolderId!,
      );
      if (fileId != null) {
        await api.files.delete(fileId);
      }
    } catch (e) {
      debugPrint('DriveService.deleteNote error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  PUBLIC API — Todos
  // ─────────────────────────────────────────────────────────────

  /// Overwrite MyNotes/Todos/todos.json with the full current list
  Future<void> saveTodos(List<Todo> todos) async {
    try {
      final api = await _getDriveApi();
      await _ensureFolders(api);

      final jsonContent = jsonEncode(
        todos
            .map((t) => {
                  'id': t.id,
                  'content': t.content,
                  'isCompleted': t.isCompleted,
                  'createdAt': t.createdAt.toIso8601String(),
                  'updatedAt': t.updatedAt.toIso8601String(),
                  'reminderTime': t.reminderTime?.toIso8601String(),
                })
            .toList(),
      );

      await _uploadFile(
        api,
        name: 'todos.json',
        parentId: _todosFolderId!,
        bytes: utf8.encode(jsonContent),
        mimeType: 'application/json',
      );
    } catch (e) {
      debugPrint('DriveService.saveTodos error: $e');
      rethrow;
    }
  }
}
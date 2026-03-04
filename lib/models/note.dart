import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  String id;
  final String? serverTimestamp;
  DateTime updatedAt;
  String title;

  /// Stored as Quill Delta JSON string.
  String content;
  DateTime createdAt;

  /// Hex color string e.g. '#6366F1'. Null means use default.
  final String? color;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.serverTimestamp,
    this.color,
  });

  factory Note.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Note(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      serverTimestamp: data['serverTimestamp']?.toString(),
      color: data['color'] as String?,
    );
  }

  static DateTime _parseTimestamp(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return DateTime.now();
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'content': content,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'serverTimestamp': serverTimestamp != null
            ? FieldValue.serverTimestamp()
            : null,
        'color': color,
      };

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? serverTimestamp,
    String? color,
  }) =>
      Note(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        serverTimestamp: serverTimestamp ?? this.serverTimestamp,
        color: color ?? this.color,
      );
}
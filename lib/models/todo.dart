// models/todo.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Todo {
  String id;
  String content;
  bool isCompleted;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? reminderTime; // Nullable DateTime field for reminders

  Todo({
    required this.id,
    required this.content,
    this.isCompleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.reminderTime,
  });

  /// Factory constructor to create a Todo object from Firestore DocumentSnapshot
  factory Todo.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Todo(
      id: doc.id,
      content: data['content'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      reminderTime: data['reminderTime'] != null ? _parseTimestamp(data['reminderTime']) : null,
    );
  }

  /// Helper function to parse Firestore timestamp into DateTime
  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is DateTime) {
      return timestamp;
    } else {
      return DateTime.now(); // fallback to current time if parsing fails
    }
  }

  /// Convert Todo object into a map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt), // Store as Firestore Timestamp
      'updatedAt': Timestamp.fromDate(updatedAt), // Store as Firestore Timestamp
      'reminderTime': reminderTime != null ? Timestamp.fromDate(reminderTime!) : null, // Convert nullable DateTime
    };
  }

  /// Create a copy of the Todo object with updated values
  Todo copyWith({
    String? id,
    String? content,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? reminderTime,
  }) {
    return Todo(
      id: id ?? this.id,
      content: content ?? this.content,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
}

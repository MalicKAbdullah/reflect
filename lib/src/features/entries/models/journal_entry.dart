import 'package:flutter/foundation.dart';

/// A single journal entry. Immutable; JSON round-trips losslessly.
@immutable
final class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.body,
    required this.mood,
    required this.createdAt,
    required this.updatedAt,
    this.title = '',
    this.tags = const [],
    this.photoIds = const [],
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      body: json['body'] as String,
      mood: json['mood'] as int,
      tags: ((json['tags'] as List<dynamic>?) ?? const [])
          .map((dynamic tag) => tag as String)
          .toList(),
      // Absent on entries written before photo support (v1 documents).
      photoIds: ((json['photoIds'] as List<dynamic>?) ?? const [])
          .map((dynamic id) => id as String)
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String id;
  final String title;
  final String body;

  /// 1 (rough) … 5 (great).
  final int mood;
  final List<String> tags;

  /// Ids of encrypted photo attachments (see AttachmentService).
  final List<String> photoIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'mood': mood,
        'tags': tags,
        'photoIds': photoIds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  JournalEntry copyWith({
    String? title,
    String? body,
    int? mood,
    List<String>? tags,
    List<String>? photoIds,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      mood: mood ?? this.mood,
      tags: tags ?? this.tags,
      photoIds: photoIds ?? this.photoIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Local calendar date of creation (timezone-safe for grouping).
  DateTime get localDate =>
      DateTime(createdAt.year, createdAt.month, createdAt.day);

  @override
  bool operator ==(Object other) =>
      other is JournalEntry &&
      other.id == id &&
      other.title == title &&
      other.body == body &&
      other.mood == mood &&
      listEquals(other.tags, tags) &&
      listEquals(other.photoIds, photoIds) &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, title, body, mood, createdAt, updatedAt);
}

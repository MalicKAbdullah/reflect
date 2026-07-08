import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';

void main() {
  test('JSON round-trip preserves all fields', () {
    final entry = JournalEntry(
      id: 'id-1',
      title: 'A day — with unicode ✨',
      body: 'Multi\nline\nbody with "quotes" and emoji 🌙',
      mood: 4,
      tags: const ['grateful', 'custom-tag'],
      createdAt: DateTime(2026, 7, 3, 8, 15, 30),
      updatedAt: DateTime(2026, 7, 3, 9, 0, 0),
    );

    final decoded = JournalEntry.fromJson(
      jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
    );
    expect(decoded, entry);
  });

  test('v1 entry JSON (pre-photo live data) still parses — fixture', () {
    // Verbatim shape written by Reflect 1.0/1.1: no photoIds key at all.
    const rawV1 = '{"id":"3f6d2a1c-live","title":"Beach day",'
        '"body":"Sand **everywhere** 🌊","mood":5,'
        '"tags":["happy","energetic"],'
        '"createdAt":"2025-08-14T18:30:00.000",'
        '"updatedAt":"2025-08-14T18:31:12.000"}';

    final decoded = JournalEntry.fromJson(
      jsonDecode(rawV1) as Map<String, dynamic>,
    );
    expect(decoded.id, '3f6d2a1c-live');
    expect(decoded.title, 'Beach day');
    expect(decoded.body, 'Sand **everywhere** 🌊');
    expect(decoded.mood, 5);
    expect(decoded.tags, ['happy', 'energetic']);
    expect(decoded.photoIds, isEmpty);
    expect(decoded.createdAt, DateTime(2025, 8, 14, 18, 30));
  });

  test('photoIds round-trip through JSON', () {
    final entry = JournalEntry(
      id: 'p',
      body: 'with photos',
      mood: 3,
      photoIds: const ['ph-1', 'ph-2'],
      createdAt: DateTime(2026, 7, 3),
      updatedAt: DateTime(2026, 7, 3),
    );
    final decoded = JournalEntry.fromJson(
      jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
    );
    expect(decoded, entry);
    expect(decoded.photoIds, ['ph-1', 'ph-2']);
  });

  test('optional title and missing tags decode to defaults', () {
    final decoded = JournalEntry.fromJson(const {
      'id': 'x',
      'body': 'b',
      'mood': 3,
      'createdAt': '2026-07-03T08:00:00.000',
      'updatedAt': '2026-07-03T08:00:00.000',
    });
    expect(decoded.title, '');
    expect(decoded.tags, isEmpty);
  });

  test('copyWith keeps id and createdAt, replaces given fields', () {
    final entry = JournalEntry(
      id: 'id',
      body: 'old',
      mood: 2,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final updated = entry.copyWith(
      body: 'new',
      mood: 5,
      updatedAt: DateTime(2026, 2),
    );
    expect(updated.id, 'id');
    expect(updated.createdAt, DateTime(2026));
    expect(updated.body, 'new');
    expect(updated.mood, 5);
    expect(updated.updatedAt, DateTime(2026, 2));
  });

  test('localDate strips time of day', () {
    final entry = JournalEntry(
      id: 'id',
      body: 'b',
      mood: 3,
      createdAt: DateTime(2026, 7, 3, 23, 59, 59),
      updatedAt: DateTime(2026, 7, 3, 23, 59, 59),
    );
    expect(entry.localDate, DateTime(2026, 7, 3));
  });
}

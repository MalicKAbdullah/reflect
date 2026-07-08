import 'dart:typed_data';

import 'package:core_storage/core_storage.dart';
import 'package:reflect/src/core/clock.dart';
import 'package:reflect/src/core/interfaces/attachment_store.dart';
import 'package:reflect/src/core/interfaces/biometric_auth.dart';
import 'package:reflect/src/core/interfaces/journal_file_store.dart';
import 'package:reflect/src/core/interfaces/key_derivation.dart';
import 'package:reflect/src/core/interfaces/reminder_scheduler.dart';

/// In-memory ISecureStorage — no platform channels.
final class FakeSecureStorage implements ISecureStorage {
  final Map<String, String> store = {};

  @override
  Future<void> write({required String key, required String value}) async {
    store[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => store[key];

  @override
  Future<void> delete({required String key}) async {
    store.remove(key);
  }

  @override
  Future<void> deleteAll() async => store.clear();

  @override
  Future<Map<String, String>> readAll() async => Map.of(store);
}

/// In-memory journal file.
final class InMemoryFileStore implements IJournalFileStore {
  Uint8List? bytes;
  int writeCount = 0;

  @override
  Future<Uint8List?> read() async => bytes;

  @override
  Future<void> write(Uint8List data) async {
    bytes = Uint8List.fromList(data);
    writeCount++;
  }

  @override
  Future<void> delete() async {
    bytes = null;
  }
}

/// Fast deterministic KDF (FNV-1a over pin+salt) standing in for Argon2id.
/// Different pins or salts yield different 32-byte keys.
final class FakeKeyDerivation implements IKeyDerivation {
  @override
  Future<Uint8List> deriveKey({
    required String pin,
    required Uint8List salt,
  }) async {
    final input = [...pin.codeUnits, ...salt];
    final key = Uint8List(32);
    var hash = 0x811c9dc5;
    for (var i = 0; i < key.length; i++) {
      for (final byte in input) {
        hash ^= byte ^ i;
        hash = (hash * 0x01000193) & 0xFFFFFFFF;
      }
      key[i] = hash & 0xFF;
    }
    return key;
  }
}

/// Clock whose current time is controlled by the test.
final class FixedClock implements Clock {
  FixedClock(this.current);

  DateTime current;

  void advance(Duration duration) => current = current.add(duration);

  @override
  DateTime now() => current;
}

/// In-memory encrypted-attachment files. Counts reads so cache behaviour
/// is observable.
final class FakeAttachmentStore implements IAttachmentStore {
  final Map<String, Uint8List> files = {};
  int readCount = 0;

  @override
  Future<Uint8List?> read(String id) async {
    readCount++;
    final bytes = files[id];
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  @override
  Future<void> write(String id, Uint8List bytes) async {
    files[id] = Uint8List.fromList(bytes);
  }

  @override
  Future<void> delete(String id) async {
    files.remove(id);
  }

  @override
  Future<List<String>> list() async => files.keys.toList();

  @override
  Future<void> deleteAll() async => files.clear();
}

/// Records daily-reminder scheduling calls.
final class FakeReminderScheduler implements IReminderScheduler {
  bool initialized = false;
  bool permissionGranted = true;
  int permissionRequests = 0;
  int scheduleCount = 0;
  int cancelCount = 0;
  (int hour, int minute)? scheduled;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async {
    scheduleCount++;
    scheduled = (hour, minute);
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    scheduled = null;
  }
}

/// Scriptable biometric hardware: availability and prompt outcome are set
/// by the test. Records how many prompts were shown.
final class FakeBiometricAuth implements IBiometricAuth {
  FakeBiometricAuth({this.available = true, this.authenticates = true});

  bool available;
  bool authenticates;
  int promptCount = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    promptCount++;
    return authenticates;
  }
}

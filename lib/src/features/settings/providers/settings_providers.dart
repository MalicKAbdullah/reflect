import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/core/storage_keys.dart';

/// Auto-lock inactivity timeout. Persisted in secure storage.
final autoLockProvider = NotifierProvider<AutoLockNotifier, Duration>(
  AutoLockNotifier.new,
);

final class AutoLockNotifier extends Notifier<Duration> {
  static const Duration defaultTimeout = Duration(minutes: 2);

  static const List<Duration> options = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

  @override
  Duration build() {
    Future.microtask(_load);
    return defaultTimeout;
  }

  Future<void> _load() async {
    final raw = await ref
        .read(secureStorageProvider)
        .read(key: ReflectKeys.autoLockSeconds);
    if (raw != null) {
      final seconds = int.tryParse(raw);
      if (seconds != null && seconds > 0) {
        state = Duration(seconds: seconds);
      }
    }
  }

  Future<void> setTimeout(Duration timeout) async {
    state = timeout;
    await ref.read(secureStorageProvider).write(
          key: ReflectKeys.autoLockSeconds,
          value: timeout.inSeconds.toString(),
        );
  }

  static String labelFor(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds} seconds';
    return d.inMinutes == 1 ? '1 minute' : '${d.inMinutes} minutes';
  }
}

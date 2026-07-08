import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/core/storage_keys.dart';
import 'package:reflect/src/features/reminders/services/reminder_time.dart';

/// The daily reminder preference: on/off plus a wall-clock time.
@immutable
final class ReminderSettings {
  const ReminderSettings({
    this.enabled = false,
    this.hour = ReminderTime.defaultHour,
    this.minute = ReminderTime.defaultMinute,
  });

  final bool enabled;
  final int hour;
  final int minute;

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  String encode() =>
      jsonEncode({'enabled': enabled, 'hour': hour, 'minute': minute});

  static ReminderSettings? decode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final hour = json['hour'] as int;
      final minute = json['minute'] as int;
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return ReminderSettings(
        enabled: json['enabled'] as bool,
        hour: hour,
        minute: minute,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.enabled == enabled &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(enabled, hour, minute);
}

final dailyReminderProvider =
    NotifierProvider<DailyReminderNotifier, ReminderSettings>(
  DailyReminderNotifier.new,
);

/// Persists the daily reminder preference and keeps the OS schedule in
/// sync: rescheduled on every toggle/time change and on app start (the app
/// shell watches this provider), cancelled when disabled.
final class DailyReminderNotifier extends Notifier<ReminderSettings> {
  @override
  ReminderSettings build() {
    Future.microtask(_load);
    return const ReminderSettings();
  }

  Future<void> _load() async {
    final raw = await ref
        .read(secureStorageProvider)
        .read(key: ReflectKeys.dailyReminder);
    final loaded = ReminderSettings.decode(raw);
    if (loaded == null) return;
    state = loaded;
    // Reschedule on app start so the pending notification survives
    // reboots, timezone moves and app updates.
    if (loaded.enabled) {
      await ref
          .read(reminderSchedulerProvider)
          .scheduleDaily(hour: loaded.hour, minute: loaded.minute);
    }
  }

  /// Turns the reminder on (asking for notification permission first) or
  /// off. Returns false when enabling failed because permission was denied.
  Future<bool> setEnabled(bool enabled) async {
    final scheduler = ref.read(reminderSchedulerProvider);
    if (enabled) {
      final granted = await scheduler.requestPermission();
      if (!granted) return false;
      state = state.copyWith(enabled: true);
      await scheduler.scheduleDaily(hour: state.hour, minute: state.minute);
    } else {
      state = state.copyWith(enabled: false);
      await scheduler.cancel();
    }
    await _persist();
    return true;
  }

  /// Updates the reminder time, rescheduling if currently enabled.
  Future<void> setTime({required int hour, required int minute}) async {
    state = state.copyWith(hour: hour, minute: minute);
    if (state.enabled) {
      await ref
          .read(reminderSchedulerProvider)
          .scheduleDaily(hour: hour, minute: minute);
    }
    await _persist();
  }

  Future<void> _persist() => ref.read(secureStorageProvider).write(
        key: ReflectKeys.dailyReminder,
        value: state.encode(),
      );
}

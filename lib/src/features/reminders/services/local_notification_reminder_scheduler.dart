import 'package:core_theme/core_theme.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:reflect/src/core/interfaces/reminder_scheduler.dart';
import 'package:reflect/src/features/reminders/services/reminder_time.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// flutter_local_notifications-backed [IReminderScheduler].
///
/// Never construct this in tests — it talks to platform channels. Tests use
/// [NoopReminderScheduler] or a fake. The notification content is fixed,
/// gentle copy; it never contains journal text.
final class LocalNotificationReminderScheduler implements IReminderScheduler {
  LocalNotificationReminderScheduler({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Status-bar icon: the brand glyph, white on transparent
  /// (`res/drawable/ic_stat_notify.xml`).
  static const String _smallIcon = 'ic_stat_notify';

  static const int _notificationId = 7001;

  static const String title = 'Reflect';
  static const String body = 'A minute for yourself — how was today?';

  static final AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'daily_reminder',
    'Writing reminders',
    icon: _smallIcon,
    color: AppAccents.reflect.light,
    channelDescription: 'A daily nudge to write, at the time you choose',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    category: AndroidNotificationCategory.reminder,
  );

  static const DarwinNotificationDetails _darwinDetails =
      DarwinNotificationDetails();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fall back to the package default (UTC) if lookup fails.
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings(_smallIcon),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async {
    await _plugin.cancel(_notificationId);
    final next = ReminderTime.nextDailyFire(DateTime.now(), hour, minute);
    await _plugin.zonedSchedule(
      _notificationId,
      title,
      body,
      tz.TZDateTime.from(next, tz.local),
      NotificationDetails(
        android: _androidDetails,
        iOS: _darwinDetails,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Repeat every day at the same wall-clock time.
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel() => _plugin.cancel(_notificationId);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Static app identity constants.
abstract final class AppInfo {
  static const String name = 'Reflect';

  /// One settings-row line, so it must stay short enough not to truncate.
  static const String privacyBlurb = 'Encrypted, and stays on this device';
}

/// Installed app version from the platform (pubspec `version`), read once.
final appVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

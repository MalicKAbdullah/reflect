import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Static app identity constants.
abstract final class AppInfo {
  static const String name = 'Reflect';

  static const String privacyBlurb =
      'Your journal stays on this device, protected by your password and '
      'encryption. The only network use is the optional update check.';
}

/// Installed app version from the platform (pubspec `version`), read once.
final appVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

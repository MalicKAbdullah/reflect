/// Static app metadata (kept in code so no platform lookup is needed).
abstract final class AppInfo {
  static const String name = 'Reflect';
  static const String version = '1.7.1';

  /// One settings-row line, so it must stay short enough not to truncate.
  static const String privacyBlurb = 'Encrypted, and stays on this device';
}

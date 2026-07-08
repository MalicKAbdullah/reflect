/// Secure-storage keys used by Reflect. Namespaced to avoid clashing with
/// sibling apps that share the core packages.
abstract final class ReflectKeys {
  static const String salt = 'reflect_salt';
  static const String verifier = 'reflect_verifier';
  static const String failedAttempts = 'reflect_failed_attempts';
  static const String lockoutUntil = 'reflect_lockout_until';
  static const String autoLockSeconds = 'reflect_auto_lock_seconds';
  static const String biometricEnabled = 'reflect_biometric_enabled';
  static const String biometricKey = 'reflect_biometric_key';
  static const String writingGoal = 'reflect_writing_goal';
  static const String dailyReminder = 'reflect_daily_reminder';
  static const String onboardingSeen = 'reflect_onboarding_seen';

  static const List<String> all = [
    salt,
    verifier,
    failedAttempts,
    lockoutUntil,
    autoLockSeconds,
    biometricEnabled,
    biometricKey,
    writingGoal,
    dailyReminder,
    onboardingSeen,
  ];
}

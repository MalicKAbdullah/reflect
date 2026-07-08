/// A tiny clock abstraction so time-dependent logic (cooldowns, streaks,
/// prompts) is deterministic under test.
abstract interface class Clock {
  DateTime now();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

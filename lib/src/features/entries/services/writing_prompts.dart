/// Built-in reflective writing prompts, rotated deterministically by local
/// calendar date (same prompt all day; no Random).
abstract final class WritingPrompts {
  static const List<String> prompts = [
    'What made you pause and notice something today?',
    'Describe a moment today you would like to remember.',
    'What are you grateful for right now?',
    'What is weighing on your mind, and what is one small next step?',
    'What did you do today that your future self will thank you for?',
    'When did you feel most like yourself today?',
    'What drained your energy today? What restored it?',
    'What is something you learned — about anything — recently?',
    'Write about a conversation that stayed with you.',
    'What would make tomorrow feel like a good day?',
    'What are you avoiding, and why?',
    'Describe your current mood as weather. What is the forecast?',
    'What small kindness did you give or receive today?',
    'If today had a title, what would it be — and why?',
  ];

  /// Deterministic prompt for a given local date.
  static String forDate(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    final daysSinceEpoch = local.difference(DateTime(1970)).inDays;
    return prompts[daysSinceEpoch % prompts.length];
  }
}

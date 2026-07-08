import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/core/storage_keys.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';
import 'package:reflect/src/features/goals/models/writing_goal.dart';
import 'package:reflect/src/features/goals/services/goal_progress.dart';

/// The optional daily writing goal (null = off). Persisted in secure
/// storage alongside the other Reflect settings.
final writingGoalProvider = NotifierProvider<WritingGoalNotifier, WritingGoal?>(
  WritingGoalNotifier.new,
);

final class WritingGoalNotifier extends Notifier<WritingGoal?> {
  @override
  WritingGoal? build() {
    Future.microtask(_load);
    return null;
  }

  Future<void> _load() async {
    try {
      final raw = await ref
          .read(secureStorageProvider)
          .read(key: ReflectKeys.writingGoal);
      final goal = WritingGoal.decode(raw);
      if (goal != null) state = goal;
    } catch (_) {
      // Unreadable value — keep the goal off.
    }
  }

  Future<void> setGoal(WritingGoal? goal) async {
    state = goal;
    final storage = ref.read(secureStorageProvider);
    if (goal == null) {
      await storage.delete(key: ReflectKeys.writingGoal);
    } else {
      await storage.write(
        key: ReflectKeys.writingGoal,
        value: goal.encode(),
      );
    }
  }
}

/// Live progress against the goal, or null when no goal is set.
final goalProgressProvider = Provider<GoalProgress?>((ref) {
  final goal = ref.watch(writingGoalProvider);
  if (goal == null) return null;
  final entries = ref.watch(entriesProvider).valueOrNull ?? const [];
  return GoalProgress.compute(
    entries,
    goal,
    now: ref.read(clockProvider).now(),
  );
});

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/features/goals/models/writing_goal.dart';
import 'package:reflect/src/features/goals/providers/goal_providers.dart';

/// Preset choices for the daily writing goal.
const List<WritingGoal> _presets = [
  WritingGoal(metric: GoalMetric.entries, target: 1),
  WritingGoal(metric: GoalMetric.entries, target: 2),
  WritingGoal(metric: GoalMetric.words, target: 100),
  WritingGoal(metric: GoalMetric.words, target: 250),
  WritingGoal(metric: GoalMetric.words, target: 500),
];

/// Bottom sheet for choosing (or turning off) the daily writing goal.
Future<void> showGoalPickerSheet(BuildContext context, WidgetRef ref) async {
  final current = ref.read(writingGoalProvider);
  final choice = await showModalBottomSheet<Object>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Daily writing goal',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ListTile(
            title: const Text('No goal'),
            trailing: current == null ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(context).pop('off'),
          ),
          for (final preset in _presets)
            ListTile(
              title: Text(preset.description),
              trailing: preset == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(preset),
            ),
        ],
      ),
    ),
  );
  if (choice == null) return;
  await ref
      .read(writingGoalProvider.notifier)
      .setGoal(choice == 'off' ? null : choice as WritingGoal);
}

import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:reflect/src/features/entries/models/mood.dart';

/// Horizontal distribution of entries per mood rating.
class MoodDistributionBars extends StatelessWidget {
  const MoodDistributionBars({required this.distribution, super.key});

  /// mood (1-5) -> entry count.
  final Map<int, int> distribution;

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    final total = distribution.values.fold<int>(0, (a, b) => a + b);
    return Column(
      children: [
        for (var mood = Mood.max; mood >= Mood.min; mood--)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    Mood.emoji(mood),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                Expanded(
                  child: AppProgressBar(
                    value: total == 0 ? 0 : (distribution[mood] ?? 0) / total,
                    color: Mood.color(mood),
                    height: 10,
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${distribution[mood] ?? 0}',
                    textAlign: TextAlign.end,
                    style: AppTextStyles.numberSmall
                        .copyWith(color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

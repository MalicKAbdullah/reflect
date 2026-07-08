import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reflect/src/core/router/app_router.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/entries/models/mood.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';
import 'package:reflect/src/features/timeline/widgets/entry_card.dart';

/// Month calendar with mood-colored day dots; tapping a day lists its
/// entries below the grid.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  static final DateFormat _monthFormat = DateFormat.yMMMM();

  late DateTime _month;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  void _shiftMonth(int delta) => setState(() {
        _month = DateTime(_month.year, _month.month + delta);
        _selectedDay = null;
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = ref.watch(entriesProvider).valueOrNull ?? const [];
    final byDay = <DateTime, List<JournalEntry>>{};
    for (final entry in entries) {
      byDay.putIfAbsent(entry.localDate, () => []).add(entry);
    }
    final selectedEntries = _selectedDay == null
        ? const <JournalEntry>[]
        : byDay[_selectedDay!] ?? const <JournalEntry>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          96,
        ),
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shiftMonth(-1),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _monthFormat.format(_month),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shiftMonth(1),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _MonthGrid(
            month: _month,
            byDay: byDay,
            selectedDay: _selectedDay,
            onDayTap: (day) => setState(() => _selectedDay = day),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_selectedDay != null) ...[
            Text(
              DateFormat.yMMMMEEEEd().format(_selectedDay!),
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (selectedEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'No entries this day.',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              for (final entry in selectedEntries)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: EntryCard(
                    entry: entry,
                    onTap: () => context.push(AppRoutes.viewEntry(entry.id)),
                    onTagTap: (tag) => context.push(AppRoutes.tagTimeline(tag)),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.byDay,
    required this.selectedDay,
    required this.onDayTap,
  });

  final DateTime month;
  final Map<DateTime, List<JournalEntry>> byDay;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstDay = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstDay.weekday - DateTime.monday;
    const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        Row(
          children: [
            for (final label in weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(label, style: theme.textTheme.labelSmall),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day =
                DateTime(month.year, month.month, index - leadingBlanks + 1);
            final dayEntries = byDay[day];
            final isSelected = day == selectedDay;
            final now = DateTime.now();
            final isToday = day == DateTime(now.year, now.month, now.day);
            Color? dotColor;
            if (dayEntries != null && dayEntries.isNotEmpty) {
              final avg =
                  dayEntries.map((e) => e.mood).reduce((a, b) => a + b) /
                      dayEntries.length;
              dotColor = Mood.color(avg.round());
            }
            return InkWell(
              onTap: () => onDayTap(day),
              customBorder: const CircleBorder(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: isSelected
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                          )
                        : isToday
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 1.5,
                                ),
                              )
                            : null,
                    child: Text(
                      '${day.day}',
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                        fontWeight: isToday ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 8,
                    child: dotColor == null
                        ? null
                        : Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dotColor,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

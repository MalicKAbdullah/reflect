import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reflect/src/core/router/app_router.dart';
import 'package:reflect/src/features/entries/models/mood.dart';
import 'package:reflect/src/features/search/providers/search_providers.dart';
import 'package:reflect/src/features/search/widgets/highlighted_snippet.dart';

/// Full-text search over the decrypted journal (in-memory inverted index;
/// prefix matching, multi-term AND, ranked results).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const Duration _debounce = Duration(milliseconds: 200);

  late final TextEditingController _controller;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      if (mounted) {
        ref.read(searchQueryProvider.notifier).state = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              AppSpacing.smd,
            ),
            child: AppSearchField(
              controller: _controller,
              autofocus: true,
              hint: 'Search your journal',
              onChanged: _onQueryChanged,
            ),
          ),
          Expanded(
            child: query.trim().isEmpty
                ? const AppEmptyState(
                    icon: Icons.search,
                    title: 'Search your journal',
                    message: 'Titles, text and tags. Prefixes work too: '
                        '"med" finds "meditation".',
                  )
                : results.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.search_off,
                        title: 'No entries match',
                        message: 'Try a shorter word or a tag.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.gutter,
                          AppSpacing.xs,
                          AppSpacing.gutter,
                          AppSpacing.xl,
                        ),
                        itemCount: results.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.smd),
                        itemBuilder: (context, index) {
                          final entry = results[index].entry;
                          return VaultCard(
                            onTap: () =>
                                context.push(AppRoutes.viewEntry(entry.id)),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      Mood.emoji(entry.mood),
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: entry.title.isEmpty
                                          ? Text(
                                              'Untitled',
                                              style: AppTextStyles.h4.copyWith(
                                                color: c.textPrimary,
                                              ),
                                            )
                                          : HighlightedSnippet(
                                              text: entry.title,
                                              query: query,
                                              maxLines: 1,
                                              style: AppTextStyles.h4.copyWith(
                                                color: c.textPrimary,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      dateFormat.format(entry.createdAt),
                                      style: AppTextStyles.caption
                                          .copyWith(color: c.textTertiary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                HighlightedSnippet(
                                  text: entry.body,
                                  query: query,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

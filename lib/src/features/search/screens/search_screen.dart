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
    final theme = Theme.of(context);
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search your journal…',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _debounceTimer?.cancel();
                      _controller.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                    },
                  ),
          ),
          onChanged: _onQueryChanged,
        ),
      ),
      body: query.trim().isEmpty
          ? const VaultEmptyState(
              icon: Icons.search,
              message: 'Search titles, text and tags.\n'
                  'Prefixes work too — "med" finds "meditation".',
            )
          : results.isEmpty
              ? const VaultEmptyState(
                  icon: Icons.search_off,
                  message: 'No entries match your search.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: results.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final result = results[index];
                    final entry = result.entry;
                    return VaultCard(
                      onTap: () => context.push(AppRoutes.viewEntry(entry.id)),
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
                                        style: theme.textTheme.titleLarge,
                                      )
                                    : HighlightedSnippet(
                                        text: entry.title,
                                        query: query,
                                        maxLines: 1,
                                        style: theme.textTheme.titleLarge,
                                      ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                dateFormat.format(entry.createdAt),
                                style: theme.textTheme.labelSmall,
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
    );
  }
}

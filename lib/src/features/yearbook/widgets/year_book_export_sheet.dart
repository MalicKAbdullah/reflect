import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// The user's year-book export choices: which year, and whether to embed
/// photos.
@immutable
class YearBookExportChoice {
  const YearBookExportChoice({required this.year, required this.includePhotos});

  final int year;
  final bool includePhotos;
}

/// Bottom sheet to pick a year and toggle photo inclusion. Returns null if
/// dismissed without choosing a year.
Future<YearBookExportChoice?> showYearBookExportSheet({
  required BuildContext context,
  required List<int> years,
  required Map<int, int> counts,
}) {
  return showModalBottomSheet<YearBookExportChoice>(
    context: context,
    builder: (context) =>
        _YearBookExportSheet(years: years, counts: counts),
  );
}

class _YearBookExportSheet extends StatefulWidget {
  const _YearBookExportSheet({required this.years, required this.counts});

  final List<int> years;
  final Map<int, int> counts;

  @override
  State<_YearBookExportSheet> createState() => _YearBookExportSheetState();
}

class _YearBookExportSheetState extends State<_YearBookExportSheet> {
  bool _includePhotos = true;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Pick a year',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.image_outlined),
            title: const Text('Include photos'),
            subtitle: const Text('Up to 4 photos per entry'),
            value: _includePhotos,
            onChanged: (next) => setState(() => _includePhotos = next),
          ),
          const Divider(height: 1),
          for (final year in widget.years)
            ListTile(
              title: Text('$year'),
              subtitle: Text(
                '${widget.counts[year]} '
                '${widget.counts[year] == 1 ? 'entry' : 'entries'}',
              ),
              onTap: () => Navigator.of(context).pop(
                YearBookExportChoice(
                  year: year,
                  includePhotos: _includePhotos,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

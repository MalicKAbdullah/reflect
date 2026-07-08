import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:reflect/src/features/attachments/widgets/photo_thumbnail.dart';
import 'package:reflect/src/features/attachments/widgets/photo_viewer_screen.dart';

/// Photo gallery shown when reading an entry: rounded, evenly spaced
/// thumbnails that open the full-screen viewer.
class EntryPhotoGallery extends StatelessWidget {
  const EntryPhotoGallery({required this.photoIds, super.key});

  final List<String> photoIds;

  @override
  Widget build(BuildContext context) {
    if (photoIds.isEmpty) return const SizedBox.shrink();

    // One photo gets a generous banner; more become a tidy grid.
    if (photoIds.length == 1) {
      return PhotoThumbnail(
        photoId: photoIds.first,
        width: double.infinity,
        height: 220,
        onTap: () => PhotoViewerScreen.open(context, photoIds: photoIds),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.sm;
        final perRow = photoIds.length == 2 ? 2 : 3;
        final size = (constraints.maxWidth - spacing * (perRow - 1)) / perRow;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < photoIds.length; i++)
              PhotoThumbnail(
                photoId: photoIds[i],
                width: size,
                height: size,
                onTap: () => PhotoViewerScreen.open(
                  context,
                  photoIds: photoIds,
                  initialIndex: i,
                ),
              ),
          ],
        );
      },
    );
  }
}

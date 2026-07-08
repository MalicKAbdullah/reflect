import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/features/attachments/providers/photo_providers.dart';

/// A rounded thumbnail for one encrypted photo, decrypted on demand.
/// Shows a soft placeholder while loading and a broken-image glyph when the
/// photo cannot be read.
class PhotoThumbnail extends ConsumerWidget {
  const PhotoThumbnail({
    required this.photoId,
    this.width = 72,
    this.height = 72,
    this.onTap,
    this.onRemove,
    super.key,
  });

  final String photoId;
  final double width;
  final double height;
  final VoidCallback? onTap;

  /// When non-null, a small remove badge is shown (editor mode).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bytes = ref.watch(photoBytesProvider(photoId));

    final Widget content = switch (bytes) {
      AsyncData(value: final data) when data != null => Image.memory(
          data,
          fit: BoxFit.cover,
          width: width,
          height: height,
          gaplessPlayback: true,
        ),
      AsyncData() || AsyncError() => Container(
          width: width,
          height: height,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.broken_image_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      _ => Container(
          width: width,
          height: height,
          color: theme.colorScheme.surfaceContainerHighest,
        ),
    };

    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      child: GestureDetector(onTap: onTap, child: content),
    );

    if (onRemove == null) return thumb;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        thumb,
        Positioned(
          top: -6,
          right: -6,
          child: Material(
            color: theme.colorScheme.inverseSurface,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: theme.colorScheme.onInverseSurface,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

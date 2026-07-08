import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reflect/src/features/attachments/widgets/photo_thumbnail.dart';
import 'package:reflect/src/features/attachments/widgets/photo_viewer_screen.dart';

/// Editor photo row: thumbnails with remove badges plus an add tile that
/// offers gallery or camera.
class EditorPhotoStrip extends StatelessWidget {
  const EditorPhotoStrip({
    required this.photoIds,
    required this.onAdd,
    required this.onRemove,
    this.busy = false,
    super.key,
  });

  static const int maxPhotos = 6;
  static const double _tile = 84;

  final List<String> photoIds;
  final ValueChanged<ImageSource> onAdd;
  final ValueChanged<String> onRemove;

  /// True while a picked photo is being processed and encrypted.
  final bool busy;

  Future<void> _pickSource(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) onAdd(source);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAdd = photoIds.length < maxPhotos && !busy;

    return SizedBox(
      height: _tile + 8,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (final id in photoIds)
            Padding(
              padding: const EdgeInsets.only(
                right: AppSpacing.sm,
                top: 8,
              ),
              child: PhotoThumbnail(
                photoId: id,
                width: _tile,
                height: _tile,
                onTap: () => PhotoViewerScreen.open(
                  context,
                  photoIds: photoIds,
                  initialIndex: photoIds.indexOf(id),
                ),
                onRemove: () => onRemove(id),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: _tile,
              height: _tile,
              child: Material(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
                  onTap: canAdd ? () => _pickSource(context) : null,
                  child: busy
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Icon(
                          Icons.add_photo_alternate_outlined,
                          color: canAdd
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.outlineVariant,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

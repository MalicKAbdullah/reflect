import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/features/attachments/providers/photo_providers.dart';

/// Full-screen photo pager: swipe between an entry's photos, pinch to zoom,
/// tap or use the close button to dismiss.
class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({
    required this.photoIds,
    this.initialIndex = 0,
    super.key,
  });

  final List<String> photoIds;
  final int initialIndex;

  static Future<void> open(
    BuildContext context, {
    required List<String> photoIds,
    int initialIndex = 0,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PhotoViewerScreen(
          photoIds: photoIds,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.photoIds.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.photoIds.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: count > 1 ? Text('${_index + 1} of $count') : null,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: PageView.builder(
        controller: _controller,
        itemCount: count,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) {
          final bytes = ref.watch(photoBytesProvider(widget.photoIds[index]));
          final data = bytes.valueOrNull;
          return GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Center(
              child: data == null
                  ? (bytes.isLoading
                      ? const CircularProgressIndicator(color: Colors.white54)
                      : const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white38,
                          size: 48,
                        ))
                  : InteractiveViewer(
                      maxScale: 5,
                      child: Image.memory(data, fit: BoxFit.contain),
                    ),
            ),
          );
        },
      ),
    );
  }
}

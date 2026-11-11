import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class FullScreenImageViewer extends StatefulWidget {
  const FullScreenImageViewer({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
    required this.heroTagPrefix,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final String heroTagPrefix;

  static Route<void> route({
    required List<String> imageUrls,
    required int initialIndex,
    required String heroTagPrefix,
  }) {
    return PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => FullScreenImageViewer(
        imageUrls: imageUrls,
        initialIndex: initialIndex,
        heroTagPrefix: heroTagPrefix,
      ),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late final PageController _pageController;
  late final List<PhotoViewScaleStateController> _scaleControllers;
  late int _index;
  bool _isZoomed = false;
  double _dragProgress = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
    _scaleControllers = List.generate(
      widget.imageUrls.length,
      (_) => PhotoViewScaleStateController(),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _scaleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _zoomedAt(int index) =>
      _scaleControllers[index].scaleState != PhotoViewScaleState.initial;

  void _updateZoomState(int index) {
    final zoomed = _zoomedAt(index);
    if (zoomed != _isZoomed) {
      setState(() => _isZoomed = zoomed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.black.withValues(
                  alpha: (1 - _dragProgress).clamp(0.0, 1.0),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Dismissible(
              key: const ValueKey('full_screen_image_viewer'),
              direction:
                  _isZoomed ? DismissDirection.none : DismissDirection.down,
              resizeDuration: null,
              movementDuration: const Duration(milliseconds: 200),
              onUpdate: (details) {
                if (details.progress != _dragProgress) {
                  setState(() => _dragProgress = details.progress);
                }
              },
              onDismissed: (_) {
                if (mounted) Navigator.of(context).pop();
              },
              child: PhotoViewGallery.builder(
                itemCount: widget.imageUrls.length,
                pageController: _pageController,
                backgroundDecoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                onPageChanged: (index) {
                  setState(() {
                    _index = index;
                    _isZoomed = _zoomedAt(index);
                  });
                },
                scaleStateChangedCallback: (state) {
                  final zoomed = state != PhotoViewScaleState.initial;
                  if (zoomed != _isZoomed) {
                    setState(() => _isZoomed = zoomed);
                  }
                },
                loadingBuilder: (context, progress) {
                  final expected = progress?.expectedTotalBytes;
                  final loaded = progress?.cumulativeBytesLoaded;
                  final value = expected != null && expected > 0 && loaded != null
                      ? loaded / expected
                      : null;
                  return Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
                builder: (context, index) {
                  return PhotoViewGalleryPageOptions(
                    imageProvider:
                        CachedNetworkImageProvider(widget.imageUrls[index]),
                    initialScale: PhotoViewComputedScale.contained,
                    minScale: PhotoViewComputedScale.contained * 0.8,
                    maxScale: PhotoViewComputedScale.covered * 3,
                    heroAttributes: PhotoViewHeroAttributes(
                      tag: '${widget.heroTagPrefix}_$index',
                    ),
                    scaleStateController: _scaleControllers[index],
                    onScaleEnd: (_, _, _) => _updateZoomState(index),
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 64,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Material(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${_index + 1} / ${widget.imageUrls.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

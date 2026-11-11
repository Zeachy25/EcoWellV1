import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';

class PostImageCollage extends StatelessWidget {
  const PostImageCollage({
    super.key,
    required this.imageUrls,
    required this.postId,
    required this.onImageTap,
  });

  final List<String> imageUrls;
  final String postId;
  final ValueChanged<int> onImageTap;

  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    final count = imageUrls.length;
    final Widget content;

    if (count == 1) {
      content = _singleImage();
    } else if (count == 2) {
      content = AspectRatio(
        aspectRatio: 2,
        child: Row(
          children: [
            Expanded(child: _tile(context, 0)),
            const SizedBox(width: _gap),
            Expanded(child: _tile(context, 1)),
          ],
        ),
      );
    } else if (count == 3) {
      content = AspectRatio(
        aspectRatio: 1.5,
        child: Row(
          children: [
            Expanded(flex: 2, child: _tile(context, 0)),
            const SizedBox(width: _gap),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Expanded(child: _tile(context, 1)),
                  const SizedBox(height: _gap),
                  Expanded(child: _tile(context, 2)),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      content = AspectRatio(
        aspectRatio: 1,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _tile(context, 0)),
                  const SizedBox(width: _gap),
                  Expanded(child: _tile(context, 1)),
                ],
              ),
            ),
            const SizedBox(height: _gap),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _tile(context, 2)),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: _tile(context, 3, overlayCount: count - 4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(Responsive.radius(context, 12)),
      child: content,
    );
  }

  Widget _singleImage() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 200, maxHeight: 400),
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onImageTap(0),
          child: Hero(
            tag: '${postId}_0',
            child: CachedNetworkImage(
              imageUrl: imageUrls.first,
              fit: BoxFit.cover,
              placeholder: (_, _) => const _ImagePlaceholder(),
              errorWidget: (_, _, _) => const _ImageError(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, int index, {int overlayCount = 0}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onImageTap(index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: '${postId}_$index',
            child: CachedNetworkImage(
              imageUrl: imageUrls[index],
              fit: BoxFit.cover,
              placeholder: (_, _) => const _ImagePlaceholder(),
              errorWidget: (_, _, _) => const _ImageError(),
            ),
          ),
          if (overlayCount > 0)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.55),
              child: Center(
                child: Text(
                  '+$overlayCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Responsive.fontSize(context, 22),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardBorder,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardBorder,
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 32,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

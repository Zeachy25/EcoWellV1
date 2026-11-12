import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../map/domain/green_space.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import 'share_preview.dart';
import 'share_text.dart';

Future<void> openShareForPost(
  BuildContext context, {
  required FeedPost post,
  required CommunityRepository repo,
  required VoidCallback onShared,
}) async {
  if (post.isShareUnavailable) {
    _showUnavailable(context);
    return;
  }

  final sharedPlace = post.sharedPlace;
  if (sharedPlace != null) {
    await showPlaceShareSheet(
      context,
      place: sharedPlace,
      onShareToFeed: (caption) async {
        await repo.sharePlaceToFeed(placeId: sharedPlace.id, caption: caption);
        onShared();
      },
    );
    return;
  }

  final target = post.sharedPost ?? post;
  if (target.isShareUnavailable) {
    _showUnavailable(context);
    return;
  }

  await showPostShareSheet(
    context,
    post: target,
    onShareToFeed: (caption) async {
      await repo.sharePostToFeed(postId: target.id, caption: caption);
      onShared();
    },
  );
}

Future<void> showPostShareSheet(
  BuildContext context, {
  required FeedPost post,
  required Future<void> Function(String caption) onShareToFeed,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _PostShareSheet(post: post, onShareToFeed: onShareToFeed),
  );
}

Future<void> showPlaceShareSheet(
  BuildContext context, {
  required GreenSpace place,
  required Future<void> Function(String caption) onShareToFeed,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        _PlaceShareSheet(place: place, onShareToFeed: onShareToFeed),
  );
}

void _showUnavailable(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('This share is no longer available.')),
  );
}

class _PostShareSheet extends StatelessWidget {
  const _PostShareSheet({required this.post, required this.onShareToFeed});

  final FeedPost post;
  final Future<void> Function(String caption) onShareToFeed;

  @override
  Widget build(BuildContext context) {
    return _ShareSheet(
      title: 'Share post',
      preview: PostSharePreview(post: post, heroPrefix: 'share_${post.id}'),
      shareText: buildPostShareText(post),
      subject: '${post.author.name} on EcoWell',
      onShareToFeed: onShareToFeed,
    );
  }
}

class _PlaceShareSheet extends StatelessWidget {
  const _PlaceShareSheet({required this.place, required this.onShareToFeed});

  final GreenSpace place;
  final Future<void> Function(String caption) onShareToFeed;

  @override
  Widget build(BuildContext context) {
    return _ShareSheet(
      title: 'Share place',
      preview: PlaceSharePreview(place: place),
      shareText: buildPlaceShareText(place),
      subject: '${place.name} on EcoWell',
      onShareToFeed: onShareToFeed,
    );
  }
}

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({
    required this.title,
    required this.preview,
    required this.shareText,
    required this.subject,
    required this.onShareToFeed,
  });

  final String title;
  final Widget preview;
  final String shareText;
  final String subject;
  final Future<void> Function(String caption) onShareToFeed;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  final _caption = TextEditingController();
  bool _posting = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _shareToFeed() async {
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await widget.onShareToFeed(_caption.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Share to feed failed: $e');
      if (mounted) {
        setState(() {
          _error = 'Could not share to your feed. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _shareExternal() async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: widget.shareText,
          subject: widget.subject,
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      debugPrint('External share failed: $e');
      if (mounted) {
        setState(() => _error = 'Could not open the share sheet.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(isOnlineProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: Responsive.fontSize(context, 20),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            widget.preview,
            const SizedBox(height: 14),
            TextField(
              controller: _caption,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Say something (optional)',
                counterText: '',
                filled: true,
                fillColor: AppColors.inputFill,
                border: _inputBorder(context),
                enabledBorder: _inputBorder(context),
                focusedBorder: _inputBorder(
                  context,
                  color: AppColors.primaryGreen,
                  width: 1.5,
                ),
              ),
            ),
            if (!online) ...[
              const SizedBox(height: 8),
              Text(
                'You are offline. Sharing to your feed needs a connection.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: Responsive.fontSize(context, 12),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: AppColors.scoreLow,
                  fontSize: Responsive.fontSize(context, 12),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: online && !_posting ? _shareToFeed : null,
                    icon: _posting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.repeat),
                    label: Text(_posting ? 'Sharing...' : 'Share to feed'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _posting ? null : _shareExternal,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share via...'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _posting ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  OutlineInputBorder _inputBorder(
    BuildContext context, {
    Color color = AppColors.inputBorder,
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(Responsive.radius(context, 12)),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

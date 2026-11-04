import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../map/domain/green_space.dart';
import 'community_post_details.dart';

class CommunityPostDraft {
  const CommunityPostDraft({
    required this.place,
    required this.caption,
    required this.photos,
    this.visitId,
    this.visitMinutes,
    this.stressReduction,
  });

  final GreenSpace place;
  final String caption;
  final List<XFile> photos;
  final String? visitId;
  final int? visitMinutes;
  final int? stressReduction;
}

/// Shared photo, place, caption, and optional visit editor for community posts.
class CommunityPostComposer extends ConsumerStatefulWidget {
  const CommunityPostComposer({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.maxPhotos,
    required this.privacyText,
    required this.onSubmit,
  });

  final String title;
  final String submitLabel;
  final int maxPhotos;
  final String privacyText;
  final Future<void> Function(CommunityPostDraft draft) onSubmit;

  @override
  ConsumerState<CommunityPostComposer> createState() =>
      _CommunityPostComposerState();
}

class _CommunityPostComposerState
    extends ConsumerState<CommunityPostComposer> {
  final _picker = ImagePicker();
  final _caption = TextEditingController();
  final List<XFile> _photos = [];

  CommunityPostDetailsValue? _details;
  bool _posting = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickFromGallery() async {
    final room = widget.maxPhotos - _photos.length;
    if (room <= 0) return;
    try {
      final picked = await _picker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (picked.isEmpty || !mounted) return;
      setState(() => _photos.addAll(picked.take(room)));
    } catch (e) {
      debugPrint('Gallery error: $e');
      _message('Could not open your photos.');
    }
  }

  Future<void> _takePhoto() async {
    if (_photos.length >= widget.maxPhotos) return;
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (shot == null || !mounted) return;
      setState(() => _photos.add(shot));
    } catch (e) {
      debugPrint('Camera error: $e');
      _message('Could not open the camera.');
    }
  }

  Future<void> _submit() async {
    final details = _details;
    if (_photos.isEmpty) {
      _message('Add at least one photo.');
      return;
    }
    if (details == null) {
      _message('Choose a place.');
      return;
    }

    setState(() => _posting = true);
    try {
      await widget.onSubmit(
        CommunityPostDraft(
          place: details.place,
          caption: _caption.text,
          photos: List.unmodifiable(_photos),
          visitId: details.visitId,
          visitMinutes: details.visitMinutes,
          stressReduction: details.stressReduction,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Create community content error: $e');
      _message('Could not share. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canAddMore = _photos.length < widget.maxPhotos;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _posting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                backgroundColor: AppColors.streakOrange,
              ),
              child: _posting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(widget.submitLabel),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.maxPhotos == 1
                ? 'Photo'
                : 'Photos (${_photos.length}/${widget.maxPhotos})',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 104,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < _photos.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_photos[i].path),
                            width: 104,
                            height: 104,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: _posting
                                ? null
                                : () => setState(() => _photos.removeAt(i)),
                            child: const CircleAvatar(
                              radius: 11,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (canAddMore) ...[
                  _AddTile(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: _posting ? null : _pickFromGallery,
                  ),
                  const SizedBox(width: 8),
                  _AddTile(
                    icon: Icons.photo_camera_outlined,
                    label: 'Camera',
                    onTap: _posting ? null : _takePhoto,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          CommunityPostDetails(
            onChanged: (details) => setState(() => _details = details),
          ),
          const SizedBox(height: 20),
          Text(
            'Caption',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _caption,
            maxLength: 500,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'How did this place make you feel?',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.privacyText,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.forestMid, size: 30),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

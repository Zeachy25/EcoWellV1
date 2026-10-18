import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../home/data/home_providers.dart';
import '../../map/data/map_providers.dart';
import '../../map/domain/green_space.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';

/// Share a moment: photos (up to 4), a place, a caption, and optionally your
/// latest visit stats. Pops with `true` when the post was created.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key, this.myDay = false});

  /// true: posts a My Day (24 hours, followers only, never in the feed).
  final bool myDay;

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  int get _maxPhotos => widget.myDay ? 1 : 4;

  final _picker = ImagePicker();
  final _caption = TextEditingController();
  final List<XFile> _photos = [];

  GreenSpace? _place;
  VisitStats? _visit;
  bool _includeVisit = false;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _chooseDefaultPlace();
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Starts with the nearest place (or the first one).
  Future<void> _chooseDefaultPlace() async {
    try {
      final spaces = await ref.read(greenSpacesProvider.future);
      if (spaces.isEmpty || !mounted) return;
      final Position? pos = await ref.read(homePositionProvider.future);
      var best = spaces.first;
      if (pos != null) {
        double d(GreenSpace s) => Geolocator.distanceBetween(
            pos.latitude, pos.longitude, s.lat, s.lng);
        best = spaces.reduce((a, b) => d(a) <= d(b) ? a : b);
      }
      await _selectPlace(best);
    } catch (e) {
      debugPrint('Default place error: $e');
    }
  }

  Future<void> _selectPlace(GreenSpace place) async {
    setState(() {
      _place = place;
      _visit = null;
      _includeVisit = false;
    });
    try {
      final v = await ref.read(communityRepositoryProvider).latestVisitAt(place.id);
      if (!mounted || _place?.id != place.id) return;
      setState(() {
        _visit = v;
        _includeVisit = v != null;
      });
    } catch (_) {
      // Posting still works without visit stats.
    }
  }

  Future<void> _pickPlace() async {
    final spaces = await ref.read(greenSpacesProvider.future);
    if (!mounted) return;
    final chosen = await showModalBottomSheet<GreenSpace>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final s in spaces)
                ListTile(
                  leading: const Icon(Icons.eco, color: AppColors.mintGreen),
                  title: Text(s.name),
                  subtitle: Text(s.categoryLabel),
                  selected: s.id == _place?.id,
                  onTap: () => Navigator.pop(ctx, s),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) await _selectPlace(chosen);
  }

  Future<void> _pickFromGallery() async {
    final room = _maxPhotos - _photos.length;
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
    if (_photos.length >= _maxPhotos) return;
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

  Future<void> _post() async {
    final place = _place;
    if (_photos.isEmpty) {
      _message('Add at least one photo.');
      return;
    }
    if (place == null) {
      _message('Choose a place.');
      return;
    }
    setState(() => _posting = true);
    try {
      final repo = ref.read(communityRepositoryProvider);
      if (widget.myDay) {
        await repo.createMyDay(
          placeId: place.id,
          placeName: place.name,
          caption: _caption.text,
          photo: _photos.first,
          visitMinutes: _includeVisit ? _visit?.minutes : null,
          stressReduction: _includeVisit ? _visit?.reduction : null,
        );
      } else {
        await repo.createPost(
          placeId: place.id,
          caption: _caption.text,
          photos: _photos,
          visitId: _includeVisit ? _visit?.visitId : null,
        );
      }
      if (mounted) {
        if (widget.myDay) {
          Navigator.of(context).pop(true);
        } else {
          context.pop(true);
        }
      }
    } catch (e) {
      debugPrint('Create post error: $e');
      _message('Could not post. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canAddMore = _photos.length < _maxPhotos;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.myDay ? 'Add to My Day' : 'Share a moment'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _posting ? null : _post,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                backgroundColor: AppColors.streakOrange,
              ),
              child: _posting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(widget.myDay ? 'Share' : 'Post'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.myDay ? 'Photo' : 'Photos (${_photos.length}/$_maxPhotos)',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
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
                              child: Icon(Icons.close,
                                  size: 14, color: Colors.white),
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
                      onTap: _posting ? null : _pickFromGallery),
                  const SizedBox(width: 8),
                  _AddTile(
                      icon: Icons.photo_camera_outlined,
                      label: 'Camera',
                      onTap: _posting ? null : _takePhoto),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Place',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _posting ? null : _pickPlace,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.mintGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _place?.name ?? 'Choose a place',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.expand_more),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Caption',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
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
          if (_visit != null) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeVisit,
              onChanged:
                  _posting ? null : (v) => setState(() => _includeVisit = v),
              title: const Text('Include my visit'),
              subtitle: Text(
                '${formatDuration(_visit!.minutes * 60.0)} \u00b7 '
                '${_visit!.reduction > 0 ? 'stress score down ${_visit!.reduction}' : _visit!.reduction < 0 ? 'stress score up ${-_visit!.reduction}' : 'stress score unchanged'}',
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            widget.myDay
                ? 'Your My Day is visible to the people who follow you for 24 '
                    'hours, then it disappears. It does not appear in the '
                    'Explore feed. Please do not share photos of people '
                    'without their permission.'
                : 'Your name, profile picture, photos, and caption will be '
                    'visible to other EcoWell users. Please do not post photos '
                    'of people without their permission.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.icon, required this.label, required this.onTap});

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
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/community_repository.dart';
import 'community_post_details.dart';
import 'my_day_media_picker_screen.dart';

/// Creates a photo story that is visible to followers for 24 hours.
class CreateMyDayScreen extends ConsumerStatefulWidget {
  const CreateMyDayScreen({super.key});

  @override
  ConsumerState<CreateMyDayScreen> createState() => _CreateMyDayScreenState();
}

class _CreateMyDayScreenState extends ConsumerState<CreateMyDayScreen> {
  final _caption = TextEditingController();
  final _captionFocus = FocusNode();
  MyDaySelectedPhoto? _photo;
  CommunityPostDetailsValue? _details;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _choosePhoto());
  }

  @override
  void dispose() {
    _caption.dispose();
    _captionFocus.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final photo = await Navigator.of(context).push<MyDaySelectedPhoto>(
      MaterialPageRoute<MyDaySelectedPhoto>(
        fullscreenDialog: true,
        builder: (_) => const MyDayMediaPickerScreen(),
      ),
    );
    if (mounted && photo != null) setState(() => _photo = photo);
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (mounted && photo != null) {
        setState(() => _photo = MyDaySelectedPhoto(file: photo));
      }
    } catch (error) {
      debugPrint('My Day camera error: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the camera.')),
      );
    }
  }

  Future<void> _share() async {
    final photo = _photo;
    final details = _details;
    if (photo == null) {
      _showMessage('Choose a photo for your story.');
      return;
    }
    if (details == null) {
      _showMessage('Choose a location for your story.');
      return;
    }

    setState(() => _sharing = true);
    try {
      await ref.read(communityRepositoryProvider).createMyDay(
        placeId: details.place.id,
        placeName: details.place.name,
        caption: _caption.text,
        photo: photo.file,
        visitMinutes: details.visitMinutes,
        stressReduction: details.stressReduction,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Create My Day error: $error');
      _showMessage('Could not share. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    return Scaffold(
      backgroundColor: const Color(0xFF08101E),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _sharing ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Create Story',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Choose another photo',
                    onPressed: _sharing ? null : _choosePhoto,
                    icon: const Icon(
                      Icons.photo_library_outlined,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Take a photo',
                    onPressed: _sharing ? null : _takePhoto,
                    icon: const Icon(
                      Icons.photo_camera_outlined,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (photo == null)
                        const ColoredBox(
                          color: Color(0xFF18263B),
                          child: Center(
                            child: Icon(
                              Icons.photo_outlined,
                              color: Colors.white38,
                              size: 62,
                            ),
                          ),
                        )
                      else if (photo.previewBytes != null)
                        Image.memory(
                          photo.previewBytes!,
                          fit: BoxFit.cover,
                        )
                      else
                        Image.file(
                          File(photo.file.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFF18263B),
                            child: Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white54,
                                size: 56,
                              ),
                            ),
                          ),
                        ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x44000000),
                              Colors.transparent,
                              Color(0x88000000),
                            ],
                            stops: [0, 0.55, 1],
                          ),
                        ),
                      ),
                      if (photo != null)
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 16,
                          child: TextField(
                            controller: _caption,
                            focusNode: _captionFocus,
                            maxLength: 500,
                            minLines: 1,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Add a caption…',
                              hintStyle: const TextStyle(color: Colors.white70),
                              counterText: '',
                              filled: true,
                              fillColor: Colors.black.withValues(alpha: 0.48),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      if (photo == null)
                        Center(
                          child: FilledButton.icon(
                            onPressed: _sharing ? null : _choosePhoto,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Choose a photo'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: const BoxDecoration(color: Color(0xFF0D1728)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CommunityPostDetails(
                    compact: true,
                    onChanged: (details) => setState(() => _details = details),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18263B),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.people_alt_outlined,
                          color: Color(0xFF74C9EF),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SHARING DESTINATION',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 9,
                                  letterSpacing: 0.6,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Your Story · Followers only',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.lock_outline,
                          color: Colors.white60,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sharing || photo == null ? null : _share,
                      icon: _sharing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF08101E),
                              ),
                            )
                          : const Icon(Icons.send_outlined, size: 18),
                      label: Text(_sharing ? 'Sharing…' : 'Share to Story'),
                      style: FilledButton.styleFrom(
                        foregroundColor: const Color(0xFF071422),
                        backgroundColor: const Color(0xFF2CB8EB),
                        minimumSize: const Size.fromHeight(48),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

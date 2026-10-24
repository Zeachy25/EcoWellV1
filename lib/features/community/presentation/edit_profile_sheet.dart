import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../home/data/profile_providers.dart';
import '../data/user_profile_repository.dart';
import '../domain/user_profile.dart';
import 'user_avatar.dart';

/// Opens the "Edit profile" sheet for the signed-in user: cover photo,
/// profile picture, name and bio. Returns true when something was saved.
Future<bool?> showEditProfileSheet(
  BuildContext context, {
  required UserProfile profile,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _EditProfileSheet(profile: profile),
  );
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _name;
  late final TextEditingController _bio;
  XFile? _avatarPick;
  XFile? _coverPick;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
    _bio = TextEditingController(text: widget.profile.bio ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Small chooser, then the platform picker (same options as posts).
  Future<void> _pickImage({required bool isCover}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1400,
        imageQuality: 80,
      );
      if (picked == null) return;
      setState(() {
        if (isCover) {
          _coverPick = picked;
        } else {
          _avatarPick = picked;
        }
      });
    } catch (e) {
      debugPrint('Image pick error: $e');
      _message('Could not open the camera or gallery.');
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final bio = _bio.text.trim();
    try {
      await ref.read(userProfileRepositoryProvider).saveProfile(
            name: name,
            bio: bio.isEmpty ? null : bio,
            avatar: _avatarPick,
            cover: _coverPick,
            oldAvatarUrl: widget.profile.avatarUrl,
            oldCoverUrl: widget.profile.coverUrl,
          );
      // Home header/greeting and the profile screen reload fresh data.
      ref.invalidate(profileProvider);
      ref.invalidate(userProfileProvider(widget.profile.id));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Save profile error: $e');
      _message('Could not save your profile. Check your connection and try '
          'again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nameOk = _name.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Responsive.horizontalPadding(context),
          0,
          Responsive.horizontalPadding(context),
          Responsive.size(context, 24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit profile',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.fontSize(context, 18),
                  ),
                ),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            SizedBox(height: Responsive.size(context, 12)),

            // ── Cover + avatar preview. The Stack is 34 px taller than the
            // cover so the avatar (and its buttons) sit fully inside the
            // hit-test area — Flutter ignores taps outside a parent's bounds.
            SizedBox(
              height: Responsive.size(context, 130) + 34,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                          Responsive.radius(context, 14)),
                      child: Container(
                        height: Responsive.size(context, 130),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1B4D36), Color(0xFF38B289)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: _coverPick != null
                            ? Image.file(File(_coverPick!.path),
                                fit: BoxFit.cover)
                            : (widget.profile.coverUrl?.isNotEmpty ?? false)
                                ? CachedNetworkImage(
                                    imageUrl: widget.profile.coverUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  )
                                : null,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 44, // 10 px above the cover's bottom edge
                    child: _CameraButton(
                        onTap: () => _pickImage(isCover: true)),
                  ),
                  Positioned(
                    left: 14,
                    bottom: 0,
                    // Facebook-style: tapping the avatar opens the chooser.
                    child: GestureDetector(
                      onTap: () => _pickImage(isCover: false),
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: _avatarPick != null
                                ? ClipOval(
                                    child: Image.file(
                                      File(_avatarPick!.path),
                                      width: 76,
                                      height: 76,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : UserAvatar(
                                    name: widget.profile.name,
                                    url: widget.profile.avatarUrl,
                                    radius: 38,
                                  ),
                          ),
                          const Positioned(
                            right: 0,
                            bottom: 0,
                            child: _CameraBadge(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: Responsive.size(context, 42)),

            // ── Name ──
            TextField(
              controller: _name,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                counterText: '',
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: Responsive.size(context, 14)),

            // ── Bio ──
            TextField(
              controller: _bio,
              maxLength: 150,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell people about yourself...',
                counterText: '',
                isDense: true,
              ),
            ),
            SizedBox(height: Responsive.size(context, 18)),

            // ── Save ──
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: _saving || !nameOk ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(Icons.camera_alt_outlined,
              size: 18, color: AppColors.forestMid),
        ),
      ),
    );
  }
}

/// Decorative corner badge on the avatar; the avatar itself handles the tap.
class _CameraBadge extends StatelessWidget {
  const _CameraBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Icon(Icons.camera_alt_outlined,
          size: 14, color: AppColors.forestMid),
    );
  }
}

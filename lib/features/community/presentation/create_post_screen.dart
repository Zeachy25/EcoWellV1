import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_repository.dart';
import 'community_post_composer.dart';

/// Creates a regular Explore feed post.
class CreatePostScreen extends ConsumerWidget {
  const CreatePostScreen({super.key});
   
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CommunityPostComposer(
      title: 'Share a moment',
      submitLabel: 'Post',
      maxPhotos: 4,
      privacyText:
          'Your name, profile picture, photos, and caption will be visible to '
          'other EcoWell users. Please do not post photos of people without '
          'their permission.',
      onSubmit: (draft) => ref.read(communityRepositoryProvider).createPost(
        placeId: draft.place.id,
        caption: draft.caption,
        photos: draft.photos,
        visitId: draft.visitId,
      ),
    );
  }
}

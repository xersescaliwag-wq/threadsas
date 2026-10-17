// lib/providers/community_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/models/community.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/providers/core_providers.dart';

/// Every community the signed-in user can see, for the list screen.
final communitiesProvider = FutureProvider<List<Community>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(communityRepositoryProvider).fetchAll();
});

/// The communities the signed-in user belongs to, for the composer's picker.
final myCommunitiesProvider = FutureProvider<List<Community>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(communityRepositoryProvider).fetchMine();
});

/// One community, watched by its own screen so a join or leave redraws the
/// header.
final communityProvider = FutureProvider.family<Community, String>((ref, id) {
  return ref.watch(communityRepositoryProvider).fetchById(id);
});

/// The posts in one community's feed. The database returns only the posts the
/// signed-in user may see, so a non-member gets an empty list.
final communityFeedProvider = FutureProvider.family<List<ThreadPost>, String>(
  (ref, id) {
    return ref.watch(threadRepositoryProvider).fetchCommunity(id);
  },
);

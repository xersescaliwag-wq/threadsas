// lib/providers/post_state_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/providers/core_providers.dart';

/// The newest state of every post the signed-in user has just changed: a like,
/// a repost, a reply or a poll vote.
///
/// Every list fetches its own copy of a post, so a reaction made on one screen
/// looked wrong on a screen that had fetched its list earlier: an empty heart
/// on the profile for a post the feed had already liked, and a second like the
/// server then refused as a duplicate. [ThreadCard] reads this map, so one
/// change is shown in every list at once without refetching anything.
class PostStateStore extends Notifier<Map<String, ThreadPost>> {
  @override
  Map<String, ThreadPost> build() {
    // The map holds one person's reactions, so another account starts clean.
    ref.watch(currentUserIdProvider);
    return {};
  }

  void apply(ThreadPost post) => state = {...state, post.id: post};

  /// Empties the map. A pull-to-refresh is the moment the lists read the truth
  /// from the server again, so anything held here is out of date.
  void clear() => state = {};
}

final postStateProvider =
    NotifierProvider<PostStateStore, Map<String, ThreadPost>>(PostStateStore.new);

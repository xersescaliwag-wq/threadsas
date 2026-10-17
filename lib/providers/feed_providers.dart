// lib/providers/feed_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/providers/post_state_provider.dart';
import 'package:threads/providers/social_providers.dart';
abstract class _FeedNotifier extends AsyncNotifier<List<ThreadPost>> {
  static const pageSize = 20;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool get hasMore => _hasMore;
  /// Each feed decides which posts to fetch. before is the cursor for the next page.
  Future<List<ThreadPost>> fetchPage({DateTime? before});
  @override
  Future<List<ThreadPost>> build() async {
    ref.watch(currentUserIdProvider); // reload after sign-in or sign-out
    final page = await fetchPage();
    _hasMore = page.length >= pageSize;
    return page;
  }
  /// Pull to refresh.
  Future<void> refresh() async {
    // The rows coming back are the server's truth, so any shared copy of a post
    // is out of date and would shadow them.
    ref.read(postStateProvider.notifier).clear();
    state = await AsyncValue.guard(() async {
      final page = await fetchPage();
      _hasMore = page.length >= pageSize;
      return page;
    });
  }
  /// Infinite scroll. Adds the next page after the oldest post on screen.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isEmpty || !_hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final page = await fetchPage(before: current.last.createdAt);
      _hasMore = page.length >= pageSize;
      final known = current.map((post) => post.id).toSet();
      state = AsyncData([
        ...current,
        ...page.where((post) => !known.contains(post.id)),
      ]);
    } catch (_) {
      // Keep the posts already on screen. The list footer offers a retry.
    } finally {
      _loadingMore = false;
    }
  }
  /// Swaps in one updated post, for example after a like, without a reload.
  void replacePost(ThreadPost updated) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final post in current) post.id == updated.id ? updated : post,
    ]);
  }
  /// Removes a post after it is deleted.
  void removePost(String threadId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.where((post) => post.id != threadId).toList());
  }
}
class ForYouFeed extends _FeedNotifier {
  @override
  Future<List<ThreadPost>> fetchPage({DateTime? before}) async {
    final page = await ref.read(threadRepositoryProvider).fetchForYou(before: before);
    final muted = await ref.read(mutedIdsProvider.future);
    return page.where((post) => !muted.contains(post.author.id)).toList();
  }
}
class FollowingFeed extends _FeedNotifier {
  @override
  Future<List<ThreadPost>> fetchPage({DateTime? before}) async {
    final page = await ref.read(threadRepositoryProvider).fetchFollowing(before: before);
    final muted = await ref.read(mutedIdsProvider.future);
    return page.where((post) => !muted.contains(post.author.id)).toList();
  }
}
final forYouFeedProvider =
    AsyncNotifierProvider<ForYouFeed, List<ThreadPost>>(ForYouFeed.new);
final followingFeedProvider =
    AsyncNotifierProvider<FollowingFeed, List<ThreadPost>>(FollowingFeed.new);

/// Which home feed is on screen: 0 = For you, 1 = Following. Home reads it, and
/// the feeds drawer (owned by the shell's scaffold) writes it.
class SelectedFeed extends Notifier<int> {
  @override
  int build() => 0;

  void select(int value) {
    if (state != value) state = value;
  }
}

final selectedFeedProvider = NotifierProvider<SelectedFeed, int>(
  SelectedFeed.new,
);

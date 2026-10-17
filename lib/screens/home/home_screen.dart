import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/providers/feed_providers.dart';
import 'package:threads/widgets/thread_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _feed = 0; // 0 = For you, 1 = Following
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadMoreNearEnd);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _loadMoreNearEnd() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 600) {
      if (_feed == 0) {
        ref.read(forYouFeedProvider.notifier).loadMore();
      } else {
        ref.read(followingFeedProvider.notifier).loadMore();
      }
    }
  }

  Future<void> _refresh() {
    return _feed == 0
        ? ref.read(forYouFeedProvider.notifier).refresh()
        : ref.read(followingFeedProvider.notifier).refresh();
  }

  bool get _hasMore {
    return _feed == 0
        ? ref.read(forYouFeedProvider.notifier).hasMore
        : ref.read(followingFeedProvider.notifier).hasMore;
  }

  void _replace(ThreadPost post) {
    if (_feed == 0) {
      ref.read(forYouFeedProvider.notifier).replacePost(post);
    } else {
      ref.read(followingFeedProvider.notifier).replacePost(post);
    }
  }

  void _remove(String threadId) {
    if (_feed == 0) {
      ref.read(forYouFeedProvider.notifier).removePost(threadId);
    } else {
      ref.read(followingFeedProvider.notifier).removePost(threadId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = _feed == 0
        ? ref.watch(forYouFeedProvider)
        : ref.watch(followingFeedProvider);
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _refresh),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _feed,
              children: const {0: Text('For you'), 1: Text('Following')},
              onValueChanged: (value) {
                if (value != null) setState(() => _feed = value);
              },
            ),
          ),
        ),
        ...feed.when<List<Widget>>(
          loading: () => [
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CupertinoActivityIndicator()),
            ),
          ],
          error: (error, _) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _RetryView(message: friendlyError(error), onRetry: _refresh),
            ),
          ],
          data: _postSlivers,
        ),
      ],
    );
  }

  List<Widget> _postSlivers(List<ThreadPost> posts) {
    if (posts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                _feed == 0 ? 'No threads yet.' : 'Follow people to fill this feed.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: CupertinoColors.secondaryLabel),
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == posts.length) {
              return _hasMore
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CupertinoActivityIndicator()),
                    )
                  : const SizedBox(height: 40);
            }
            final post = posts[index];
            return Column(
              children: [
                ThreadCard(
                  key: ValueKey(post.id),
                  post: post,
                  onChanged: _replace,
                  onDeleted: () => _remove(post.id),
                ),
                Container(
                  height: 0.5,
                  margin: const EdgeInsets.only(left: 68),
                  color: CupertinoColors.separator,
                ),
              ],
            );
          },
          childCount: posts.length + 1,
        ),
      ),
    ];
  }
}

class _RetryView extends StatelessWidget {
  const _RetryView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            CupertinoButton.filled(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/providers/feed_providers.dart';
import 'package:threads/screens/compose/compose_screen.dart';
import 'package:threads/screens/search/search_screen.dart';
import 'package:threads/widgets/avatar.dart';
import 'package:threads/widgets/thread_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();

  /// Which feed is on screen: 0 = For you, 1 = Following.
  int get _feed => ref.read(selectedFeedProvider);

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
    final feedIndex = ref.watch(selectedFeedProvider);
    final feed = feedIndex == 0
        ? ref.watch(forYouFeedProvider)
        : ref.watch(followingFeedProvider);
    return AppRefreshView(
      controller: _scroll,
      onRefresh: _refresh,
      slivers: [
        SliverToBoxAdapter(child: _homeHeader()),
        ...feed.when<List<Widget>>(
          loading: () => [
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: AppSpinner()),
            ),
          ],
          error: (error, _) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _RetryView(
                message: friendlyError(error),
                onRetry: _refresh,
              ),
            ),
          ],
          data: _postSlivers,
        ),
      ],
    );
  }

  Widget _homeHeader() {
    final userId = ref.watch(currentUserIdProvider);
    final profile = userId == null
        ? null
        : ref.watch(profileByIdProvider(userId)).value;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => openAppDrawer(context),
                  child: Icon(
                    AppIcons.line_horizontal_3,
                    size: 31,
                    color: context.colors.secondaryLabel,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'threads',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -1.6,
                        color: context.colors.label,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      openScreen<void>(context, const _HomeSearchPage()),
                  child: Icon(
                    AppIcons.search,
                    size: 31,
                    color: context.colors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => openScreen<void>(
              context,
              const ComposeScreen(),
              fullscreen: true,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Row(
                children: [
                  Avatar(
                    name: profile?.name ?? 'You',
                    url: profile?.avatarUrl,
                    size: 58,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.username ?? 'you',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "What's new?",
                          style: TextStyle(
                            fontSize: 16,
                            color: context.colors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(height: .5, color: context.colors.separator),
        ],
      ),
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
                _feed == 0
                    ? 'No threads yet.'
                    : 'Follow people to fill this feed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.secondaryLabel),
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == posts.length) {
            return _hasMore
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: AppSpinner()),
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
                color: context.colors.separator,
              ),
            ],
          );
        }, childCount: posts.length + 1),
      ),
    ];
  }
}

class _HomeSearchPage extends StatelessWidget {
  const _HomeSearchPage();

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    appBar: AdaptiveAppBar(title: 'Search'),
    body: const SearchScreen(),
  );
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
            AdaptiveButton.child(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

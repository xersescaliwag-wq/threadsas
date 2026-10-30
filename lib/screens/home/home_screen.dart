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
            SliverToBoxAdapter(child: _FeedSkeletonList()),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: _feedSwitcher(),
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

  Widget _feedSwitcher() {
    final selected = ref.watch(selectedFeedProvider);
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.systemGrey6,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        for (final entry in const [(0, 'For You'), (1, 'Following')])
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(selectedFeedProvider.notifier).select(entry.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == entry.$1 ? context.colors.systemBackground : null,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected == entry.$1 ? [BoxShadow(color: context.colors.separator, blurRadius: 5, offset: const Offset(0, 1))] : null,
                ),
                child: Text(entry.$2, style: TextStyle(fontSize: 14, fontWeight: selected == entry.$1 ? FontWeight.w700 : FontWeight.w500)),
              ),
            ),
          ),
      ]),
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

class _FeedSkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    children: [for (var i = 0; i < 5; i++) const _SkeletonPost()],
  );
}

class _SkeletonPost extends StatelessWidget {
  const _SkeletonPost();
  @override
  Widget build(BuildContext context) {
    final color = context.colors.systemGrey6;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SkeletonBlock(width: 52, height: 52, radius: 26, color: color),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _SkeletonBlock(width: 136, height: 16, color: color),
            const SizedBox(width: 10),
            _SkeletonBlock(width: 78, height: 14, color: color),
          ]),
          const SizedBox(height: 14),
          _SkeletonBlock(width: double.infinity, height: 16, color: color),
          const SizedBox(height: 10),
          FractionallySizedBox(widthFactor: .72, child: _SkeletonBlock(width: double.infinity, height: 16, color: color)),
        ])),
      ]),
    );
  }
}

class _SkeletonBlock extends StatefulWidget {
  const _SkeletonBlock({required this.width, required this.height, required this.color, this.radius = 2});
  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  State<_SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<_SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final position = -1.5 + (_controller.value * 3);
      final highlight = Color.lerp(
        widget.color,
        CupertinoColors.white,
        0.16,
      )!;
      return ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(position, 0),
          end: Alignment(position + 1, 0),
          colors: [
            widget.color,
            widget.color,
            highlight,
            widget.color,
            widget.color,
          ],
          stops: const [0, .32, .5, .68, 1],
        ).createShader(bounds),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
    },
  );
}

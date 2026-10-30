// lib/screens/profile/profile_screen.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/core/formatters.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/data/social_repository.dart';
import 'package:threads/models/profile.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/providers/feed_providers.dart';
import 'package:threads/providers/post_state_provider.dart';
import 'package:threads/providers/social_providers.dart';
import 'package:threads/providers/thread_providers.dart';
import 'package:threads/screens/messages/chat_screen.dart';
import 'package:threads/screens/profile/edit_profile_screen.dart';
import 'package:threads/screens/profile/follow_list_screen.dart';
import 'package:threads/widgets/avatar.dart';
import 'package:threads/widgets/thread_card.dart';
import 'package:url_launcher/url_launcher.dart';

const _pageSize = 20;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    required this.userId,
    this.showAppBar = true,
  });
  final String userId;
  final bool showAppBar;
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileSkeletonBlock extends StatefulWidget {
  const _ProfileSkeletonBlock({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
  });
  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  State<_ProfileSkeletonBlock> createState() => _ProfileSkeletonBlockState();
}

class _ProfileSkeletonBlockState extends State<_ProfileSkeletonBlock>
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
    builder: (context, _) {
      final position = -1.5 + (_controller.value * 3);
      final highlight = Color.lerp(widget.color, CupertinoColors.white, .16)!;
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

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _tabNames = ['threads', 'replies', 'media', 'reposts'];
  int _tab = 0;
  final Map<String, ThreadPost> _edits = {};
  final Set<String> _gone = {};
  final List<ThreadPost> _more = [];
  bool _endReached = false;
  bool _loadingMore = false;
  String get _tabName => _tabNames[_tab];
  ThreadPost _current(ThreadPost post) => _edits[post.id] ?? post;
  void _changed(ThreadPost post) => setState(() => _edits[post.id] = post);
  void _selectTab(int tab) {
    setState(() {
      _tab = tab;
      _more.clear();
      _gone.clear();
      _endReached = false;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _more.clear();
      _gone.clear();
      _edits.clear();
      _endReached = false;
    });
    // The rows coming back are the server's truth, so shared copies are out of date.
    ref.read(postStateProvider.notifier).clear();
    ref.invalidate(profileByIdProvider(widget.userId));
    ref.invalidate(followStateProvider(widget.userId));
    ref.invalidate(pinnedThreadProvider(widget.userId));
    ref.invalidate(profileTabProvider((widget.userId, _tabName)));
    await ref.read(profileTabProvider((widget.userId, _tabName)).future);
  }

  /// Fetches the next page of the current tab. Each page starts after the oldest post on screen.
  Future<void> _loadMore(List<ThreadPost> shown) async {
    if (_loadingMore || _endReached || shown.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(threadRepositoryProvider)
          .fetchByAuthor(
            widget.userId,
            tab: _tabName,
            before: shown.last.createdAt,
          );
      setState(() {
        _more.addAll(page);
        if (page.length < _pageSize) _endReached = true;
      });
    } catch (error) {
      if (mounted) await showError(context, error);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggleFollow(Profile profile, FollowState current) async {
    try {
      final social = ref.read(socialRepositoryProvider);
      if (current == FollowState.none) {
        await social.follow(profile.id);
      } else {
        final requested = current == FollowState.requested;
        final sure = await confirm(
          context,
          title: requested
              ? 'Cancel request?'
              : 'Unfollow @${profile.username}?',
          message: requested
              ? 'Your follow request will be withdrawn.'
              : 'You will stop seeing their posts in Following.',
          actionLabel: requested ? 'Cancel request' : 'Unfollow',
          destructive: true,
        );
        if (!sure) return;
        await social.unfollow(profile.id);
      }
      ref.invalidate(followStateProvider(profile.id));
      // Their follower count and follower list changed.
      ref.invalidate(profileByIdProvider(profile.id));
      ref.invalidate(followersProvider(profile.id));
      // My following count and following list changed too. My own profile
      // stays mounted in the main shell, so it has to be told to reload its
      // counts or the number on screen stays stale.
      final me = ref.read(currentUserIdProvider);
      if (me != null) {
        ref.invalidate(profileByIdProvider(me));
        ref.invalidate(followingListProvider(me));
      }
      ref.invalidate(followingFeedProvider);
    } catch (error) {
      if (mounted) await showError(context, error);
    }
  }

  void _message(Profile profile) {
    openScreen<void>(context, ChatScreen(other: profile));
  }

  Future<void> _editProfile(Profile profile) async {
    final saved = await openScreen<bool>(
      context,
      EditProfileScreen(profile: profile),
    );
    if (saved == true) await _refresh();
  }

  void _openWebsite(String value) {
    final url = value.startsWith('http') ? value : 'https://$value';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String _followLabel(FollowState state) => switch (state) {
    FollowState.none => 'Follow',
    FollowState.following => 'Following',
    FollowState.requested => 'Requested',
  };
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileByIdProvider(widget.userId));
    final me = ref.watch(currentUserIdProvider);
    final body = AppContentSafeArea(
      child: ResponsiveContent(
        child: profileAsync.when<Widget>(
          loading: () => _profileSkeleton(),
          error: (error, _) => Center(child: Text(friendlyError(error))),
          data: (profile) {
            if (profile == null) {
              return const Center(
                child: Text('This account is not available.'),
              );
            }
            return _buildBody(profile, isMine: profile.id == me);
          },
        ),
      ),
    );
    if (!widget.showAppBar) return body;
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: profileAsync.value?.username ?? 'Profile'),
      body: body,
    );
  }

  Widget _buildBody(Profile profile, {required bool isMine}) {
    final followState = isMine
        ? FollowState.following
        : (ref.watch(followStateProvider(profile.id)).value ??
              FollowState.none);
    final locked =
        profile.isPrivate && !isMine && followState != FollowState.following;
    return AppRefreshView(
      onRefresh: _refresh,
      slivers: [
        SliverToBoxAdapter(
          child: _header(profile, isMine: isMine, followState: followState),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: AdaptiveSegmentedControl(
              labels: const ['Posts', 'Replies', 'Media', 'Reposts'],
              selectedIndex: _tab,
              onValueChanged: _selectTab,
            ),
          ),
        ),
        if (locked)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'This account is private. Follow it to see its posts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.secondaryLabel),
                ),
              ),
            ),
          ),
        if (!locked) ..._postSlivers(profile.id),
      ],
    );
  }

  Widget _profileSkeleton() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBlock(width: 150, height: 22),
                const SizedBox(height: 10),
                _skeletonBlock(width: 100, height: 14),
              ],
            ),
          ),
          _skeletonBlock(width: 88, height: 88, radius: 44),
        ],
      ),
      const SizedBox(height: 18),
      _skeletonBlock(width: double.infinity, height: 15),
      const SizedBox(height: 9),
      _skeletonBlock(width: 220, height: 15),
      const SizedBox(height: 18),
      Row(
        children: [
          _skeletonBlock(width: 100, height: 15),
          const SizedBox(width: 18),
          _skeletonBlock(width: 100, height: 15),
        ],
      ),
      const SizedBox(height: 18),
      _skeletonBlock(width: double.infinity, height: 42, radius: 10),
      const SizedBox(height: 18),
      _skeletonBlock(width: double.infinity, height: 42, radius: 10),
    ],
  );

  Widget _skeletonBlock({
    required double width,
    required double height,
    double radius = 3,
  }) => _ProfileSkeletonBlock(
    width: width,
    height: height,
    radius: radius,
    color: context.colors.systemGrey6,
  );
  Widget _header(
    Profile profile, {
    required bool isMine,
    required FollowState followState,
  }) {
    final website = profile.website;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (profile.isVerified) ...[
                          const SizedBox(width: 6),
                          Icon(
                            AppIcons.checkmark_seal_fill,
                            size: 18,
                            color: context.colors.activeBlue,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${profile.username}',
                      style: TextStyle(
                        fontSize: 15,
                        color: context.colors.secondaryLabel,
                      ),
                    ),
                    if (profile.isPrivate) ...[
                      const SizedBox(height: 7),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppIcons.lock_fill,
                            size: 13,
                            color: context.colors.secondaryLabel,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Private',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.secondaryLabel,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (profile.bio.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(profile.bio, style: const TextStyle(fontSize: 15)),
                    ],
                  ],
                ),
              ),
              Avatar(name: profile.name, url: profile.avatarUrl, size: 88),
            ],
          ),
          if (website != null && website.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _openWebsite(website),
              child: Row(
                children: [
                  Icon(
                    AppIcons.link,
                    size: 15,
                    color: context.colors.activeBlue,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      website,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: context.colors.activeBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () => openScreen<void>(
                  context,
                  FollowListScreen(userId: profile.id, showFollowers: true),
                ),
                child: Text(
                  '${compactCount(profile.followersCount)} followers',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => openScreen<void>(
                  context,
                  FollowListScreen(userId: profile.id, showFollowers: false),
                ),
                child: Text(
                  '${compactCount(profile.followingCount)} following',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isMine)
            SizedBox(
              width: double.infinity,
              child: AdaptiveButton.child(
                onPressed: () => _editProfile(profile),
                child: const Text(
                  'Edit profile',
                  style: TextStyle(
                    color: CupertinoColors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: AdaptiveButton.child(
                    onPressed: () => _toggleFollow(profile, followState),
                    child: Text(
                      _followLabel(followState),
                      style: const TextStyle(
                        color: CupertinoColors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AdaptiveButton.child(
                    style: AdaptiveButtonStyle.tinted,
                    onPressed: () => _message(profile),
                    child: const Text('Message'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _profilePostSkeleton() => Column(
    children: [
      for (var i = 0; i < 4; i++)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _skeletonBlock(width: 42, height: 42, radius: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _skeletonBlock(width: 120, height: 14),
                        const SizedBox(width: 8),
                        _skeletonBlock(width: 58, height: 12),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _skeletonBlock(width: double.infinity, height: 14),
                    const SizedBox(height: 8),
                    _skeletonBlock(width: 190, height: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );

  List<Widget> _postSlivers(String userId) {
    final firstPage = ref.watch(profileTabProvider((userId, _tabName)));
    final pinned = _tab == 0
        ? ref.watch(pinnedThreadProvider(userId)).value
        : null;
    return firstPage.when<List<Widget>>(
      loading: () => [SliverToBoxAdapter(child: _profilePostSkeleton())],
      error: (error, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text(friendlyError(error))),
        ),
      ],
      data: (page) {
        final posts = [
          ...page,
          ..._more,
        ].where((post) => !_gone.contains(post.id)).toList();
        final rows = <Widget>[
          if (pinned != null && !_gone.contains(pinned.id)) _row(pinned),
          for (final post in posts) _row(post),
        ];
        if (rows.isEmpty) {
          rows.add(
            Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Nothing here yet.',
                  style: TextStyle(color: context.colors.secondaryLabel),
                ),
              ),
            ),
          );
        }
        if (!_endReached && posts.isNotEmpty) rows.add(_loadMoreRow(posts));
        return [SliverList(delegate: SliverChildListDelegate(rows))];
      },
    );
  }

  Widget _row(ThreadPost post) {
    return Column(
      key: ValueKey(post.id),
      children: [
        ThreadCard(
          post: _current(post),
          onChanged: _changed,
          onDeleted: () => setState(() => _gone.add(post.id)),
        ),
        Container(
          height: 0.5,
          margin: const EdgeInsets.only(left: 68),
          color: context.colors.separator,
        ),
      ],
    );
  }

  Widget _loadMoreRow(List<ThreadPost> shown) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: _loadingMore
            ? const AppSpinner()
            : AdaptiveButton.child(
                onPressed: () => _loadMore(shown),
                child: const Text('Load more'),
              ),
      ),
    );
  }
}

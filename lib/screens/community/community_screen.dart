// lib/screens/community/community_screen.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/core/formatters.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/models/community.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/providers/community_providers.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/providers/post_state_provider.dart';
import 'package:threads/providers/social_providers.dart';

import 'package:threads/screens/compose/compose_screen.dart';
import 'package:threads/widgets/small_button.dart';
import 'package:threads/widgets/thread_card.dart';

const _pageSize = 20;

/// One community: a header with its name, description and a join button, then
/// its own feed. The database shows the posts only to members, so a non-member
/// sees the invite instead of a feed.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key, required this.communityId});

  final String communityId;

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  // Local copies made by cards (likes, votes, edits), kept until the next
  // reload, exactly as the topic screen does.
  final Map<String, ThreadPost> _edits = {};
  final Set<String> _gone = {};
  final List<ThreadPost> _more = [];
  bool _endReached = false;
  bool _loadingMore = false;
  bool _busyMembership = false;

  /// A just-joined or just-left header, kept until the next reload, so the
  /// button and count feel instant.
  Community? _header;

  String get _id => widget.communityId;

  ThreadPost _current(ThreadPost post) => _edits[post.id] ?? post;
  void _changed(ThreadPost post) => setState(() => _edits[post.id] = post);

  Future<void> _refresh() async {
    setState(() {
      _more.clear();
      _gone.clear();
      _edits.clear();
      _endReached = false;
      _header = null;
    });
    // The rows coming back are the server's truth, so shared copies are out of date.
    ref.read(postStateProvider.notifier).clear();
    ref.invalidate(communityProvider(_id));
    ref.invalidate(communityFeedProvider(_id));
    await ref.read(communityProvider(_id).future);
    await ref.read(communityFeedProvider(_id).future);
  }

  Future<void> _toggleMembership(Community community) async {
    if (_busyMembership) return;
    final joining = !community.joinedByMe;
    setState(() {
      _busyMembership = true;
      _header = community.copyWith(
        joinedByMe: joining,
        memberCount: community.memberCount + (joining ? 1 : -1),
      );
    });
    try {
      final repository = ref.read(communityRepositoryProvider);
      if (joining) {
        await repository.join(community.id);
      } else {
        await repository.leave(community.id);
      }
      ref.invalidate(communitiesProvider);
      ref.invalidate(myCommunitiesProvider);
      // A new member may now read the posts, and someone who left may not.
      ref.invalidate(communityFeedProvider(_id));
      if (mounted) await ref.read(communityFeedProvider(_id).future);
    } catch (error) {
      if (mounted) {
        setState(() => _header = null);
        await showError(context, error);
      }
    } finally {
      if (mounted) setState(() => _busyMembership = false);
    }
  }

  /// Each page starts after the oldest post on screen.
  Future<void> _loadMore(List<ThreadPost> all) async {
    if (_loadingMore || _endReached || all.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(threadRepositoryProvider).fetchCommunity(
            _id,
            before: all.last.createdAt,
          );
      if (!mounted) return;
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

  Future<void> _compose(Community community) async {
    final created = await openScreen<ThreadPost>(
      context,
      ComposeScreen(community: community),
      fullscreen: true,
    );
    if (created != null && mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final headerAsync = ref.watch(communityProvider(_id));
    final community = _header ?? headerAsync.value;
    final muted = ref.watch(mutedIdsProvider).value ?? const <String>{};
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: community?.name ?? 'Community',
        actions: [
          if (community?.joinedByMe ?? false)
            AdaptiveAppBarAction(
              iosSymbol: 'square.and.pencil',
              icon: AppIcons.pencil,
              onPressed: () => _compose(community!),
            ),
        ],
      ),
      body: headerAsync.when<Widget>(
        loading: () => const Center(child: AppSpinner()),
        error: (error, _) => Center(child: Text(friendlyError(error))),
        data: (loaded) {
          final shown = _header ?? loaded;
          final feed = ref.watch(communityFeedProvider(_id));
          return feed.when<Widget>(
            loading: () => CustomScrollView(
              slivers: [
                _headerSliver(shown, onToggle: () => _toggleMembership(shown)),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: AppSpinner()),
                ),
              ],
            ),
            error: (error, _) => CustomScrollView(
              slivers: [
                _headerSliver(shown, onToggle: () => _toggleMembership(shown)),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(friendlyError(error), textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ],
            ),
            data: (page) {
              final all = [...page, ..._more];
              final posts = all
                  .where((post) =>
                      !muted.contains(post.author.id) && !_gone.contains(post.id))
                  .toList();
              final hasMore = !_endReached && page.length >= _pageSize;
              return AppRefreshView(
                onRefresh: _refresh,
                slivers: [
                  _headerSliver(shown, onToggle: () => _toggleMembership(shown)),
                  if (!shown.joinedByMe)
                    SliverToBoxAdapter(
                      child: _Invite(
                        community: shown,
                        busy: _busyMembership,
                        onJoin: () => _toggleMembership(shown),
                      ),
                    )
                  else if (posts.isEmpty)
                    SliverToBoxAdapter(
                      child: _EmptyFeed(
                        community: shown,
                        onCompose: () => _compose(shown),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildListDelegate([
                        for (final post in posts)
                          Column(
                            key: ValueKey(post.id),
                            children: [
                              ThreadCard(
                                post: _current(post),
                                onChanged: _changed,
                                onDeleted: () =>
                                    setState(() => _gone.add(post.id)),
                              ),
                              Container(
                                height: 0.5,
                                margin: const EdgeInsets.only(left: 68),
                                color: context.colors.separator,
                              ),
                            ],
                          ),
                        if (hasMore)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: _loadingMore
                                  ? const AppSpinner()
                                  : AdaptiveButton.child(
                                      onPressed: () => _loadMore(all),
                                      child: const Text('Load more'),
                                    ),
                            ),
                          ),
                      ]),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _headerSliver(Community community, {required VoidCallback onToggle}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    community.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (community.isPrivate)
                  Icon(
                    AppIcons.lock_fill,
                    size: 16,
                    color: context.colors.secondaryLabel,
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'threads/${community.slug} · '
              '${compactCount(community.memberCount)} member'
              '${community.memberCount == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 13,
                color: context.colors.secondaryLabel,
              ),
            ),
            if (community.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(community.description, style: const TextStyle(fontSize: 15)),
            ],
            const SizedBox(height: 12),
            SmallButton(
              label: community.joinedByMe ? 'Joined' : 'Join',
              filled: !community.joinedByMe,
              onPressed: _busyMembership ? null : onToggle,
            ),
            const SizedBox(height: 12),
            Container(height: 0.5, color: context.colors.separator),
          ],
        ),
      ),
    );
  }
}

/// Shown to someone who has not joined: the database gives them no posts.
class _Invite extends StatelessWidget {
  const _Invite({
    required this.community,
    required this.busy,
    required this.onJoin,
  });

  final Community community;
  final bool busy;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
      child: Column(
        children: [
          Icon(
            AppIcons.person_2,
            size: 40,
            color: context.colors.systemGrey,
          ),
          const SizedBox(height: 12),
          Text(
            community.isPrivate
                ? 'This community is private. Join to see its threads.'
                : 'Join this community to see its threads.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.secondaryLabel),
          ),
          const SizedBox(height: 16),
          SmallButton(label: 'Join', filled: true, onPressed: busy ? null : onJoin),
        ],
      ),
    );
  }
}

/// Shown to a member when the community has no threads yet.
class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.community, required this.onCompose});

  final Community community;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
      child: Column(
        children: [
          Text(
            'No threads in ${community.name} yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.secondaryLabel),
          ),
          const SizedBox(height: 16),
          SmallButton(
            label: 'Start a thread',
            filled: true,
            onPressed: onCompose,
          ),
        ],
      ),
    );
  }
}

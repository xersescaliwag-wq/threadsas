// lib/screens/community/community_list_screen.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/formatters.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/models/community.dart';
import 'package:threads/providers/community_providers.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/screens/community/community_screen.dart';
import 'package:threads/screens/community/create_community_screen.dart';
import 'package:threads/widgets/small_button.dart';

/// The list of communities. Public ones are shown to everyone; private ones
/// appear only to their members, because the database hides the rest.
class CommunityListScreen extends ConsumerStatefulWidget {
  const CommunityListScreen({super.key});

  @override
  ConsumerState<CommunityListScreen> createState() =>
      _CommunityListScreenState();
}

class _CommunityListScreenState extends ConsumerState<CommunityListScreen> {
  final _search = TextEditingController();

  /// Communities whose join state changed on this screen, kept until the next
  /// reload so the buttons feel instant.
  final Map<String, Community> _local = {};
  final Set<String> _busy = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Community _current(Community community) => _local[community.id] ?? community;

  Future<void> _refresh() async {
    setState(() {
      _local.clear();
    });
    ref.invalidate(communitiesProvider);
    ref.invalidate(myCommunitiesProvider);
    await ref.read(communitiesProvider.future);
  }

  Future<void> _toggleMembership(Community community) async {
    final current = _current(community);
    if (_busy.contains(community.id)) return;
    final joining = !current.joinedByMe;
    setState(() {
      _busy.add(community.id);
      _local[community.id] = current.copyWith(
        joinedByMe: joining,
        memberCount: current.memberCount + (joining ? 1 : -1),
      );
    });
    try {
      final repository = ref.read(communityRepositoryProvider);
      if (joining) {
        await repository.join(community.id);
      } else {
        await repository.leave(community.id);
      }
      ref.invalidate(myCommunitiesProvider);
    } catch (error) {
      if (mounted) {
        setState(() => _local.remove(community.id)); // put the button back
        await showError(context, error);
      }
    } finally {
      if (mounted) setState(() => _busy.remove(community.id));
    }
  }

  Future<void> _open(Community community) async {
    await openScreen<void>(context, CommunityScreen(communityId: community.id));
    // The screen may have joined or left, so discard the local guesses.
    if (mounted) {
      setState(_local.clear);
      ref.invalidate(communitiesProvider);
    }
  }

  Future<void> _create() async {
    final created = await openScreen<Community>(
      context,
      const CreateCommunityScreen(),
      fullscreen: true,
    );
    if (created == null || !mounted) return;
    setState(_local.clear);
    ref.invalidate(communitiesProvider);
    ref.invalidate(myCommunitiesProvider);
    await openScreen<void>(context, CommunityScreen(communityId: created.id));
  }

  @override
  Widget build(BuildContext context) {
    final communities = ref.watch(communitiesProvider);
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: 'Communities',
        actions: [
          AdaptiveAppBarAction(
            iosSymbol: 'plus',
            icon: AppIcons.add,
            onPressed: _create,
          ),
        ],
      ),
      body: ResponsiveContent(
        child: communities.when<Widget>(
          loading: () => const Center(child: AppSpinner()),
          error: (error, _) => Center(child: Text(friendlyError(error))),
          data: (all) {
            final query = _search.text.trim().toLowerCase();
            final shown = all
                .where(
                  (community) =>
                      query.isEmpty ||
                      community.name.toLowerCase().contains(query) ||
                      community.slug.toLowerCase().contains(query),
                )
                .toList();
            return AppRefreshView(
              onRefresh: _refresh,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: AppSearchField(
                      controller: _search,
                      placeholder: 'Search communities',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                if (shown.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No communities yet. Tap + to start one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.colors.secondaryLabel,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildListDelegate([
                      for (final community in shown)
                        _CommunityRow(
                          community: _current(community),
                          onTap: () => _open(community),
                          onToggle: () => _toggleMembership(community),
                        ),
                    ]),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CommunityRow extends StatelessWidget {
  const _CommunityRow({
    required this.community,
    required this.onTap,
    required this.onToggle,
  });

  final Community community;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              AppIcons.person_2_fill,
              size: 30,
              color: context.colors.systemGrey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          community.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (community.isPrivate) ...[
                        const SizedBox(width: 6),
                        Icon(
                          AppIcons.lock_fill,
                          size: 12,
                          color: context.colors.secondaryLabel,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${compactCount(community.memberCount)} member'
                    '${community.memberCount == 1 ? '' : 's'} · threads/${community.slug}',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.secondaryLabel,
                    ),
                  ),
                  if (community.description.isNotEmpty)
                    Text(
                      community.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SmallButton(
              label: community.joinedByMe ? 'Joined' : 'Join',
              filled: !community.joinedByMe,
              onPressed: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}

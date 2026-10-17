// lib/screens/profile/follow_list_screen.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/providers/social_providers.dart';
import 'package:threads/widgets/profile_row.dart';
class FollowListScreen extends ConsumerWidget {
  const FollowListScreen({super.key, required this.userId, required this.showFollowers});
  final String userId;
  final bool showFollowers;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = showFollowers ? followersProvider(userId) : followingListProvider(userId);
    final people = ref.watch(provider);
    Future<void> refresh() async {
      ref.invalidate(provider);
      await ref.read(provider.future);
    }
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: showFollowers ? 'Followers' : 'Following'),
      body: people.when<Widget>(
        loading: () => const Center(child: AppSpinner()),
        error: (error, _) => Center(child: Text(friendlyError(error))),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                showFollowers ? 'No followers yet.' : 'Not following anyone yet.',
                style: TextStyle(color: context.colors.secondaryLabel),
              ),
            );
          }
          return AppRefreshView(
            onRefresh: refresh,
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Column(
                    children: [
                      ProfileRow(profile: list[index]),
                      Container(height: 0.5, margin: const EdgeInsets.only(left: 72), color: context.colors.separator),
                    ],
                  ),
                  childCount: list.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

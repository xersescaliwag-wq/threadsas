// lib/screens/profile/follow_requests_screen.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/models/profile.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/providers/social_providers.dart';
import 'package:threads/widgets/profile_row.dart';
import 'package:threads/widgets/small_button.dart';

class FollowRequestsScreen extends ConsumerStatefulWidget {
  const FollowRequestsScreen({super.key});
  @override
  ConsumerState<FollowRequestsScreen> createState() =>
      _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends ConsumerState<FollowRequestsScreen> {
  final Set<String> _answered = {};
  final Set<String> _busy = {};
  Future<void> _answer(Profile person, {required bool accept}) async {
    if (_busy.contains(person.id)) return;
    setState(() => _busy.add(person.id));
    try {
      final social = ref.read(socialRepositoryProvider);
      if (accept) {
        await social.acceptRequest(person.id);
      } else {
        await social.declineRequest(person.id);
      }
      _answered.add(person.id);
      ref.invalidate(followRequestsProvider);
      final me = ref.read(currentUserIdProvider);
      // Accepting raises my follower count, so reload my profile.
      if (accept && me != null) ref.invalidate(profileByIdProvider(me));
    } catch (error) {
      if (mounted) await showError(context, error);
    } finally {
      if (mounted) setState(() => _busy.remove(person.id));
    }
  }

  Future<void> _refresh() async {
    _answered.clear();
    ref.invalidate(followRequestsProvider);
    await ref.read(followRequestsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(followRequestsProvider);
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Follow requests'),
      body: ResponsiveContent(
        child: requests.when<Widget>(
          skipLoadingOnReload: true,
          loading: () => const Center(child: AppSpinner()),
          error: (error, _) => Center(child: Text(friendlyError(error))),
          data: (all) {
            final people = all
                .where((person) => !_answered.contains(person.id))
                .toList();
            if (people.isEmpty) {
              return Center(
                child: Text(
                  'No pending requests.',
                  style: TextStyle(color: context.colors.secondaryLabel),
                ),
              );
            }
            return AppRefreshView(
              onRefresh: _refresh,
              slivers: [
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final person = people[index];
                    final busy = _busy.contains(person.id);
                    return Column(
                      children: [
                        ProfileRow(
                          profile: person,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SmallButton(
                                label: 'Confirm',
                                filled: true,
                                onPressed: busy
                                    ? null
                                    : () => _answer(person, accept: true),
                              ),
                              const SizedBox(width: 8),
                              SmallButton(
                                label: 'Delete',
                                onPressed: busy
                                    ? null
                                    : () => _answer(person, accept: false),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 0.5,
                          margin: const EdgeInsets.only(left: 72),
                          color: context.colors.separator,
                        ),
                      ],
                    );
                  }, childCount: people.length),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

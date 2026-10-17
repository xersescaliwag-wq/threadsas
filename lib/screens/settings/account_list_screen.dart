// lib/screens/settings/account_list_screen.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/models/profile.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/providers/feed_providers.dart';
import 'package:threads/providers/social_providers.dart';
import 'package:threads/widgets/profile_row.dart';
import 'package:threads/widgets/small_button.dart';
enum AccountListKind { blocked, muted }
class AccountListScreen extends ConsumerStatefulWidget {
  const AccountListScreen({super.key, required this.kind});
  final AccountListKind kind;
  @override
  ConsumerState<AccountListScreen> createState() => _AccountListScreenState();
}
class _AccountListScreenState extends ConsumerState<AccountListScreen> {
  final Set<String> _removed = {};
  final Set<String> _busy = {};
  bool get _isBlocked => widget.kind == AccountListKind.blocked;
  Future<void> _undo(Profile person) async {
    if (_busy.contains(person.id)) return;
    setState(() => _busy.add(person.id));
    try {
      final social = ref.read(socialRepositoryProvider);
      if (_isBlocked) {
        await social.unblock(person.id);
        ref.invalidate(blockedProfilesProvider);
        ref.invalidate(followStateProvider(person.id));
        ref.invalidate(profileByIdProvider(person.id));
      } else {
        await social.unmute(person.id);
        ref.invalidate(mutedProfilesProvider);
        ref.invalidate(mutedIdsProvider);
      }
      ref.invalidate(forYouFeedProvider);
      ref.invalidate(followingFeedProvider);
      if (mounted) setState(() => _removed.add(person.id));
    } catch (error) {
      if (mounted) await showError(context, error);
    } finally {
      if (mounted) setState(() => _busy.remove(person.id));
    }
  }
  @override
  Widget build(BuildContext context) {
    final people = _isBlocked ? ref.watch(blockedProfilesProvider) : ref.watch(mutedProfilesProvider);
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: _isBlocked ? 'Blocked accounts' : 'Muted accounts'),
      body: people.when<Widget>(
        skipLoadingOnReload: true,
        loading: () => const Center(child: AppSpinner()),
        error: (error, _) => Center(child: Text(friendlyError(error))),
        data: (all) {
          final list = all.where((person) => !_removed.contains(person.id)).toList();
          if (list.isEmpty) {
            return Center(
              child: Text(
                _isBlocked ? 'You have not blocked anyone.' : 'You have not muted anyone.',
                style: TextStyle(color: context.colors.secondaryLabel),
              ),
            );
          }
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  _isBlocked
                      ? 'Blocked accounts cannot see your threads or follow you. Unblocking does not bring old follows back.'
                      : 'Threads from muted accounts stay out of your feeds. They are not told.',
                  style: TextStyle(fontSize: 13, color: context.colors.secondaryLabel),
                ),
              ),
              for (final person in list)
                Column(
                  children: [
                    ProfileRow(
                      profile: person,
                      trailing: SmallButton(
                        label: _isBlocked ? 'Unblock' : 'Unmute',
                        onPressed: _busy.contains(person.id) ? null : () => _undo(person),
                      ),
                    ),
                    Container(height: 0.5, margin: const EdgeInsets.only(left: 72), color: context.colors.separator),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

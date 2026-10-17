// lib/screens/settings/settings_screen.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/screens/profile/follow_requests_screen.dart';
import 'package:threads/screens/settings/account_list_screen.dart';
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;
  /// Runs one task with the screen locked, and shows any error.
  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } catch (error) {
      if (mounted) await showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  Future<void> _logOut() async {
    final sure = await confirm(
      context,
      title: 'Log out?',
      message: 'You can log back in at any time.',
      actionLabel: 'Log out',
    );
    if (!sure || !mounted) return;
    final navigator = Navigator.of(context);
    await _run(() async {
      await ref.read(authRepositoryProvider).logOut();
      navigator.popUntil((route) => route.isFirst);
    });
  }
  Future<void> _deleteAccount() async {
    final first = await confirm(
      context,
      title: 'Delete your account?',
      message: 'Your profile, threads, replies, likes and uploaded photos are deleted for good.',
      actionLabel: 'Continue',
      destructive: true,
    );
    if (!first || !mounted) return;
    final second = await confirm(
      context,
      title: 'This cannot be undone',
      message: 'Delete your account now?',
      actionLabel: 'Delete account',
      destructive: true,
    );
    if (!second || !mounted) return;
    final userId = ref.read(currentUserIdProvider);
    final navigator = Navigator.of(context);
    await _run(() async {
      // Files first: once the user row is gone, the storage policy no longer matches.
      if (userId != null) await ref.read(mediaRepositoryProvider).deleteAllMine(userId);
      await ref.read(authRepositoryProvider).deleteAccount();
      navigator.popUntil((route) => route.isFirst);
    });
  }
  CupertinoListTile _tile(IconData icon, String title, VoidCallback onTap) {
    return CupertinoListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const CupertinoListTileChevron(),
      onTap: onTap,
    );
  }
  @override
  Widget build(BuildContext context) {
    final email = ref.watch(supabaseClientProvider).auth.currentUser?.email;
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Settings'),
      body: Stack(
        children: [
          IgnorePointer(
            ignoring: _busy,
            child: Opacity(
              opacity: _busy ? 0.5 : 1,
              child: ListView(
                children: [
                  CupertinoListSection.insetGrouped(
                    header: const Text('Privacy'),
                    footer: const Text('To make your account private, use Edit profile on your profile page.'),
                    children: [
                      _tile(
                        CupertinoIcons.person_badge_plus,
                        'Follow requests',
                        () => openScreen<void>(context, const FollowRequestsScreen()),
                      ),
                      _tile(
                        CupertinoIcons.hand_raised,
                        'Blocked accounts',
                        () => openScreen<void>(context, const AccountListScreen(kind: AccountListKind.blocked)),
                      ),
                      _tile(
                        CupertinoIcons.speaker_slash,
                        'Muted accounts',
                        () => openScreen<void>(context, const AccountListScreen(kind: AccountListKind.muted)),
                      ),
                    ],
                  ),
                  CupertinoListSection.insetGrouped(
                    header: const Text('Account'),
                    footer: email == null ? null : Text('Signed in as $email'),
                    children: [
                      CupertinoListTile(title: const Text('Log out'), onTap: _logOut),
                      CupertinoListTile(
                        title: const Text('Delete account', style: TextStyle(color: CupertinoColors.systemRed)),
                        onTap: _deleteAccount,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_busy) const Center(child: CupertinoActivityIndicator(radius: 14)),
        ],
      ),
    );
  }
}

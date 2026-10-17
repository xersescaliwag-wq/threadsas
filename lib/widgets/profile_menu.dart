// lib/widgets/profile_menu.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/models/profile.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/providers/feed_providers.dart';
import 'package:threads/providers/social_providers.dart';
import 'package:threads/widgets/report_dialog.dart';
/// The ... menu on someone else's profile: mute, block and report.
Future<void> showProfileMenu(
  BuildContext context, {
  required WidgetRef ref,
  required Profile profile,
}) async {
  var isMuted = false;
  try {
    isMuted = (await ref.read(mutedIdsProvider.future)).contains(profile.id);
  } catch (_) {}
  if (!context.mounted) return;
  final choice = await showCupertinoModalPopup<String>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      actions: [
        _action(sheetContext, 'mute', isMuted ? 'Unmute @${profile.username}' : 'Mute @${profile.username}'),
        _action(sheetContext, 'block', 'Block @${profile.username}', destructive: true),
        _action(sheetContext, 'report', 'Report @${profile.username}'),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: const Text('Cancel'),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'mute') {
    await _run(context, () => _toggleMute(context, ref, profile, isMuted));
  } else if (choice == 'block') {
    await _confirmBlock(context, ref, profile);
  } else if (choice == 'report') {
    await _report(context, ref, profile);
  }
}
CupertinoActionSheetAction _action(
  BuildContext context,
  String value,
  String label, {
  bool destructive = false,
}) {
  return CupertinoActionSheetAction(
    isDestructiveAction: destructive,
    onPressed: () => Navigator.of(context).pop(value),
    child: Text(label),
  );
}
/// Runs one task and shows any error in plain language.
Future<void> _run(BuildContext context, Future<void> Function() task) async {
  try {
    await task();
  } catch (error) {
    if (context.mounted) await showError(context, error);
  }
}
void _refreshFeeds(WidgetRef ref) {
  ref.invalidate(forYouFeedProvider);
  ref.invalidate(followingFeedProvider);
}
Future<void> _toggleMute(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
  bool isMuted,
) async {
  final social = ref.read(socialRepositoryProvider);
  if (isMuted) {
    await social.unmute(profile.id);
  } else {
    await social.mute(profile.id);
  }
  ref.invalidate(mutedIdsProvider);
  ref.invalidate(mutedProfilesProvider);
  _refreshFeeds(ref);
  if (!context.mounted) return;
  await showMessage(
    context,
    isMuted ? 'Unmuted' : 'Muted',
    isMuted
        ? 'You will see @${profile.username} in your feeds again.'
        : 'Threads from @${profile.username} no longer appear in your feeds. They are not told.',
  );
}
Future<void> _confirmBlock(BuildContext context, WidgetRef ref, Profile profile) async {
  final sure = await confirm(
    context,
    title: 'Block @${profile.username}?',
    message: 'They cannot see your threads or follow you, and you cannot see theirs.',
    actionLabel: 'Block',
    destructive: true,
  );
  if (!sure || !context.mounted) return;
  await _run(context, () async {
    await ref.read(socialRepositoryProvider).block(profile.id);
    ref.invalidate(followStateProvider(profile.id));
    ref.invalidate(profileByIdProvider(profile.id));
    ref.invalidate(blockedProfilesProvider);
    _refreshFeeds(ref);
    if (context.mounted) Navigator.of(context).pop();
  });
}
Future<void> _report(BuildContext context, WidgetRef ref, Profile profile) async {
  final reason = await askReportReason(context, title: 'Report @${profile.username}');
  if (reason == null || !context.mounted) return;
  if (reason.length < 3) {
    await showMessage(context, 'Add a reason', 'Write at least three characters.');
    return;
  }
  await _run(context, () async {
    await ref.read(socialRepositoryProvider).reportProfile(profile.id, reason);
    if (context.mounted) await showMessage(context, 'Thanks', 'We will review this account.');
  });
}

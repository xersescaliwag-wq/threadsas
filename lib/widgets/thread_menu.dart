// lib/widgets/thread_menu.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/links.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/providers/feed_providers.dart';
import 'package:threads/providers/social_providers.dart';
import 'package:threads/providers/thread_providers.dart';
import 'package:threads/screens/compose/compose_screen.dart';

/// The ... menu for one post. Your own posts get edit, pin, hide likes and delete.
/// Other people's posts get mute, block and report.
Future<void> showThreadMenu(
  BuildContext context, {
  required WidgetRef ref,
  required ThreadPost post,
  required bool isMine,
  required ValueChanged<ThreadPost> onChanged,
  VoidCallback? onDeleted,
}) async {
  final choice = await showCupertinoModalPopup<String>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      actions: [
        if (isMine) ...[
          _choice(sheetContext, 'edit', 'Edit'),
          _choice(sheetContext, 'pin', post.isPinned ? 'Unpin from profile' : 'Pin to profile'),
          _choice(
            sheetContext,
            'hide-likes',
            post.hideLikeCount ? 'Show like count' : 'Hide like count',
          ),
          _choice(sheetContext, 'delete', 'Delete', destructive: true),
        ] else ...[
          _choice(sheetContext, 'mute', 'Mute @${post.author.username}'),
          _choice(sheetContext, 'block', 'Block @${post.author.username}', destructive: true),
          _choice(sheetContext, 'report', 'Report'),
        ],
        _choice(sheetContext, 'copy', 'Copy link'),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: const Text('Cancel'),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'edit') {
    await _edit(context, post, onChanged);
  } else if (choice == 'pin') {
    await _run(context, () => _setPinned(ref, post, onChanged));
  } else if (choice == 'hide-likes') {
    await _run(context, () => _setHideLikes(ref, post, onChanged));
  } else if (choice == 'delete') {
    await _confirmDelete(context, ref, post, onDeleted);
  } else if (choice == 'mute') {
    await _mute(context, ref, post);
  } else if (choice == 'block') {
    await _confirmBlock(context, ref, post);
  } else if (choice == 'report') {
    await _report(context, ref, post);
  } else if (choice == 'copy') {
    await copyThreadLink(context, post);
  }
}

CupertinoActionSheetAction _choice(
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

Future<void> _edit(
  BuildContext context,
  ThreadPost post,
  ValueChanged<ThreadPost> onChanged,
) async {
  final updated = await openScreen<ThreadPost>(
    context,
    ComposeScreen(editing: post),
    fullscreen: true,
  );
  if (updated != null) onChanged(updated);
}

Future<void> _setPinned(
  WidgetRef ref,
  ThreadPost post,
  ValueChanged<ThreadPost> onChanged,
) async {
  final pinned = !post.isPinned;
  await ref.read(threadRepositoryProvider).setPinned(post.id, pinned);
  onChanged(post.copyWith(isPinned: pinned));
  // The trigger may have unpinned another post, so refresh the profile header and tabs.
  ref.invalidate(pinnedThreadProvider(post.author.id));
  ref.invalidate(profileTabProvider((post.author.id, 'threads')));
}

Future<void> _setHideLikes(
  WidgetRef ref,
  ThreadPost post,
  ValueChanged<ThreadPost> onChanged,
) async {
  final hidden = !post.hideLikeCount;
  await ref.read(threadRepositoryProvider).updateThread(post.id, hideLikeCount: hidden);
  onChanged(post.copyWith(hideLikeCount: hidden));
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  ThreadPost post,
  VoidCallback? onDeleted,
) async {
  final sure = await confirm(
    context,
    title: 'Delete this thread?',
    message: 'Its replies are deleted with it. This cannot be undone.',
    actionLabel: 'Delete',
    destructive: true,
  );
  if (!sure || !context.mounted) return;
  await _run(context, () async {
    await ref.read(threadRepositoryProvider).deleteThread(post.id);
    onDeleted?.call();
  });
}

Future<void> _mute(BuildContext context, WidgetRef ref, ThreadPost post) async {
  await _run(context, () async {
    await ref.read(socialRepositoryProvider).mute(post.author.id);
    ref.invalidate(mutedIdsProvider);
    ref.invalidate(mutedProfilesProvider);
    _refreshFeeds(ref);
  });
}

Future<void> _confirmBlock(BuildContext context, WidgetRef ref, ThreadPost post) async {
  final sure = await confirm(
    context,
    title: 'Block @${post.author.username}?',
    message: 'They cannot see your posts or follow you, and you cannot see theirs.',
    actionLabel: 'Block',
    destructive: true,
  );
  if (!sure || !context.mounted) return;
  await _run(context, () async {
    await ref.read(socialRepositoryProvider).block(post.author.id);
    ref.invalidate(followStateProvider(post.author.id));
    ref.invalidate(blockedProfilesProvider);
    _refreshFeeds(ref);
  });
}

Future<void> _report(BuildContext context, WidgetRef ref, ThreadPost post) async {
  final reason = await _askReason(context);
  if (reason == null || !context.mounted) return;
  if (reason.length < 3) {
    await showMessage(context, 'Add a reason', 'Write at least three characters.');
    return;
  }
  await _run(context, () async {
    await ref.read(socialRepositoryProvider).reportThread(post.id, reason);
    if (context.mounted) {
      await showMessage(context, 'Thanks', 'We will review this post.');
    }
  });
}

/// A dialog with a text box. Returns the trimmed reason, or null when the person cancels.
Future<String?> _askReason(BuildContext context) {
  final controller = TextEditingController();
  return showCupertinoDialog<String>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('Report this post'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: controller,
          placeholder: 'What is wrong with it?',
          maxLines: 3,
          maxLength: 500,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
          child: const Text('Send'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

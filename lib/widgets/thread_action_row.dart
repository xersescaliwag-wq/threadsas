// lib/widgets/thread_action_row.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/formatters.dart';
import 'package:threads/core/links.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/data/thread_repository.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/screens/compose/compose_screen.dart';

/// The buttons under a post. Each tap updates the card at once, then saves.
class ThreadActionRow extends ConsumerStatefulWidget {
  const ThreadActionRow({super.key, required this.post, required this.onChanged});
  final ThreadPost post;
  final ValueChanged<ThreadPost> onChanged;

  @override
  ConsumerState<ThreadActionRow> createState() => _ThreadActionRowState();
}

class _ThreadActionRowState extends ConsumerState<ThreadActionRow> {
  bool _busy = false; // stops a second write from starting while the first is saving
  ThreadRepository get _threads => ref.read(threadRepositoryProvider);

  Future<void> _toggleLike() async {
    if (_busy) return;
    _busy = true;
    final before = widget.post;
    final liked = !before.likedByMe;
    widget.onChanged(before.copyWith(
      likedByMe: liked,
      likeCount: _bump(before.likeCount, liked ? 1 : -1),
    ));
    try {
      if (liked) {
        await _threads.like(before.id);
      } else {
        await _threads.unlike(before.id);
      }
    } catch (error) {
      if (mounted) {
        widget.onChanged(before);
        await showError(context, error);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _toggleRepost() async {
    if (_busy) return;
    _busy = true;
    final before = widget.post;
    final reposted = !before.repostedByMe;
    widget.onChanged(before.copyWith(
      repostedByMe: reposted,
      repostCount: _bump(before.repostCount, reposted ? 1 : -1),
    ));
    try {
      if (reposted) {
        await _threads.repost(before.id);
      } else {
        await _threads.undoRepost(before.id);
      }
    } catch (error) {
      if (mounted) {
        widget.onChanged(before);
        await showError(context, error);
      }
    } finally {
      _busy = false;
    }
  }

  /// The repost button offers two choices: a plain repost, or a quote with your own words.
  Future<void> _showRepostChoices() async {
    final post = widget.post;
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop('repost'),
            child: Text(post.repostedByMe ? 'Undo repost' : 'Repost'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop('quote'),
            child: const Text('Quote'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'repost') {
      await _toggleRepost();
    } else {
      await openScreen<ThreadPost>(context, ComposeScreen(quoting: post), fullscreen: true);
    }
  }

  /// A reply is saved by the composer. The count here rises at once, without a reload.
  Future<void> _reply() async {
    final reply = await openScreen<ThreadPost>(
      context,
      ComposeScreen(replyTo: widget.post),
      fullscreen: true,
    );
    if (reply != null && mounted) {
      widget.onChanged(widget.post.copyWith(replyCount: widget.post.replyCount + 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isMine = post.author.id == ref.watch(currentUserIdProvider);
    final hideCount = post.hideLikeCount && !isMine;
    return Row(
      children: [
        _ActionButton(
          icon: post.likedByMe ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
          tint: post.likedByMe ? CupertinoColors.systemRed : null,
          count: hideCount ? null : post.likeCount,
          onTap: _toggleLike,
        ),
        _ActionButton(
          icon: CupertinoIcons.chat_bubble,
          count: post.replyCount,
          onTap: _reply,
        ),
        _ActionButton(
          icon: CupertinoIcons.arrow_2_squarepath,
          tint: post.repostedByMe ? CupertinoColors.activeGreen : null,
          count: post.repostCount + post.quoteCount,
          onTap: _showRepostChoices,
        ),
        _ActionButton(
          icon: CupertinoIcons.paperplane,
          onTap: () => copyThreadLink(context, post),
        ),
      ],
    );
  }
}

int _bump(int value, int delta) => value + delta < 0 ? 0 : value + delta;

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.onTap, this.count, this.tint});
  final IconData icon;
  final VoidCallback onTap;
  final int? count;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? CupertinoColors.label;
    final shown = count;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 21, color: color),
            if (shown != null && shown > 0) ...[
              const SizedBox(width: 5),
              Text(compactCount(shown), style: TextStyle(fontSize: 14, color: color)),
            ],
          ],
        ),
      ),
    );
  }
}

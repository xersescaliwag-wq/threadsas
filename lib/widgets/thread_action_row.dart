// lib/widgets/thread_action_row.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/formatters.dart';
import 'package:threads/core/links.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/data/thread_repository.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/screens/compose/compose_screen.dart';
import 'package:threads/screens/thread/thread_detail_screen.dart';

/// The buttons under a post. Each tap updates the card at once, then saves.
class ThreadActionRow extends ConsumerStatefulWidget {
  const ThreadActionRow({super.key, required this.post, required this.onChanged, this.compact = false, this.disableComment = false});
  final ThreadPost post;
  final ValueChanged<ThreadPost> onChanged;
  final bool compact;
  final bool disableComment;

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
    final choice = await showAppActionSheet<String>(
      context,
      items: [
        AppActionSheetItem(
          value: 'repost',
          label: post.repostedByMe ? 'Undo repost' : 'Repost',
        ),
        const AppActionSheetItem(value: 'quote', label: 'Quote'),
      ],
    );
    if (!mounted || choice == null) return;
    if (choice == 'repost') {
      await _toggleRepost();
    } else {
      await openScreen<ThreadPost>(context, ComposeScreen(quoting: post), fullscreen: true);
    }
  }

  /// Opens the public thread view. Replies are displayed there and can be
  /// posted from its public reply composer.
  Future<void> _reply() async {
    await openScreen<void>(context, ThreadDetailScreen(threadId: widget.post.id));
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isMine = post.author.id == ref.watch(currentUserIdProvider);
    final hideCount = post.hideLikeCount && !isMine;
    return Row(
      children: [
        _ActionButton(
          compact: widget.compact,
          icon: post.likedByMe ? AppIcons.heart_fill : AppIcons.heart,
          tint: post.likedByMe ? context.colors.systemRed : null,
          count: hideCount ? null : post.likeCount,
          onTap: _toggleLike,
        ),
        _ActionButton(
          compact: widget.compact,
          icon: AppIcons.chat_bubble,
          count: post.replyCount,
          onTap: widget.disableComment ? () {} : _reply,
        ),
        _ActionButton(
          compact: widget.compact,
          icon: AppIcons.arrow_2_squarepath,
          tint: post.repostedByMe ? context.colors.activeGreen : null,
          count: post.repostCount + post.quoteCount,
          onTap: _showRepostChoices,
        ),
        _ActionButton(
          compact: widget.compact,
          icon: AppIcons.paperplane,
          onTap: () => copyThreadLink(context, post),
        ),
      ],
    );
  }
}

int _bump(int value, int delta) => value + delta < 0 ? 0 : value + delta;

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.onTap, this.count, this.tint, this.compact = false});
  final IconData icon;
  final VoidCallback onTap;
  final int? count;
  final Color? tint;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? context.colors.label;
    final shown = count;
    final button = Semantics(
        button: true,
        label: _accessibilityLabel(icon, shown),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: 8,
              horizontal: compact ? 1 : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: compact ? 19 : 21, color: color),
                if (shown != null && shown > 0) ...[
                  const SizedBox(width: 3),
                  Text(compactCount(shown), style: TextStyle(fontSize: compact ? 12 : 14, color: color)),
                ],
              ],
            ),
          ),
        ),
      );
    return compact ? SizedBox(width: 58, child: button) : Expanded(child: button);
  }
}

String _accessibilityLabel(IconData icon, int? count) {
  final suffix = count == null || count == 0 ? '' : ', ${compactCount(count)}';
  if (icon == AppIcons.heart || icon == AppIcons.heart_fill) return 'Like$suffix';
  if (icon == AppIcons.chat_bubble) return 'Reply$suffix';
  if (icon == AppIcons.arrow_2_squarepath) return 'Repost or quote$suffix';
  if (icon == AppIcons.paperplane) return 'Share';
  return 'Post action';
}

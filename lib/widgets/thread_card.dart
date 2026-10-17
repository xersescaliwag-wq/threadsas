import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/formatters.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/models/poll.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/screens/profile/profile_screen.dart';
import 'package:threads/screens/search/topic_screen.dart';
import 'package:threads/screens/thread/thread_detail_screen.dart';
import 'package:threads/widgets/avatar.dart';
import 'package:threads/widgets/link_preview_card.dart';
import 'package:threads/widgets/media_grid.dart';
import 'package:threads/widgets/poll_view.dart';
import 'package:threads/widgets/quote_card.dart';
import 'package:threads/widgets/rich_content.dart';
import 'package:threads/widgets/thread_action_row.dart';
import 'package:threads/widgets/thread_menu.dart';

class ThreadCard extends ConsumerStatefulWidget {
  const ThreadCard({
    super.key,
    required this.post,
    required this.onChanged,
    this.onDeleted,
    this.opensOnTap = true,
  });
  final ThreadPost post;
  final ValueChanged<ThreadPost> onChanged;
  final VoidCallback? onDeleted;
  final bool opensOnTap;

  @override
  ConsumerState<ThreadCard> createState() => _ThreadCardState();
}

class _ThreadCardState extends ConsumerState<ThreadCard> {
  late ThreadPost _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void didUpdateWidget(ThreadCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new object from the parent means the server has newer data.
    if (!identical(oldWidget.post, widget.post)) _post = widget.post;
  }

  /// Shows a change at once, then tells the parent.
  void _update(ThreadPost updated) {
    setState(() => _post = updated);
    widget.onChanged(updated);
  }

  Future<void> _vote(String optionId) async {
    final poll = _post.poll;
    if (poll == null || poll.hasVoted || !poll.isOpen) return;
    final before = _post;
    final options = [
      for (final option in poll.options)
        if (option.id == optionId)
          PollOption(
            id: option.id,
            label: option.label,
            position: option.position,
            votesCount: option.votesCount + 1,
          )
        else
          option,
    ];
    _update(_post.copyWith(poll: poll.copyWith(options: options, myOptionId: optionId)));
    try {
      await ref.read(threadRepositoryProvider).votePoll(_post.id, optionId);
    } catch (error) {
      if (!mounted) return;
      _update(before); // roll back the optimistic vote
      await showError(context, error);
    }
  }

  Future<void> _openMention(String username) async {
    final profile = await ref.read(profileRepositoryProvider).getByUsername(username);
    if (!mounted) return;
    if (profile == null) {
      await showMessage(context, 'Profile not found', '@$username is not on Threads.');
      return;
    }
    await openScreen<void>(context, ProfileScreen(userId: profile.id));
  }

  void _openTopic(String tag) => openScreen<void>(context, TopicScreen(tag: tag));
  void _openProfile() => openScreen<void>(context, ProfileScreen(userId: _post.author.id));
  void _openThread() {
    if (widget.opensOnTap) {
      openScreen<void>(context, ThreadDetailScreen(threadId: _post.id));
    }
  }

  String? _expiryNote(DateTime expiresAt) {
    final hours = expiresAt.difference(DateTime.now()).inHours;
    return hours < 1 ? 'Disappears in under an hour' : 'Disappears in ${hours}h';
  }

  Widget _note(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: CupertinoColors.secondaryLabel),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final me = ref.watch(currentUserIdProvider);
    final isMine = post.author.id == me;
    final edited = post.editedAt == null ? '' : ' · Edited';
    final expiresAt = post.expiresAt;
    final expiryNote = expiresAt == null ? null : _expiryNote(expiresAt);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openThread,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _openProfile,
              child: Avatar(name: post.author.name, url: post.author.avatarUrl, size: 40),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: _openProfile,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  post.author.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (post.author.isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  CupertinoIcons.checkmark_seal_fill,
                                  size: 15,
                                  color: CupertinoColors.activeBlue,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '@${post.author.username} · ${timeAgo(post.createdAt)}$edited',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel),
                        ),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(28, 28),
                        onPressed: () => showThreadMenu(
                          context,
                          ref: ref,
                          post: post,
                          isMine: isMine,
                          onChanged: _update,
                          onDeleted: widget.onDeleted,
                        ),
                        child: const Icon(
                          CupertinoIcons.ellipsis,
                          size: 20,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                  if (post.isPinned) _note(CupertinoIcons.pin_fill, 'Pinned'),
                  if (expiryNote != null) _note(CupertinoIcons.clock, expiryNote),
                  if (post.content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    RichContent(
                      text: post.content,
                      onHashtag: _openTopic,
                      onMention: _openMention,
                    ),
                  ],
                  LinkPreviewCard(text: post.content),
                  if (post.mediaUrls.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    MediaGrid(urls: post.mediaUrls, kinds: post.mediaKinds),
                  ],
                  if (post.quoted != null) ...[
                    const SizedBox(height: 10),
                    QuoteCard(
                      post: post.quoted!,
                      onTap: () => openScreen<void>(
                        context,
                        ThreadDetailScreen(threadId: post.quoted!.id),
                      ),
                    ),
                  ],
                  if (post.poll != null) ...[
                    const SizedBox(height: 10),
                    PollView(poll: post.poll!, onVote: _vote),
                  ],
                  const SizedBox(height: 6),
                  ThreadActionRow(post: post, onChanged: _update),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
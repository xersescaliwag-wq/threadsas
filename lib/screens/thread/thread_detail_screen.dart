// lib/screens/thread/thread_detail_screen.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/config.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/providers/post_state_provider.dart';
import 'package:threads/providers/thread_providers.dart';
import 'package:threads/widgets/thread_card.dart';

class ThreadDetailScreen extends ConsumerStatefulWidget {
  const ThreadDetailScreen({super.key, required this.threadId});
  final String threadId;

  @override
  ConsumerState<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends ConsumerState<ThreadDetailScreen> {
  // Local copies made by cards (likes, votes, edits), kept until the next reload.
  final Map<String, ThreadPost> _edits = {};
  final Set<String> _removed = {};

  ThreadPost _current(ThreadPost post) => _edits[post.id] ?? post;

  void _changed(ThreadPost updated) {
    setState(() => _edits[updated.id] = updated);
  }

  void _reload() {
    _edits.clear();
    _removed.clear();
    ref.invalidate(threadDetailProvider(widget.threadId));
  }

  Future<void> _refresh() async {
    // A pull to refresh asks the server for the truth, so the shared copies of
    // posts the user reacted to elsewhere are out of date now.
    ref.read(postStateProvider.notifier).clear();
    _reload();
    await ref.read(threadDetailProvider(widget.threadId).future);
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(threadDetailProvider(widget.threadId));
    final focus = detail.value?.focus;
    final rootId = focus?.rootId ?? focus?.id ?? widget.threadId;
    // Realtime: a new reply, like or repost reloads the page. The first event only reports
    // the current state, so reloading on it costs one extra request and nothing else.
    ref.listen(liveConversationProvider(rootId), (previous, next) => _reload());
    ref.listen(liveThreadProvider(widget.threadId), (previous, next) => _reload());
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Thread'),
      body: detail.when<Widget>(
        loading: () => const Center(child: AppSpinner()),
        error: (error, _) => Center(child: Text(friendlyError(error))),
        data: (data) => data == null
            ? const Center(child: Text('This thread is no longer available.'))
            : _buildThread(data),
      ),
    );
  }

  Widget _buildThread(ThreadDetail detail) {
    final focus = _current(detail.focus);
    return Column(
      children: [
        Expanded(
          child: AppRefreshView(
            onRefresh: _refresh,
            slivers: [
              SliverList(
                delegate: SliverChildListDelegate([
                  for (final ancestor in detail.ancestors)
                    ThreadCard(
                      key: ValueKey('above-${ancestor.id}'),
                      post: _current(ancestor),
                      onChanged: _changed,
                    ),
                  ThreadCard(
                    key: ValueKey('focus-${focus.id}'),
                    post: focus,
                    onChanged: _changed,
                    onDeleted: () => Navigator.of(context).pop(),
                    opensOnTap: false,
                  ),
                  Container(height: 0.5, color: context.colors.separator),
                  ..._replyTree(detail),
                ]),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
        _QuickReply(parentId: focus.id, onPosted: _refresh),
      ],
    );
  }

  /// Replies in nested order. Each reply is followed by its own replies, indented one step deeper.
  List<Widget> _replyTree(ThreadDetail detail) {
    final childrenOf = <String, List<ThreadPost>>{};
    for (final reply in detail.replies) {
      final parent = reply.parentId;
      if (parent != null) {
        childrenOf.putIfAbsent(parent, () => []).add(reply);
      }
    }
    final rows = <Widget>[];
    void addChildren(String parentId, int depth) {
      for (final reply in childrenOf[parentId] ?? const <ThreadPost>[]) {
        if (_removed.contains(reply.id)) continue;
        final post = _current(reply);
        rows.add(
          Padding(
            padding: EdgeInsets.only(left: 16.0 * (depth > 4 ? 4 : depth)),
            child: Column(
              children: [
                ThreadCard(
                  key: ValueKey(post.id),
                  post: post,
                  onChanged: _changed,
                  onDeleted: () => setState(() => _removed.add(post.id)),
                ),
                Container(height: 0.5, color: context.colors.separator),
              ],
            ),
          ),
        );
        addChildren(reply.id, depth + 1);
      }
    }

    addChildren(detail.focus.id, 0);
    return rows;
  }
}

/// The reply box at the bottom of the thread. It posts a reply to the thread on screen.
class _QuickReply extends ConsumerStatefulWidget {
  const _QuickReply({required this.parentId, required this.onPosted});
  final String parentId;
  final Future<void> Function() onPosted;

  @override
  ConsumerState<_QuickReply> createState() => _QuickReplyState();
}

class _QuickReplyState extends ConsumerState<_QuickReply> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(threadRepositoryProvider).createThread(
            content: text,
            parentId: widget.parentId,
          );
      _controller.clear();
      await widget.onPosted();
    } catch (error) {
      if (mounted) await showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: context.colors.systemBackground,
          border: Border(
            top: BorderSide(color: context.colors.separator, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AdaptiveTextField(
                controller: _controller,
                placeholder: 'Reply to this thread',
                minLines: 1,
                maxLines: 4,
                maxLength: maxThreadLength,
              ),
            ),
            const SizedBox(width: 8),
            AdaptiveButton.child(
              padding: EdgeInsets.zero,
              onPressed: _busy ? null : _send,
              child: Icon(AppIcons.arrow_up_circle_fill, size: 32),
            ),
          ],
        ),
      ),
    );
  }
}

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
import 'package:threads/widgets/avatar.dart';

/// Horizontal center of the avatar inside a ThreadCard. The connector line is
/// drawn at this x. Adjust it to match your ThreadCard's left padding + avatar radius.
const double _railX = 36;

/// Distance from the top of a ThreadCard to just under its avatar.
const double _railTop = 58;

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
  // Replies whose nested replies the user chose to show.
  final Set<String> _expanded = {};
  bool _reloadQueued = false;

  ThreadPost _current(ThreadPost post) => _edits[post.id] ?? post;

  void _changed(ThreadPost updated) {
    setState(() => _edits[updated.id] = updated);
  }

  void _reloadNow() {
    _edits.clear();
    _removed.clear();
    ref.invalidate(threadDetailProvider(widget.threadId));
  }

  void _scheduleReload() {
    if (_reloadQueued) return;
    _reloadQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadQueued = false;
      if (mounted) _reloadNow();
    });
  }

  Future<void> _refresh() async {
    // A pull to refresh asks the server for the truth, so the shared copies of
    // posts the user reacted to elsewhere are out of date now.
    ref.read(postStateProvider.notifier).clear();
    _reloadNow();
    await ref.read(threadDetailProvider(widget.threadId).future);
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(threadDetailProvider(widget.threadId));
    final focus = detail.value?.focus;
    final rootId = focus?.rootId ?? focus?.id ?? widget.threadId;
    // Realtime: a new reply, like or repost reloads the page. The first event only reports
    // the current state, so reloading on it costs one extra request and nothing else.
    ref.listen(
      liveConversationProvider(rootId),
      (previous, next) => _scheduleReload(),
    );
    ref.listen(
      liveThreadProvider(widget.threadId),
      (previous, next) => _scheduleReload(),
    );
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Thread'),
      body: detail.when<Widget>(
        loading: () => const _ThreadSkeletonList(),
        error: (error, _) => Center(child: Text(friendlyError(error))),
        data: (data) => data == null
            ? const Center(child: Text('This thread is no longer available.'))
            : ResponsiveContent(child: _buildThread(data)),
      ),
    );
  }

  Widget _divider(BuildContext context) =>
      Container(height: 0.5, color: context.colors.separator);

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
                  // Ancestors, joined to the next post by a vertical thread line.
                  for (final ancestor in detail.ancestors)
                    Stack(
                      children: [
                        ThreadCard(
                          key: ValueKey('above-${ancestor.id}'),
                          post: _current(ancestor),
                          onChanged: _changed,
                        ),
                        Positioned(
                          left: _railX - 1,
                          top: _railTop,
                          bottom: 0,
                          width: 2,
                          child: ColoredBox(color: context.colors.separator),
                        ),
                      ],
                    ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ThreadCard(
                      key: ValueKey('focus-${focus.id}'),
                      post: focus,
                      onChanged: _changed,
                      onDeleted: () => Navigator.of(context).pop(),
                      opensOnTap: false,
                      disableComment: true,
                    ),
                  ),
                  _divider(context),
                  if (detail.replies.isNotEmpty)
                    _RepliesHeader(count: detail.replies.length),
                  ..._replyTree(detail),
                ]),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
        _ReplyComposer(parentId: focus.id, onPosted: _refresh),
      ],
    );
  }

  /// Replies as threaded branches. Top-level replies are separated by a hairline.
  /// Nested replies hang off a thread line, and deeper levels collapse behind
  /// a "View N more replies" row.
  List<Widget> _replyTree(ThreadDetail detail) {
    final childrenOf = <String, List<ThreadPost>>{};
    for (final reply in detail.replies) {
      final parent = reply.parentId;
      if (parent != null) {
        childrenOf.putIfAbsent(parent, () => []).add(reply);
      }
    }

    List<ThreadPost> visibleKids(String id) => [
      for (final c in childrenOf[id] ?? const <ThreadPost>[])
        if (!_removed.contains(c.id)) c,
    ];

    int countBelow(String id) {
      var n = 0;
      for (final c in visibleKids(id)) {
        n += 1 + countBelow(c.id);
      }
      return n;
    }

    Widget node(ThreadPost reply, int depth) {
      final post = _current(reply);
      final kids = visibleKids(reply.id);
      final collapsed =
          depth >= 1 && kids.isNotEmpty && !_expanded.contains(reply.id);
      final nested = [for (final k in kids) node(k, depth + 1)];
      return Column(
        children: [
          ThreadCard(
            key: ValueKey(post.id),
            post: post,
            onChanged: _changed,
            onDeleted: () => setState(() => _removed.add(post.id)),
            compact: true,
          ),
          if (collapsed)
            _MoreReplies(
              count: countBelow(reply.id),
              onTap: () => setState(() => _expanded.add(reply.id)),
            )
          else if (kids.isNotEmpty)
            _Branch(deep: depth >= 3, children: nested),
        ],
      );
    }

    final rows = <Widget>[];
    for (final reply in visibleKids(detail.focus.id)) {
      rows.add(node(reply, 0));
      rows.add(_divider(context));
    }
    return rows;
  }
}

class _ThreadSkeletonList extends StatelessWidget {
  const _ThreadSkeletonList();

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.zero,
    children: [for (var i = 0; i < 7; i++) const _ThreadSkeletonPost()],
  );
}

class _ThreadSkeletonPost extends StatelessWidget {
  const _ThreadSkeletonPost();

  @override
  Widget build(BuildContext context) {
    final color = context.colors.systemGrey6;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ThreadSkeletonBlock(width: 52, height: 52, radius: 26, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ThreadSkeletonBlock(width: 136, height: 16, color: color),
                    const SizedBox(width: 10),
                    _ThreadSkeletonBlock(width: 78, height: 14, color: color),
                  ],
                ),
                const SizedBox(height: 14),
                _ThreadSkeletonBlock(
                  width: double.infinity,
                  height: 16,
                  color: color,
                ),
                const SizedBox(height: 10),
                FractionallySizedBox(
                  widthFactor: .72,
                  child: _ThreadSkeletonBlock(
                    width: double.infinity,
                    height: 16,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadSkeletonBlock extends StatefulWidget {
  const _ThreadSkeletonBlock({
    required this.width,
    required this.height,
    required this.color,
    this.radius = 2,
  });
  final double width;
  final double height;
  final double radius;

  final Color color;

  @override
  State<_ThreadSkeletonBlock> createState() => _ThreadSkeletonBlockState();
}

class _ThreadSkeletonBlockState extends State<_ThreadSkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final position = -1.5 + (_controller.value * 3);
      final highlight = Color.lerp(widget.color, CupertinoColors.white, .16)!;
      return ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(position, 0),
          end: Alignment(position + 1, 0),
          colors: [
            widget.color,
            widget.color,
            highlight,
            widget.color,
            widget.color,
          ],
          stops: const [0, .32, .5, .68, 1],
        ).createShader(bounds),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
    },
  );
}

class _RepliesHeader extends StatelessWidget {
  const _RepliesHeader({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Text(
        'Replies · $count',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.colors.secondaryLabel,
        ),
      ),
    );
  }
}

/// Nested replies hanging off a vertical thread line under the parent's avatar.
class _Branch extends StatelessWidget {
  const _Branch({required this.children, required this.deep});
  final List<Widget> children;
  final bool deep;

  @override
  Widget build(BuildContext context) {
    final column = Column(children: children);
    // Past a few levels the line stops stepping right, so the content keeps its width.
    if (deep) return column;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: _railX - 1),
          Container(width: 2, color: context.colors.separator),
          const SizedBox(width: 2),
          Expanded(child: column),
        ],
      ),
    );
  }
}

class _MoreReplies extends StatelessWidget {
  const _MoreReplies({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_railX + 14, 4, 18, 12),
        child: Text(
          count == 1 ? 'View 1 more reply' : 'View $count more replies',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.colors.secondaryLabel,
          ),
        ),
      ),
    );
  }
}

/// Inline reply row under the post. It posts a reply to the thread on screen.
class _ReplyComposer extends ConsumerStatefulWidget {
  const _ReplyComposer({required this.parentId, required this.onPosted});
  final String parentId;
  final Future<void> Function() onPosted;

  @override
  ConsumerState<_ReplyComposer> createState() => _ReplyComposerState();
}

class _ReplyComposerState extends ConsumerState<_ReplyComposer> {
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
    if (text.length > maxThreadLength) {
      await showMessage(
        context,
        'Reply too long',
        'Replies can be up to $maxThreadLength characters.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(threadRepositoryProvider)
          .createThread(content: text, parentId: widget.parentId);
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
    final userId = ref.watch(currentUserIdProvider);
    final profile = userId == null
        ? null
        : ref.watch(profileByIdProvider(userId)).value;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 12, 14),
        decoration: BoxDecoration(
          color: context.colors.systemBackground,
          border: Border(
            top: BorderSide(color: context.colors.separator, width: .5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 44,
              height: 50,
              child: Center(
                child: Avatar(
                  name: profile?.name ?? 'You',
                  url: profile?.avatarUrl,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: AdaptiveTextField(
                  controller: _controller,
                  placeholder: 'Reply to this thread',
                  minLines: 1,
                  maxLines: 3,
                  cupertinoDecoration: BoxDecoration(
                    color: context.colors.systemBackground,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: context.colors.separator,
                      width: .5,
                    ),
                  ),
                  decoration: appFilledInputDecoration(
                    hintText: 'Reply to this thread',
                    fillColor: context.colors.systemBackground,
                    borderColor: context.colors.separator,
                    focusedBorderColor: context.colors.activeBlue,
                    radius: 5,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            // Like Threads, the Post button only appears once there is text.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                if (!hasText && !_busy) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: SizedBox(
                    height: 48,
                    child: AdaptiveButton.child(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      onPressed: _busy ? null : _send,
                      child: Text(
                        _busy ? 'Posting...' : 'Post',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: CupertinoColors.black,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

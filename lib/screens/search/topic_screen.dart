// lib/screens/search/topic_screen.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/providers/social_providers.dart';
import 'package:threads/providers/thread_providers.dart';
import 'package:threads/widgets/thread_card.dart';
const _pageSize = 20;
class TopicScreen extends ConsumerStatefulWidget {
  const TopicScreen({super.key, required this.tag});
  final String tag;
  @override
  ConsumerState<TopicScreen> createState() => _TopicScreenState();
}
class _TopicScreenState extends ConsumerState<TopicScreen> {
  final Map<String, ThreadPost> _edits = {};
  final Set<String> _gone = {};
  final List<ThreadPost> _more = [];
  bool _endReached = false;
  bool _loadingMore = false;
  ThreadPost _current(ThreadPost post) => _edits[post.id] ?? post;
  void _changed(ThreadPost post) => setState(() => _edits[post.id] = post);
  Future<void> _refresh() async {
    setState(() {
      _more.clear();
      _gone.clear();
      _edits.clear();
      _endReached = false;
    });
    ref.invalidate(topicProvider(widget.tag));
    await ref.read(topicProvider(widget.tag).future);
  }
  /// Each page starts after the oldest post on screen.
  Future<void> _loadMore(List<ThreadPost> all) async {
    if (_loadingMore || _endReached || all.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(threadRepositoryProvider).fetchTopic(
            widget.tag,
            before: all.last.createdAt,
          );
      if (!mounted) return;
      setState(() {
        _more.addAll(page);
        if (page.length < _pageSize) _endReached = true;
      });
    } catch (error) {
      if (mounted) await showError(context, error);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final first = ref.watch(topicProvider(widget.tag));
    final muted = ref.watch(mutedIdsProvider).value ?? const <String>{};
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: '#${widget.tag}'),
      body: first.when<Widget>(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (error, _) => Center(child: Text(friendlyError(error))),
        data: (page) {
          final all = [...page, ..._more];
          final posts = all
              .where((post) => !muted.contains(post.author.id) && !_gone.contains(post.id))
              .toList();
          final hasMore = !_endReached && page.length >= _pageSize;
          return CustomScrollView(
            slivers: [
              CupertinoSliverRefreshControl(onRefresh: _refresh),
              if (posts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No threads use #${widget.tag} yet.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: CupertinoColors.secondaryLabel),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildListDelegate([
                    for (final post in posts)
                      Column(
                        key: ValueKey(post.id),
                        children: [
                          ThreadCard(
                            post: _current(post),
                            onChanged: _changed,
                            onDeleted: () => setState(() => _gone.add(post.id)),
                          ),
                          Container(height: 0.5, margin: const EdgeInsets.only(left: 68), color: CupertinoColors.separator),
                        ],
                      ),
                    if (hasMore)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: _loadingMore
                              ? const CupertinoActivityIndicator()
                              : CupertinoButton(
                                  onPressed: () => _loadMore(all),
                                  child: const Text('Load more'),
                                ),
                        ),
                      ),
                  ]),
                ),
            ],
          );
        },
      ),
    );
  }
}

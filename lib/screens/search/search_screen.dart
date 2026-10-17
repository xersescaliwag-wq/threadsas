// lib/screens/search/search_screen.dart
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/models/profile.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/models/topic_hit.dart';
import 'package:threads/providers/search_providers.dart';
import 'package:threads/providers/social_providers.dart';
import 'package:threads/screens/search/topic_screen.dart';
import 'package:threads/widgets/profile_row.dart';
import 'package:threads/widgets/thread_card.dart';
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}
class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final Set<String> _gone = {};
  Timer? _debounce;
  String _query = '';
  int _mode = 0; // 0 People, 1 Threads, 2 Topics
  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }
  /// Waits for a pause in typing, so each key press does not run a query.
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }
  void _onSubmitted(String value) {
    _debounce?.cancel();
    setState(() => _query = value.trim());
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: CupertinoSearchTextField(
            controller: _controller,
            placeholder: 'Search',
            onChanged: _onChanged,
            onSubmitted: _onSubmitted,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: CupertinoSlidingSegmentedControl<int>(
            groupValue: _mode,
            children: const {0: Text('People'), 1: Text('Threads'), 2: Text('Topics')},
            onValueChanged: (value) {
              if (value != null) setState(() => _mode = value);
            },
          ),
        ),
        Expanded(child: _results()),
      ],
    );
  }
  Widget _results() {
    if (_mode == 2) return _topics(_query);
    if (_query.isEmpty) {
      return _message(_mode == 0 ? 'Search for people by name or username.' : 'Search the text of threads.');
    }
    return _mode == 0 ? _people(_query) : _threads(_query);
  }
  Widget _message(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: CupertinoColors.secondaryLabel),
        ),
      ),
    );
  }
  /// One list with a spinner, an error message, an empty message and dividers.
  Widget _list<T>(
    AsyncValue<List<T>> value, {
    required String empty,
    required double indent,
    required Widget Function(T item) row,
  }) {
    return value.when<Widget>(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => _message(friendlyError(error)),
      data: (items) {
        if (items.isEmpty) return _message(empty);
        return ListView.builder(
          padding: EdgeInsets.zero,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: items.length,
          itemBuilder: (context, index) => Column(
            children: [
              row(items[index]),
              Container(height: 0.5, margin: EdgeInsets.only(left: indent), color: CupertinoColors.separator),
            ],
          ),
        );
      },
    );
  }
  Widget _people(String query) {
    return _list<Profile>(
      ref.watch(searchPeopleProvider(query)),
      empty: 'No people found.',
      indent: 72,
      row: (person) => ProfileRow(profile: person),
    );
  }
  Widget _threads(String query) {
    final muted = ref.watch(mutedIdsProvider).value ?? const <String>{};
    final results = ref.watch(searchThreadsProvider(query)).whenData(
          (posts) => [
            for (final post in posts)
              if (!muted.contains(post.author.id) && !_gone.contains(post.id)) post,
          ],
        );
    return _list<ThreadPost>(
      results,
      empty: 'No threads found.',
      indent: 68,
      // The card keeps its own copy after a like or a vote, so nothing to store.
      row: (post) => ThreadCard(
        key: ValueKey(post.id),
        post: post,
        onChanged: (_) {},
        onDeleted: () => setState(() => _gone.add(post.id)),
      ),
    );
  }
  Widget _topics(String query) {
    final list = _list<TopicHit>(
      ref.watch(searchTopicsProvider(query)),
      empty: query.isEmpty ? 'No topics yet.' : 'No topics start with that text.',
      indent: 16,
      row: (hit) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openScreen<void>(context, TopicScreen(tag: hit.tag)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text('#${hit.tag}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              Text(
                '${hit.uses} ${hit.uses == 1 ? 'thread' : 'threads'}',
                style: const TextStyle(color: CupertinoColors.secondaryLabel),
              ),
              const SizedBox(width: 6),
              const Icon(CupertinoIcons.chevron_forward, size: 16, color: CupertinoColors.secondaryLabel),
            ],
          ),
        ),
      ),
    );
    if (query.isNotEmpty) return list;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Popular topics',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CupertinoColors.secondaryLabel),
          ),
        ),
        Expanded(child: list),
      ],
    );
  }
}

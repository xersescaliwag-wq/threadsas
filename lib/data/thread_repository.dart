// lib/data/thread_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:threads/core/json.dart';
import 'package:threads/models/poll.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/models/topic_hit.dart';
class ThreadRepository {
  ThreadRepository(this._client);
  final SupabaseClient _client;
  String get _me => _client.auth.currentUser!.id;
  /// Every thread query uses this select. It joins the author, the quoted post and the poll.
  static const _threadSelect =
      '*, '
      'author:profiles!threads_author_id_fkey(id, username, display_name, bio, avatar_url, is_private, is_verified), '
      'quoted:threads!threads_quote_id_fkey(*, author:profiles!threads_author_id_fkey(id, username, display_name, avatar_url, is_private, is_verified)), '
      'poll:polls(ends_at), '
      'poll_options(id, label, position, votes_count)';
  // ---------- Feeds ----------
  /// Top-level posts from everyone the signed-in user can see.
  Future<List<ThreadPost>> fetchForYou({DateTime? before}) {
    return _topLevel(before: before);
  }
  /// Top-level posts from accounts the user follows, plus the user's own posts.
  Future<List<ThreadPost>> fetchFollowing({DateTime? before}) async {
    final followed = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', _me)
        .eq('status', 'accepted');
    final authorIds = [
      _me,
      ...followed.map((row) => row['following_id'] as String),
    ];
    return _topLevel(before: before, authorIds: authorIds);
  }
  /// Top-level posts that use a hashtag, for a topic page.
  Future<List<ThreadPost>> fetchTopic(String tag, {DateTime? before}) {
    return _topLevel(before: before, hashtag: tag.toLowerCase());
  }
  /// Top-level posts inside one community, for its own feed (Step 21.5).
  Future<List<ThreadPost>> fetchCommunity(String communityId, {DateTime? before}) {
    return _topLevel(before: before, communityId: communityId);
  }
  Future<List<ThreadPost>> _topLevel({
    DateTime? before,
    List<String>? authorIds,
    String? hashtag,
    String? communityId,
  }) async {
    var query = _client.from('threads').select(_threadSelect).isFilter('parent_id', null);
    // A community's posts live only in that community's feed, and normal feeds
    // never show them.
    if (communityId != null) {
      query = query.eq('community_id', communityId);
    } else {
      query = query.isFilter('community_id', null);
    }
    if (authorIds != null) query = query.inFilter('author_id', authorIds);
    if (hashtag != null) query = query.contains('hashtags', [hashtag]);
    if (before != null) query = query.lt('created_at', before.toUtc().toIso8601String());
    final rows = await query.order('created_at', ascending: false).limit(20);
    return _hydrate(rows);
  }
  // ---------- Profile tabs ----------
  /// One profile tab: 'threads', 'replies' or 'reposts'. Pinned posts are fetched separately.
  Future<List<ThreadPost>> fetchByAuthor(
    String authorId, {
    required String tab,
    DateTime? before,
  }) async {
    if (tab == 'reposts') return _repostsBy(authorId, before: before);
    var query = _client.from('threads').select(_threadSelect).eq('author_id', authorId);
    if (tab == 'replies') {
      query = query.not('parent_id', 'is', null);
    } else {
      query = query.isFilter('parent_id', null).eq('is_pinned', false);
    }
    if (before != null) query = query.lt('created_at', before.toUtc().toIso8601String());
    final rows = await query.order('created_at', ascending: false).limit(20);
    return _hydrate(rows);
  }
  Future<ThreadPost?> fetchPinned(String authorId) async {
    final row = await _client
        .from('threads')
        .select(_threadSelect)
        .eq('author_id', authorId)
        .eq('is_pinned', true)
        .maybeSingle();
    if (row == null) return null;
    return (await _hydrate([row])).single;
  }
  Future<List<ThreadPost>> _repostsBy(String userId, {DateTime? before}) async {
    var query = _client
        .from('reposts')
        .select('created_at, thread:threads($_threadSelect)')
        .eq('user_id', userId);
    if (before != null) query = query.lt('created_at', before.toUtc().toIso8601String());
    final rows = await query.order('created_at', ascending: false).limit(20);
    final threads = rows.map((row) => row['thread']).whereType<Map<String, dynamic>>().toList();
    return _hydrate(threads);
  }
  // ---------- Thread detail ----------
  /// The post, the posts above it, and every reply under it at any depth.
  Future<ThreadDetail?> fetchDetail(String threadId) async {
    final focusRow = await _client
        .from('threads')
        .select(_threadSelect)
        .eq('id', threadId)
        .maybeSingle();
    if (focusRow == null) return null;
    final focus = (await _hydrate([focusRow])).single;
    // Walk up the parent chain to the top of the conversation.
    final ancestors = <ThreadPost>[];
    var parentId = focus.parentId;
    while (parentId != null && ancestors.length < 30) {
      final parentRow = await _client
          .from('threads')
          .select(_threadSelect)
          .eq('id', parentId)
          .maybeSingle();
      if (parentRow == null) break;
      final parent = (await _hydrate([parentRow])).single;
      ancestors.insert(0, parent);
      parentId = parent.parentId;
    }
    // Load every reply in the conversation, then keep the ones that sit under the focused post.
    final conversationRoot = focus.rootId ?? focus.id;
    final rows = await _client
        .from('threads')
        .select(_threadSelect)
        .eq('root_id', conversationRoot)
        .order('created_at', ascending: true)
        .limit(500);
    final everyReply = await _hydrate(rows);
    final underFocus = <String>{focus.id};
    var added = true;
    while (added) {
      added = false;
      for (final post in everyReply) {
        final parent = post.parentId;
        if (parent != null && underFocus.contains(parent) && underFocus.add(post.id)) {
          added = true;
        }
      }
    }
    final replies = everyReply
        .where((post) => post.id != focus.id && underFocus.contains(post.id))
        .toList();
    return ThreadDetail(focus: focus, ancestors: ancestors, replies: replies);
  }
  // ---------- Writes ----------
  /// Creates a post, a reply or a quote. A poll is created after the post. If the poll fails, the post is removed.
  Future<ThreadPost> createThread({
    required String content,
    List<String> mediaUrls = const [],
    List<String> mediaKinds = const [],
    String? parentId,
    String? quoteId,
    String? communityId,
    ReplyControl replyControl = ReplyControl.everyone,
    bool hideLikeCount = false,
    DateTime? expiresAt,
    PollDraft? poll,
  }) async {
    final inserted = await _client
        .from('threads')
        .insert({
          'author_id': _me,
          'content': content.trim(),
          'media_urls': mediaUrls,
          'media_kinds': mediaKinds,
          'parent_id': parentId,
          'quote_id': quoteId,
          'community_id': communityId,
          'reply_control': replyControl.value,
          'hide_like_count': hideLikeCount,
          'expires_at': expiresAt?.toUtc().toIso8601String(),
        })
        .select('id')
        .single();
    final threadId = inserted['id'] as String;
    if (poll != null) {
      try {
        await _createPoll(threadId, poll);
      } catch (_) {
        await _client.from('threads').delete().eq('id', threadId);
        rethrow;
      }
    }
    final row = await _client.from('threads').select(_threadSelect).eq('id', threadId).single();
    return (await _hydrate([row])).single;
  }
  Future<void> _createPoll(String threadId, PollDraft draft) async {
    await _client.from('polls').insert({
      'thread_id': threadId,
      'ends_at': DateTime.now().add(draft.duration).toUtc().toIso8601String(),
    });
    await _client.from('poll_options').insert([
      for (var i = 0; i < draft.options.length; i++)
        {'thread_id': threadId, 'label': draft.options[i].trim(), 'position': i},
    ]);
  }
  /// Edits the text or settings of your own post. Hashtags and mentions are recalculated by the database.
  Future<void> updateThread(
    String threadId, {
    String? content,
    ReplyControl? replyControl,
    bool? hideLikeCount,
  }) async {
    final changes = <String, Object?>{
      if (content != null) 'content': content.trim(),
      if (replyControl != null) 'reply_control': replyControl.value,
      if (hideLikeCount != null) 'hide_like_count': hideLikeCount,
    };
    if (changes.isEmpty) return;
    await _client.from('threads').update(changes).eq('id', threadId);
  }
  Future<void> setPinned(String threadId, bool pinned) async {
    await _client.from('threads').update({'is_pinned': pinned}).eq('id', threadId);
  }
  Future<void> deleteThread(String threadId) async {
    await _client.from('threads').delete().eq('id', threadId);
  }
  Future<void> like(String threadId) async {
    await _client.from('likes').insert({'thread_id': threadId, 'user_id': _me});
  }
  Future<void> unlike(String threadId) async {
    await _client.from('likes').delete().eq('thread_id', threadId).eq('user_id', _me);
  }
  Future<void> repost(String threadId) async {
    await _client.from('reposts').insert({'thread_id': threadId, 'user_id': _me});
  }
  Future<void> undoRepost(String threadId) async {
    await _client.from('reposts').delete().eq('thread_id', threadId).eq('user_id', _me);
  }
  Future<void> votePoll(String threadId, String optionId) async {
    await _client.from('poll_votes').insert({
      'thread_id': threadId,
      'option_id': optionId,
      'user_id': _me,
    });
  }
  // ---------- Search ----------
  /// Full-text search. The search_threads function returns matching ids, then the normal select runs, so visibility rules still apply.
  Future<List<ThreadPost>> searchThreads(String query) async {
    final text = query.trim();
    if (text.isEmpty) return [];
    final matches = await _client.rpc('search_threads', params: {'q': text});
    final ids = (matches as List)
        .map((row) => (row as Map<String, dynamic>)['id'] as String)
        .toList();
    if (ids.isEmpty) return [];
    final rows = await _client
        .from('threads')
        .select(_threadSelect)
        .inFilter('id', ids)
        .order('created_at', ascending: false);
    return _hydrate(rows);
  }
  /// Topics that start with the typed text. An empty query lists the most used.
  Future<List<TopicHit>> searchTopics(String query) async {
    final rows = await _client.rpc('search_topics', params: {'q': query.trim()});
    return (rows as List).map((row) {
      final map = row as Map<String, dynamic>;
      return TopicHit(tag: map['tag'] as String, uses: asInt(map['uses']));
    }).toList();
  }
  // ---------- Helpers ----------
  /// Turns rows into posts and adds the signed-in user's likes, reposts and poll votes.
  Future<List<ThreadPost>> _hydrate(List<Map<String, dynamic>> rows) async {
    final posts = rows.map((row) => ThreadPost.fromJson(row)).toList();
    if (posts.isEmpty) return posts;
    final ids = posts.map((post) => post.id).toList();
    final likedRows = await _client
        .from('likes')
        .select('thread_id')
        .eq('user_id', _me)
        .inFilter('thread_id', ids);
    final repostedRows = await _client
        .from('reposts')
        .select('thread_id')
        .eq('user_id', _me)
        .inFilter('thread_id', ids);
    final likedIds = likedRows.map((row) => row['thread_id'] as String).toSet();
    final repostedIds = repostedRows.map((row) => row['thread_id'] as String).toSet();
    final pollIds = posts.where((post) => post.poll != null).map((post) => post.id).toList();
    final myVotes = <String, String>{};
    if (pollIds.isNotEmpty) {
      final voteRows = await _client
          .from('poll_votes')
          .select('thread_id, option_id')
          .eq('user_id', _me)
          .inFilter('thread_id', pollIds);
      for (final row in voteRows) {
        myVotes[row['thread_id'] as String] = row['option_id'] as String;
      }
    }
    return posts
        .map(
          (post) => post.copyWith(
            likedByMe: likedIds.contains(post.id),
            repostedByMe: repostedIds.contains(post.id),
            poll: post.poll?.copyWith(myOptionId: myVotes[post.id]),
          ),
        )
        .toList();
  }
}

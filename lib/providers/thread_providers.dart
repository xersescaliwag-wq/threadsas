// lib/providers/thread_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/providers/core_providers.dart';
/// A thread page: the post, the posts above it and the replies under it.
final threadDetailProvider = FutureProvider.family<ThreadDetail?, String>((ref, threadId) {
  return ref.watch(threadRepositoryProvider).fetchDetail(threadId);
});
/// One profile tab. The key is a record of (user id, tab name).
final profileTabProvider = FutureProvider.family<List<ThreadPost>, (String, String)>((ref, key) {
  final (userId, tab) = key;
  return ref.watch(threadRepositoryProvider).fetchByAuthor(userId, tab: tab);
});
final pinnedThreadProvider = FutureProvider.family<ThreadPost?, String>((ref, userId) {
  return ref.watch(threadRepositoryProvider).fetchPinned(userId);
});
final topicProvider = FutureProvider.family<List<ThreadPost>, String>((ref, tag) {
  return ref.watch(threadRepositoryProvider).fetchTopic(tag);
});
/// Live changes to the replies in one conversation, keyed by the conversation root id.
final liveConversationProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, rootId) {
  return ref
      .watch(supabaseClientProvider)
      .from('threads')
      .stream(primaryKey: ['id'])
      .eq('root_id', rootId);
});
/// Live changes to one thread, such as its like count.
final liveThreadProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, threadId) {
  return ref
      .watch(supabaseClientProvider)
      .from('threads')
      .stream(primaryKey: ['id'])
      .eq('id', threadId);
});

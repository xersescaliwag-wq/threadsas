// lib/providers/search_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/models/profile.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/models/topic_hit.dart';
import 'package:threads/providers/core_providers.dart';
final searchPeopleProvider = FutureProvider.autoDispose.family<List<Profile>, String>((ref, query) {
  return ref.watch(profileRepositoryProvider).search(query);
});
final searchThreadsProvider = FutureProvider.autoDispose.family<List<ThreadPost>, String>((ref, query) {
  return ref.watch(threadRepositoryProvider).searchThreads(query);
});
final searchTopicsProvider = FutureProvider.autoDispose.family<List<TopicHit>, String>((ref, query) {
  return ref.watch(threadRepositoryProvider).searchTopics(query);
});

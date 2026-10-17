// lib/providers/social_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/data/social_repository.dart';
import 'package:threads/models/profile.dart';
import 'package:threads/providers/core_providers.dart';
final followStateProvider = FutureProvider.family<FollowState, String>((ref, targetId) {
  ref.watch(currentUserIdProvider);
  return ref.watch(socialRepositoryProvider).followState(targetId);
});
final mutedIdsProvider = FutureProvider<Set<String>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(socialRepositoryProvider).mutedIds();
});
final followersProvider = FutureProvider.family<List<Profile>, String>((ref, userId) {
  return ref.watch(socialRepositoryProvider).followers(userId);
});
final followingListProvider = FutureProvider.family<List<Profile>, String>((ref, userId) {
  return ref.watch(socialRepositoryProvider).following(userId);
});
final followRequestsProvider = FutureProvider<List<Profile>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(socialRepositoryProvider).followRequests();
});
final blockedProfilesProvider = FutureProvider<List<Profile>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(socialRepositoryProvider).blockedProfiles();
});
final mutedProfilesProvider = FutureProvider<List<Profile>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(socialRepositoryProvider).mutedProfiles();
});

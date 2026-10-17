// lib/providers/notification_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/models/app_notification.dart';
import 'package:threads/providers/core_providers.dart';
final activityProvider = FutureProvider<List<AppNotification>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(notificationRepositoryProvider).list();
});
final unreadCountProvider = FutureProvider<int>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(notificationRepositoryProvider).unreadCount();
});
/// Stays alive while the app shell is on screen. The shell listens to it and refreshes the activity list and the badge on each event.
final notificationLiveProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.empty();
  return ref.watch(notificationRepositoryProvider).liveChanges();
});

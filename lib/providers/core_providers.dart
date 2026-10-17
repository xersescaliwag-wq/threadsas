// lib/providers/core_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:threads/data/auth_repository.dart';
import 'package:threads/data/community_repository.dart';
import 'package:threads/data/gif_repository.dart';
import 'package:threads/data/link_preview_repository.dart';
import 'package:threads/data/media_repository.dart';
import 'package:threads/data/notification_repository.dart';
import 'package:threads/data/profile_repository.dart';
import 'package:threads/data/social_repository.dart';
import 'package:threads/data/thread_repository.dart';
import 'package:threads/models/profile.dart';
final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);
final threadRepositoryProvider = Provider<ThreadRepository>(
  (ref) => ThreadRepository(ref.watch(supabaseClientProvider)),
);
final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(ref.watch(supabaseClientProvider)),
);
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(supabaseClientProvider)),
);
final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => MediaRepository(ref.watch(supabaseClientProvider)),
);
final linkPreviewRepositoryProvider = Provider<LinkPreviewRepository>(
  (ref) => LinkPreviewRepository(ref.watch(supabaseClientProvider)),
);
final gifRepositoryProvider = Provider<GifRepository>(
  (ref) => GifRepository(ref.watch(supabaseClientProvider)),
);
final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(ref.watch(supabaseClientProvider)),
);
/// Emits on every sign-in, sign-out and token refresh.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseClientProvider).auth.onAuthStateChange,
);
/// The signed-in user's id, or null. Providers that depend on the user watch this, so they reload after sign-in or sign-out.
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser?.id;
});
final myProfileProvider = FutureProvider<Profile?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Future.value(null);
  return ref.watch(profileRepositoryProvider).getById(userId);
});
final profileByIdProvider = FutureProvider.family<Profile?, String>((ref, id) {
  return ref.watch(profileRepositoryProvider).getById(id);
});

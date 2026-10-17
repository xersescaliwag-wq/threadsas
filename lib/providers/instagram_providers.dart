// lib/providers/instagram_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/models/instagram_account.dart';
import 'package:threads/providers/core_providers.dart';

/// The signed-in user's connected Instagram account, or null.
///
/// The Instagram screen invalidates it after connecting, disconnecting, and
/// when the app returns from the browser, so the composer's switch appears as
/// soon as the account is linked.
final instagramAccountProvider = FutureProvider<InstagramAccount?>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(instagramRepositoryProvider).fetchAccount();
});

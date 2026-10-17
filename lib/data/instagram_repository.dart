// lib/data/instagram_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:threads/models/instagram_account.dart';

/// A short, readable reason why an Instagram action did not work.
class InstagramException implements Exception {
  InstagramException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reads the Instagram connection and calls the two Step 21.6 Edge Functions.
///
/// Meta's app secret and the account's access token stay on the server: they
/// live in the functions' environment and in Supabase Vault. The app only ever
/// learns *that* an account is connected.
class InstagramRepository {
  InstagramRepository(this._client);

  final SupabaseClient _client;

  static const _fields =
      'user_id, ig_user_id, page_id, username, token_expires_at, connected_at';

  /// The signed-in user's connected account, or null. Row level security keeps
  /// this to the owner, and the token column is not granted, so nothing secret
  /// can come back.
  Future<InstagramAccount?> fetchAccount() async {
    final row = await _client
        .from('instagram_accounts')
        .select(_fields)
        .maybeSingle();
    if (row == null) return null;
    return InstagramAccount.fromJson(row);
  }

  /// Returns the Meta consent URL for the caller to open in a browser.
  Future<String> beginConnect() async {
    try {
      final response = await _client.functions.invoke(
        'instagram-oauth',
        body: {'action': 'start'},
      );
      final data = response.data;
      final url = data is Map ? data['url'] : null;
      if (url is String && url.isNotEmpty) return url;
      throw InstagramException('Instagram did not return a sign-in page.');
    } on FunctionException catch (error) {
      throw InstagramException(_message(error));
    }
  }

  /// Forgets the connection and removes the token from Vault.
  Future<void> disconnect() async {
    try {
      await _client.functions.invoke(
        'instagram-oauth',
        body: {'action': 'disconnect'},
      );
    } on FunctionException catch (error) {
      throw InstagramException(_message(error));
    }
  }

  /// Shares one thread to Instagram. Throws [InstagramException] with the
  /// reason when the copy fails, so the composer can tell the user which copy
  /// failed without blocking the Threads post.
  Future<void> publish(String threadId) async {
    try {
      await _client.functions.invoke(
        'instagram-publish',
        body: {'thread_id': threadId},
      );
    } on FunctionException catch (error) {
      throw InstagramException(_message(error));
    }
  }

  /// Removes the Instagram copy of a thread, if there is one. Returns a note to
  /// show the user, or null when there is nothing to say. It never throws: a
  /// failed cleanup must not stop the thread from being deleted.
  Future<String?> deleteCopy(String threadId) async {
    try {
      // Only call the function when a copy was actually recorded, and do it
      // before the thread is deleted (the link row goes with it by cascade).
      final row = await _client
          .from('instagram_posts')
          .select('thread_id')
          .eq('thread_id', threadId)
          .maybeSingle();
      if (row == null) return null;

      final response = await _client.functions.invoke(
        'instagram-publish',
        body: {'thread_id': threadId, 'action': 'delete'},
      );
      final data = response.data;
      if (data is Map && data['ok'] == false) {
        final note = data['note'];
        if (note is String && note.isNotEmpty) return note;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// The functions send { "error": "..." }; show that when it is there.
  String _message(FunctionException error) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (error.status == 401) return 'Sign in again.';
    if (error.status == 500) return 'Instagram is not set up yet.';
    return 'Instagram did not work. Try again.';
  }
}

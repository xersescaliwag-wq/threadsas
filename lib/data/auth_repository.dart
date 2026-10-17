// lib/data/auth_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;
  Future<bool> isUsernameAvailable(String username) async {
    final available = await _client.rpc(
      'is_username_available',
      params: {'candidate': username.trim().toLowerCase()},
    );
    return available as bool;
  }
  /// Returns true when Supabase is waiting for the user to confirm their email address.
  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'username': username.trim().toLowerCase(),
        'display_name': displayName.trim(),
      },
    );
    return response.session == null;
  }
  Future<void> logIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email.trim(), password: password);
  }
  /// Emails a sign-in link. The link opens the app through the threads:// scheme.
  Future<void> sendSignInLink(String email) async {
    await _client.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: 'threads://login-callback',
    );
  }
  Future<void> logOut() async {
    await _client.auth.signOut();
  }
  /// Deletes the account. The database removes the profile and all content by cascade.
  Future<void> deleteAccount() async {
    await _client.rpc('delete_my_account');
    await _client.auth.signOut();
  }
}

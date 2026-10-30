// lib/data/auth_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _passwordRecoveryPendingKey = 'password_recovery_pending';

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
  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }
  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'threads://login-callback',
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_passwordRecoveryPendingKey, true);
  }

  static Future<bool> takePendingPasswordRecovery() async {
    final preferences = await SharedPreferences.getInstance();
    final pending = preferences.getBool(_passwordRecoveryPendingKey) ?? false;
    if (pending) await preferences.remove(_passwordRecoveryPendingKey);
    return pending;
  }
  Future<void> requestPasswordCode(String email) async {
    final response = await _client.functions.invoke(
      'request-password-code',
      body: {'email': email.trim().toLowerCase()},
    );
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
  }
  Future<String> verifyPasswordCode({required String email, required String code}) async {
    final response = await _client.functions.invoke(
      'verify-password-code',
      body: {'email': email.trim().toLowerCase(), 'code': code.trim()},
    );
    final data = response.data;
    if (data is! Map || data['verification_token'] is! String) {
      throw Exception(data is Map ? (data['error'] ?? 'The code could not be verified.') : 'The code could not be verified.');
    }
    return data['verification_token'] as String;
  }
  Future<void> completePasswordReset({required String email, required String verificationToken, required String password}) async {
    final response = await _client.functions.invoke(
      'complete-password-reset',
      body: {
        'email': email.trim().toLowerCase(),
        'verification_token': verificationToken,
        'password': password,
      },
    );
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
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

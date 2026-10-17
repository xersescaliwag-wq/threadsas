// lib/models/instagram_account.dart
import 'package:threads/core/json.dart';

/// One connected Instagram account, matching a row in instagram_accounts.
///
/// The access token is deliberately not part of this model: it lives in
/// Supabase Vault and only the Edge Functions can read it.
class InstagramAccount {
  const InstagramAccount({
    required this.userId,
    required this.igUserId,
    this.pageId,
    this.username,
    this.expiresAt,
    required this.connectedAt,
  });

  final String userId;
  final String igUserId;
  final String? pageId;

  /// The Instagram handle, when Meta returned one.
  final String? username;

  /// When the token expires, or null when it does not.
  final DateTime? expiresAt;

  final DateTime connectedAt;

  factory InstagramAccount.fromJson(Map<String, dynamic> json) {
    return InstagramAccount(
      userId: json['user_id'] as String,
      igUserId: json['ig_user_id'] as String,
      pageId: json['page_id'] as String?,
      username: json['username'] as String?,
      expiresAt: asDate(json['token_expires_at']),
      connectedAt: asDate(json['connected_at'])!,
    );
  }
}

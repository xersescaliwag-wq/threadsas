// lib/data/profile_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:threads/models/profile.dart';
class ProfileRepository {
  ProfileRepository(this._client);
  final SupabaseClient _client;
  static const profileColumns =
      'id, username, display_name, bio, website, avatar_url, is_private, is_verified, '
      'followers_count, following_count, threads_count';
  Future<Profile?> getById(String id) async {
    final row = await _client
        .from('profiles')
        .select(profileColumns)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }
  Future<Profile?> getByUsername(String username) async {
    final row = await _client
        .from('profiles')
        .select(profileColumns)
        .eq('username', username.trim().toLowerCase())
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }
  Future<void> updateProfile({
    required String userId,
    required String username,
    required String displayName,
    required String bio,
    required String website,
    required bool isPrivate,
    String? avatarUrl,
  }) async {
    await _client
        .from('profiles')
        .update({
          'username': username.trim().toLowerCase(),
          'display_name': displayName.trim(),
          'bio': bio.trim(),
          'website': website.trim().isEmpty ? null : website.trim(),
          'is_private': isPrivate,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        })
        .eq('id', userId);
  }
  /// Finds people by username or display name. Symbols are removed so they cannot break the filter.
  Future<List<Profile>> search(String query) async {
    final cleaned = query.replaceAll(RegExp(r'[^A-Za-z0-9_. ]'), '').trim();
    if (cleaned.isEmpty) return [];
    final rows = await _client
        .from('profiles')
        .select(profileColumns)
        .or('username.ilike.%$cleaned%,display_name.ilike.%$cleaned%')
        .limit(25);
    return rows.map((row) => Profile.fromJson(row)).toList();
  }
}

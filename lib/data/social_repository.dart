// lib/data/social_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:threads/models/profile.dart';
/// Whether the signed-in user follows someone, or has asked to.
enum FollowState { none, following, requested }
class SocialRepository {
  SocialRepository(this._client);
  final SupabaseClient _client;
  String get _me => _client.auth.currentUser!.id;
  static const _profileFields =
      'id, username, display_name, bio, avatar_url, is_private, is_verified, '
      'followers_count, following_count, threads_count';
  Future<FollowState> followState(String targetId) async {
    final row = await _client
        .from('follows')
        .select('status')
        .eq('follower_id', _me)
        .eq('following_id', targetId)
        .maybeSingle();
    if (row == null) return FollowState.none;
    return row['status'] == 'accepted' ? FollowState.following : FollowState.requested;
  }
  /// The trigger from Step 2 sets the status: accepted for public accounts, pending for private ones.
  Future<void> follow(String targetId) async {
    await _client.from('follows').insert({'follower_id': _me, 'following_id': targetId});
  }
  Future<void> unfollow(String targetId) async {
    await _client.from('follows').delete().eq('follower_id', _me).eq('following_id', targetId);
  }
  Future<List<Profile>> followers(String userId) async {
    final rows = await _client
        .from('follows')
        .select('follower:profiles!follows_follower_id_fkey($_profileFields)')
        .eq('following_id', userId)
        .eq('status', 'accepted')
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map((row) => Profile.fromJson(row['follower'] as Map<String, dynamic>)).toList();
  }
  Future<List<Profile>> following(String userId) async {
    final rows = await _client
        .from('follows')
        .select('following:profiles!follows_following_id_fkey($_profileFields)')
        .eq('follower_id', userId)
        .eq('status', 'accepted')
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map((row) => Profile.fromJson(row['following'] as Map<String, dynamic>)).toList();
  }
  Future<List<Profile>> followRequests() async {
    final rows = await _client
        .from('follows')
        .select('follower:profiles!follows_follower_id_fkey($_profileFields)')
        .eq('following_id', _me)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return rows.map((row) => Profile.fromJson(row['follower'] as Map<String, dynamic>)).toList();
  }
  Future<void> acceptRequest(String followerId) async {
    await _client
        .from('follows')
        .update({'status': 'accepted'})
        .eq('follower_id', followerId)
        .eq('following_id', _me);
  }
  Future<void> declineRequest(String followerId) async {
    await _client.from('follows').delete().eq('follower_id', followerId).eq('following_id', _me);
  }
  Future<void> block(String targetId) async {
    await _client.from('blocks').insert({'blocker_id': _me, 'blocked_id': targetId});
  }
  Future<void> unblock(String targetId) async {
    await _client.from('blocks').delete().eq('blocker_id', _me).eq('blocked_id', targetId);
  }
  Future<List<Profile>> blockedProfiles() async {
    final rows = await _client
        .from('blocks')
        .select('blocked:profiles!blocks_blocked_id_fkey($_profileFields)')
        .eq('blocker_id', _me);
    return rows.map((row) => Profile.fromJson(row['blocked'] as Map<String, dynamic>)).toList();
  }
  Future<void> mute(String targetId) async {
    await _client.from('mutes').insert({'muter_id': _me, 'muted_id': targetId});
  }
  Future<void> unmute(String targetId) async {
    await _client.from('mutes').delete().eq('muter_id', _me).eq('muted_id', targetId);
  }
  Future<List<Profile>> mutedProfiles() async {
    final rows = await _client
        .from('mutes')
        .select('muted:profiles!mutes_muted_id_fkey($_profileFields)')
        .eq('muter_id', _me);
    return rows.map((row) => Profile.fromJson(row['muted'] as Map<String, dynamic>)).toList();
  }
  /// The ids that feeds hide. A set makes each lookup fast.
  Future<Set<String>> mutedIds() async {
    final rows = await _client.from('mutes').select('muted_id').eq('muter_id', _me);
    return rows.map((row) => row['muted_id'] as String).toSet();
  }
  Future<void> reportThread(String threadId, String reason) async {
    await _client.from('reports').insert({
      'reporter_id': _me,
      'thread_id': threadId,
      'reason': reason.trim(),
    });
  }
  Future<void> reportProfile(String profileId, String reason) async {
    await _client.from('reports').insert({
      'reporter_id': _me,
      'profile_id': profileId,
      'reason': reason.trim(),
    });
  }
}

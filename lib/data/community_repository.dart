// lib/data/community_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:threads/models/community.dart';

/// Reads and writes communities and their membership rows. What comes back is
/// already limited by the row level security policies on those tables.
class CommunityRepository {
  CommunityRepository(this._client);

  final SupabaseClient _client;

  String get _me => _client.auth.currentUser!.id;

  static const _fields =
      'id, owner_id, slug, name, description, is_private, member_count, '
      'created_at';

  /// Every community the signed-in user can see: the public ones, plus any
  /// private one they belong to. The busiest come first.
  Future<List<Community>> fetchAll() async {
    final rows = await _client
        .from('communities')
        .select(_fields)
        .order('member_count', ascending: false)
        .limit(100);
    return _attachMembership(rows);
  }

  /// The communities the signed-in user has joined. The composer's picker uses
  /// this list.
  Future<List<Community>> fetchMine() async {
    final rows = await _client
        .from('community_members')
        .select('community:communities($_fields)')
        .eq('user_id', _me);
    final communities = rows
        .map((row) => row['community'])
        .whereType<Map<String, dynamic>>()
        .map((json) => Community.fromJson(json, joinedByMe: true))
        .toList();
    communities.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return communities;
  }

  /// One community, by id.
  Future<Community> fetchById(String id) async {
    final row = await _client
        .from('communities')
        .select(_fields)
        .eq('id', id)
        .single();
    final one = await _attachMembership([row]);
    return one.single;
  }

  /// Creates a community. The creator becomes its owner, and a database trigger
  /// adds them as a member, so the returned community is already joined.
  Future<Community> create({
    required String name,
    required String slug,
    required String description,
    required bool isPrivate,
  }) async {
    final row = await _client
        .from('communities')
        .insert({
          'owner_id': _me,
          'name': name.trim(),
          'slug': slug.trim().toLowerCase(),
          'description': description.trim(),
          'is_private': isPrivate,
        })
        .select(_fields)
        .single();
    return Community.fromJson(row, joinedByMe: true);
  }

  /// Joins a community as the signed-in user.
  Future<void> join(String communityId) async {
    await _client.from('community_members').insert({
      'community_id': communityId,
      'user_id': _me,
    });
  }

  /// Leaves a community, or removes someone else when you own it.
  Future<void> leave(String communityId) async {
    await _client
        .from('community_members')
        .delete()
        .eq('community_id', communityId)
        .eq('user_id', _me);
  }

  /// Adds the logged-in user's membership flag to each row using one extra
  /// query, so the list can draw the right button.
  Future<List<Community>> _attachMembership(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((row) => row['id'] as String).toList();
    final myRows = await _client
        .from('community_members')
        .select('community_id')
        .eq('user_id', _me)
        .inFilter('community_id', ids);
    final joined = myRows.map((row) => row['community_id'] as String).toSet();
    return rows
        .map(
          (row) => Community.fromJson(
            row,
            joinedByMe: joined.contains(row['id']),
          ),
        )
        .toList();
  }
}

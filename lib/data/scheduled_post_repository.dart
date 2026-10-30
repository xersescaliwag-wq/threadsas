import 'package:supabase_flutter/supabase_flutter.dart';

class ScheduledPostRepository {
  ScheduledPostRepository(this._client);
  final SupabaseClient _client;
  String get _me => _client.auth.currentUser!.id;

  Future<void> create({required String content, DateTime? scheduledFor}) async {
    await _client.from('scheduled_posts').insert({
      'owner_id': _me,
      'content': content,
      'scheduled_for': (scheduledFor ?? DateTime.now().add(const Duration(hours: 1))).toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> list() async {
    final rows = await _client.from('scheduled_posts')
        .select('id, content, scheduled_for, status, error_message')
        .eq('owner_id', _me)
        .order('scheduled_for');
    return rows;
  }

  Future<void> cancel(String id) async {
    await _client.from('scheduled_posts').update({'status': 'cancelled'}).eq('id', id).eq('owner_id', _me);
  }
}

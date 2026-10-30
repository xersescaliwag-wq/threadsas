import 'package:supabase_flutter/supabase_flutter.dart';

class PersonalizationRepository {
  PersonalizationRepository(this._client);
  final SupabaseClient _client;
  String get _me => _client.auth.currentUser!.id;

  Future<List<String>> interests() async {
    final rows = await _client.from('user_interests').select('topic').eq('user_id', _me).order('topic');
    return rows.map((row) => row['topic'] as String).toList();
  }
  Future<List<String>> mutedTopics() async {
    final rows = await _client.from('muted_topics').select('topic').eq('user_id', _me).order('topic');
    return rows.map((row) => row['topic'] as String).toList();
  }
  Future<void> setInterest(String topic, bool enabled) async {
    final value = topic.trim().toLowerCase();
    if (value.isEmpty) return;
    if (enabled) {
      await _client.from('user_interests').upsert({'user_id': _me, 'topic': value});
    } else {
      await _client.from('user_interests').delete().eq('user_id', _me).eq('topic', value);
    }
  }
  Future<void> setMutedTopic(String topic, bool enabled) async {
    final value = topic.trim().toLowerCase();
    if (value.isEmpty) return;
    if (enabled) {
      await _client.from('muted_topics').upsert({'user_id': _me, 'topic': value});
    } else {
      await _client.from('muted_topics').delete().eq('user_id', _me).eq('topic', value);
    }
  }
}

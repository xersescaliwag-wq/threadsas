import 'package:supabase_flutter/supabase_flutter.dart';

class DraftRepository {
  DraftRepository(this._client);
  final SupabaseClient _client;

  String get _me => _client.auth.currentUser!.id;

  Future<void> save({
    required String content,
    required List<String> mediaUrls,
    required List<String> mediaKinds,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _client.from('post_drafts').insert({
      'owner_id': _me,
      'content': content,
      'media_urls': mediaUrls,
      'media_kinds': mediaKinds,
      'metadata': metadata,
    });
  }

  Future<List<Map<String, dynamic>>> list() async {
    final rows = await _client
        .from('post_drafts')
        .select('id, content, media_urls, media_kinds, metadata, updated_at')
        .eq('owner_id', _me)
        .order('updated_at', ascending: false);
    return rows;
  }

  Future<void> delete(String id) async {
    await _client.from('post_drafts').delete().eq('id', id).eq('owner_id', _me);
  }
}

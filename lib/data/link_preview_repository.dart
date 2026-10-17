// lib/data/link_preview_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:threads/models/link_preview.dart';

/// Asks the link-preview Edge Function for a page's title, description and
/// image (Step 21.4). The server does the fetching and caches the result, so
/// the app never contacts the linked page directly.
class LinkPreviewRepository {
  LinkPreviewRepository(this._client);
  final SupabaseClient _client;

  /// Returns null when the page has nothing to show, is not allowed, or cannot
  /// be reached. A preview is a nicety, so failures stay quiet.
  Future<LinkPreview?> fetch(String url) async {
    try {
      final response = await _client.functions.invoke(
        'link-preview',
        body: {'url': url},
      );
      final data = response.data;
      if (data is! Map) return null;
      final preview = LinkPreview.fromJson(Map<String, dynamic>.from(data));
      return preview.isEmpty ? null : preview;
    } catch (_) {
      // A missing function, a rejected link or a network error all just mean
      // "no preview" for this post.
      return null;
    }
  }
}

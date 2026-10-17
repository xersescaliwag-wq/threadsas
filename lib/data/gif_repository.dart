// lib/data/gif_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:threads/models/gif_result.dart';

/// A short, readable reason why GIF search did not work.
class GifSearchException implements Exception {
  GifSearchException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Searches for GIFs through the gif-search Edge Function (Step 21.3). The
/// provider key lives only on the server, so the app never holds it.
class GifRepository {
  GifRepository(this._client);
  final SupabaseClient _client;

  /// An empty query returns the provider's trending GIFs.
  Future<List<GifResult>> search(String query) async {
    try {
      final response = await _client.functions.invoke(
        'gif-search',
        body: {'query': query.trim()},
      );
      final data = response.data;
      final raw = data is Map ? data['results'] : null;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((item) => GifResult.fromJson(Map<String, dynamic>.from(item)))
          .where((gif) => gif.previewUrl.isNotEmpty && gif.fullUrl.isNotEmpty)
          .toList();
    } on FunctionException catch (error) {
      throw GifSearchException(_message(error));
    } catch (_) {
      throw GifSearchException(
        'Could not reach GIF search. Check your connection.',
      );
    }
  }

  /// The function sends { "error": "..." }; show that when it is there.
  String _message(FunctionException error) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (error.status == 401) return 'Sign in to search for GIFs.';
    if (error.status == 500) return 'GIF search is not set up yet.';
    return 'GIF search failed. Try again.';
  }
}

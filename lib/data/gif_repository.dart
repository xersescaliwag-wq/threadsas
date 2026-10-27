// lib/data/gif_repository.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:threads/core/config.dart';
import 'package:threads/models/gif_result.dart';

/// A short, readable reason why GIF search did not work.
class GifSearchException implements Exception {
  GifSearchException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Searches GIPHY directly from the client, as required by GIPHY's Search API.
/// A persistent HTTP client reuses connections, and repeated searches are kept
/// in a small in-memory cache for the lifetime of the app session.
class GifRepository {
  GifRepository({http.Client? client}) : _client = client ?? http.Client();

  static const _resultLimit = 16;
  static const _maxCachedQueries = 20;
  static const _timeout = Duration(seconds: 8);

  final http.Client _client;
  final Map<String, List<GifResult>> _cache = {};

  /// An empty query returns trending GIFs.
  Future<List<GifResult>> search(String query) async {
    final trimmed = query.trim();
    final normalized = trimmed.length > 50 ? trimmed.substring(0, 50) : trimmed;
    final cacheKey = normalized.toLowerCase();
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final endpoint = normalized.isEmpty ? 'trending' : 'search';
    final parameters = <String, String>{
      'api_key': giphyApiKey,
      'limit': '$_resultLimit',
      'rating': 'pg-13',
      // Only return the renditions used by the picker and selected post.
      'fields': [
        'id',
        'images.fixed_width_downsampled',
        'images.fixed_width',
        'images.downsized',
        'images.original',
      ].join(','),
      if (normalized.isNotEmpty) 'q': normalized,
    };
    final uri = Uri.https('api.giphy.com', '/v1/gifs/$endpoint', parameters);

    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        throw GifSearchException('GIF search failed. Try again.');
      }

      final body = jsonDecode(response.body);
      final rawResults = body is Map<String, dynamic> ? body['data'] : null;
      if (rawResults is! List) return const [];

      final results = rawResults
          .whereType<Map>()
          .map(_fromGiphy)
          .whereType<GifResult>()
          .toList(growable: false);
      _cache[cacheKey] = results;
      if (_cache.length > _maxCachedQueries) {
        _cache.remove(_cache.keys.first);
      }
      return results;
    } on GifSearchException {
      rethrow;
    } on TimeoutException {
      throw GifSearchException('GIF search timed out. Try again.');
    } catch (_) {
      throw GifSearchException(
        'Could not reach GIF search. Check your connection.',
      );
    }
  }

  GifResult? _fromGiphy(Map<dynamic, dynamic> raw) {
    final item = Map<String, dynamic>.from(raw);
    final images = item['images'];
    if (images is! Map) return null;

    final preview = _firstRendition(images, const [
      'fixed_width_downsampled',
      'fixed_width',
      'downsized',
      'original',
    ]);
    final full = _firstRendition(images, const ['downsized', 'original']);
    if (preview == null || full == null) return null;

    // Animated WebP is much smaller and faster in the picker. Posts keep a
    // GIF URL for compatibility with the existing media pipeline.
    final previewUrl = _url(preview, const ['webp', 'url']);
    final fullUrl = _url(full, const ['url']);
    if (previewUrl.isEmpty || fullUrl.isEmpty) return null;

    return GifResult(
      id: item['id']?.toString() ?? '',
      previewUrl: previewUrl,
      fullUrl: fullUrl,
      width: int.tryParse(full['width']?.toString() ?? '') ?? 0,
      height: int.tryParse(full['height']?.toString() ?? '') ?? 0,
    );
  }

  Map<dynamic, dynamic>? _firstRendition(
    Map<dynamic, dynamic> images,
    List<String> names,
  ) {
    for (final name in names) {
      final rendition = images[name];
      if (rendition is Map &&
          _url(rendition, const ['webp', 'url']).isNotEmpty) {
        return rendition;
      }
    }
    return null;
  }

  String _url(Map<dynamic, dynamic> rendition, List<String> fields) {
    for (final field in fields) {
      final value = rendition[field]?.toString() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  void close() => _client.close();
}

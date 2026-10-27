// lib/data/music_repository.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:threads/models/music_track.dart';

class MusicSearchException implements Exception {
  MusicSearchException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Searches Audius for streamable music without copying audio into Supabase.
class MusicRepository {
  MusicRepository({http.Client? client}) : _client = client ?? http.Client();

  static const _timeout = Duration(seconds: 10);
  final http.Client _client;
  final Map<String, List<MusicTrack>> _cache = {};

  Future<List<MusicTrack>> search(String query) async {
    final text = query.trim();
    final cacheKey = text.toLowerCase();
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final path = text.isEmpty ? '/v1/tracks/trending' : '/v1/tracks/search';
    final uri = Uri.https('discoveryprovider.audius.co', path, {
      'app_name': 'ThreadsFlutter',
      'limit': '20',
      if (text.isNotEmpty) 'query': text,
    });

    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        throw MusicSearchException('Music search failed. Try again.');
      }
      final decoded = jsonDecode(response.body);
      final raw = decoded is Map<String, dynamic> ? decoded['data'] : null;
      if (raw is! List) return const [];
      final tracks = raw
          .whereType<Map>()
          .map((item) => MusicTrack.fromAudius(Map<String, dynamic>.from(item)))
          .where(
            (track) =>
                track.id.isNotEmpty &&
                track.title.isNotEmpty &&
                track.artist.isNotEmpty &&
                track.durationSeconds >= 30,
          )
          .toList(growable: false);
      _cache[cacheKey] = tracks;
      if (_cache.length > 20) _cache.remove(_cache.keys.first);
      return tracks;
    } on MusicSearchException {
      rethrow;
    } on TimeoutException {
      throw MusicSearchException('Music search timed out. Try again.');
    } catch (_) {
      throw MusicSearchException(
        'Could not load music. Check your connection.',
      );
    }
  }

  void close() => _client.close();
}

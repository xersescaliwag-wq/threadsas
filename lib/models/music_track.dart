// lib/models/music_track.dart

/// A streamable track attached to a thread as a 30-second music sticker.
class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.permalink,
    required this.durationSeconds,
    required this.clipStartSeconds,
  });

  final String id;
  final String title;
  final String artist;
  final String artworkUrl;
  final String permalink;
  final int durationSeconds;
  final int clipStartSeconds;

  String get streamUrl => Uri.https(
    'discoveryprovider.audius.co',
    '/v1/tracks/$id/stream',
    const {'app_name': 'ThreadsFlutter'},
  ).toString();

  MusicTrack copyWith({int? clipStartSeconds}) => MusicTrack(
    id: id,
    title: title,
    artist: artist,
    artworkUrl: artworkUrl,
    permalink: permalink,
    durationSeconds: durationSeconds,
    clipStartSeconds: clipStartSeconds ?? this.clipStartSeconds,
  );

  factory MusicTrack.fromAudius(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : const <String, dynamic>{};
    final artwork = json['artwork'] is Map
        ? Map<String, dynamic>.from(json['artwork'] as Map)
        : const <String, dynamic>{};
    final duration = (json['duration'] as num?)?.round() ?? 0;
    final suggestedStart =
        (json['preview_start_seconds'] as num?)?.round() ?? 0;
    final latestStart = duration > 30 ? duration - 30 : 0;
    return MusicTrack(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: user['name']?.toString() ?? '',
      artworkUrl:
          artwork['480x480']?.toString() ??
          artwork['1000x1000']?.toString() ??
          artwork['150x150']?.toString() ??
          '',
      permalink: json['permalink']?.toString() ?? '',
      durationSeconds: duration,
      clipStartSeconds: suggestedStart.clamp(0, latestStart),
    );
  }

  static MusicTrack? fromThreadJson(Map<String, dynamic> json) {
    final id = json['music_id'] as String?;
    if (id == null || id.isEmpty) return null;
    return MusicTrack(
      id: id,
      title: (json['music_title'] as String?) ?? '',
      artist: (json['music_artist'] as String?) ?? '',
      artworkUrl: (json['music_artwork_url'] as String?) ?? '',
      permalink: (json['music_permalink'] as String?) ?? '',
      durationSeconds: (json['music_duration_seconds'] as num?)?.round() ?? 30,
      clipStartSeconds:
          (json['music_clip_start_seconds'] as num?)?.round() ?? 0,
    );
  }

  Map<String, Object?> toThreadColumns() => {
    'music_id': id,
    'music_title': title,
    'music_artist': artist,
    'music_artwork_url': artworkUrl,
    'music_permalink': permalink,
    'music_duration_seconds': durationSeconds,
    'music_clip_start_seconds': clipStartSeconds,
  };
}

// lib/models/gif_result.dart

/// One GIF selected with the GIPHY SDK. The full URL is stored in media_urls.
class GifResult {
  const GifResult({
    required this.id,
    required this.previewUrl,
    required this.fullUrl,
    required this.width,
    required this.height,
  });

  final String id;
  final String previewUrl;
  final String fullUrl;
  final int width;
  final int height;

  factory GifResult.fromJson(Map<String, dynamic> json) {
    return GifResult(
      id: (json['id'] as String?) ?? '',
      previewUrl: (json['preview_url'] as String?) ?? '',
      fullUrl: (json['full_url'] as String?) ?? '',
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
    );
  }
}

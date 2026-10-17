// lib/models/link_preview.dart

/// The title, description and image the link-preview function read from a page.
class LinkPreview {
  const LinkPreview({
    required this.url,
    required this.title,
    required this.description,
    required this.imageUrl,
  });

  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;

  /// True when the page had nothing worth showing.
  bool get isEmpty =>
      (title == null || title!.isEmpty) &&
      (description == null || description!.isEmpty) &&
      imageUrl == null;

  factory LinkPreview.fromJson(Map<String, dynamic> json) {
    return LinkPreview(
      url: (json['url'] as String?) ?? '',
      title: json['title'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}

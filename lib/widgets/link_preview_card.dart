// lib/widgets/link_preview_card.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/links.dart';
import 'package:threads/providers/link_preview_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// The preview card for the first https link in a post (Step 21.4).
///
/// Shows nothing when the post has no link, while the preview is loading, or
/// when the page had no title, description or image to show. Tapping it opens
/// the link in the browser, as the inline link in the text does.
class LinkPreviewCard extends ConsumerWidget {
  const LinkPreviewCard({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = firstHttpsLink(text);
    if (url == null) return const SizedBox.shrink();
    final preview = ref.watch(linkPreviewProvider(url)).value;
    if (preview == null) return const SizedBox.shrink();
    final host = Uri.tryParse(url)?.host ?? url;
    final title = preview.title;
    final description = preview.description;
    final imageUrl = preview.imageUrl;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.separator, width: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        ColoredBox(color: context.colors.systemGrey5),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.secondaryLabel,
                      ),
                    ),
                    if (title != null && title.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.secondaryLabel,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

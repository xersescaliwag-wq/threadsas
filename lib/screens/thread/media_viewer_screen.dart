// lib/screens/thread/media_viewer_screen.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:threads/widgets/video_player_view.dart';

/// Full-screen view of one photo, video or GIF.
///
/// The grid from Step 9 keeps its still frames so scrolling stays smooth; this
/// page loads the video player only when a cell is tapped. A GIF is just an
/// image here: Flutter animates it on its own.
class MediaViewerScreen extends StatelessWidget {
  const MediaViewerScreen({super.key, required this.url, this.kind = 'image'});

  final String url;

  /// 'image', 'video' or 'gif' (Step 21.3).
  final String kind;

  bool get isVideo => kind == 'video';

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(title: ''),
      backgroundColor: CupertinoColors.black,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            isVideo
                ? VideoPlayerView(url: url)
                : Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      CupertinoIcons.exclamationmark_triangle,
                      size: 32,
                      color: CupertinoColors.white,
                    ),
                  ),
            if (kind == 'gif')
              const Positioned(
                left: 16,
                bottom: 16,
                child: _GifBadge(),
              ),
          ],
        ),
      ),
    );
  }
}

/// The small dark label on a full-screen GIF.
class _GifBadge extends StatelessWidget {
  const _GifBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text(
        'GIF',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.white,
        ),
      ),
    );
  }
}

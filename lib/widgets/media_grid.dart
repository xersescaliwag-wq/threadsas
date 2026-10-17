// lib/widgets/media_grid.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/screens/thread/media_viewer_screen.dart';

/// Up to four photos, videos or GIFs. A play symbol marks videos and a GIF
/// badge marks GIFs, and a count covers the rest. The grid keeps its still
/// frames so scrolling stays smooth; tapping a cell opens the full-screen
/// viewer, which loads the video player only when it is shown (Step 21.1).
class MediaGrid extends StatelessWidget {
  const MediaGrid({super.key, required this.urls, this.kinds = const []});
  final List<String> urls;

  /// Parallel to [urls], from threads.media_kinds (Step 21.3). Empty for posts
  /// made before GIFs existed; then the file extension decides.
  final List<String> kinds;

  String _kindAt(int index) {
    if (index < kinds.length && kinds[index].isNotEmpty) return kinds[index];
    final path = urls[index].toLowerCase().split('?').first;
    if (path.endsWith('.mp4') || path.endsWith('.mov')) return 'video';
    if (path.endsWith('.gif')) return 'gif';
    return 'image';
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    final shown = urls.take(4).toList();
    final hidden = urls.length - shown.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: shown.length == 1 ? 1 : 2,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          children: [
            for (var i = 0; i < shown.length; i++)
              GestureDetector(
                onTap: () => openScreen<void>(
                  context,
                  MediaViewerScreen(
                    url: shown[i],
                    kind: _kindAt(i),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      shown[i],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          ColoredBox(color: context.colors.systemGrey5),
                    ),
                    if (_kindAt(i) == 'video')
                      Center(
                        child: Icon(
                          AppIcons.play_circle_fill,
                          size: 44,
                          color: context.colors.white,
                        ),
                      ),
                    if (_kindAt(i) == 'gif')
                      const Positioned(
                        left: 6,
                        bottom: 6,
                        child: _KindBadge(label: 'GIF'),
                      ),
                    if (i == shown.length - 1 && hidden > 0)
                      Container(
                        color: const Color(0x99000000),
                        alignment: Alignment.center,
                        child: Text(
                          '+$hidden',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            color: context.colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The small dark label over a GIF cell.
class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: context.colors.white,
        ),
      ),
    );
  }
}

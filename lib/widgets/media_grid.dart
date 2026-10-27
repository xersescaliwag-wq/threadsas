// lib/widgets/media_grid.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/screens/thread/media_viewer_screen.dart';

/// Media shown in a horizontal scrollable strip for posts with multiple images.
/// Tapping a cell opens the full-screen viewer.
class MediaGrid extends StatelessWidget {
  const MediaGrid({super.key, required this.urls, this.kinds = const []});
  final List<String> urls;

  /// Parallel to [urls], from threads.media_kinds. Empty for posts made before
  /// GIFs existed; then the file extension decides.
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

    if (urls.length == 1) {
      final url = urls[0];
      final kind = _kindAt(0);
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 140,
          height: 140,
          child: GestureDetector(
            onTap: () => openScreen<void>(
              context,
              MediaViewerScreen(
                url: url,
                kind: kind,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      ColoredBox(color: context.colors.systemGrey5),
                ),
                if (kind == 'video')
                  Center(
                    child: Icon(
                      AppIcons.play_circle_fill,
                      size: 32,
                      color: context.colors.white,
                    ),
                  ),
                if (kind == 'gif')
                  const Positioned(
                    left: 6,
                    bottom: 6,
                    child: _KindBadge(label: 'GIF'),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final shown = urls.take(10).toList();
    final hidden = urls.length - shown.length;

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: shown.length,
        separatorBuilder: (context, index) => const SizedBox(width: 4),
        itemBuilder: (context, i) {
          final url = shown[i];
          final kind = _kindAt(i);
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 140,
              height: 140,
              child: GestureDetector(
                onTap: () => openScreen<void>(
                  context,
                  MediaViewerScreen(
                    url: url,
                    kind: kind,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          ColoredBox(color: context.colors.systemGrey5),
                    ),
                    if (kind == 'video')
                      Center(
                        child: Icon(
                          AppIcons.play_circle_fill,
                          size: 32,
                          color: context.colors.white,
                        ),
                      ),
                    if (kind == 'gif')
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
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: context.colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
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

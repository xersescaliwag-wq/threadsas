// lib/screens/compose/music_search_screen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/data/music_repository.dart';
import 'package:threads/models/music_track.dart';
import 'package:threads/providers/core_providers.dart';

class MusicSearchScreen extends ConsumerStatefulWidget {
  const MusicSearchScreen({super.key});

  @override
  ConsumerState<MusicSearchScreen> createState() => _MusicSearchScreenState();
}

class _MusicSearchScreenState extends ConsumerState<MusicSearchScreen> {
  final _controller = TextEditingController();
  final _player = AudioPlayer();
  Timer? _debounce;
  Timer? _clipTimer;
  List<MusicTrack> _results = const [];
  String _lastQuery = '';
  String? _playingId;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    });
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _clipTimer?.cancel();
    _controller.dispose();
    _player.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    final text = query.trim();
    _lastQuery = text;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref.read(musicRepositoryProvider).search(text);
      if (!mounted || _lastQuery != text) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } on MusicSearchException catch (error) {
      if (!mounted || _lastQuery != text) return;
      setState(() {
        _results = const [];
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _togglePreview(MusicTrack track) async {
    if (_playingId == track.id) {
      _clipTimer?.cancel();
      await _player.pause();
      if (mounted) setState(() => _playingId = null);
      return;
    }

    if (mounted) setState(() => _playingId = track.id);
    try {
      _clipTimer?.cancel();
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);

      debugPrint('MusicSearch: previewing ${track.streamUrl}');
      await _player.stop();
      await _player.setUrl(track.streamUrl);
      await _player.seek(Duration(seconds: track.clipStartSeconds));
      await _player.play();

      _clipTimer = Timer(const Duration(seconds: 60), () async {
        await _player.pause();
        if (mounted) setState(() => _playingId = null);
      });
    } catch (e, s) {
      debugPrint('MusicSearch preview failed: $e');
      debugPrint('$s');
      if (mounted) {
        setState(() {
          _playingId = null;
          _error = 'This track could not be previewed.';
        });
      }
    }
  }

  Future<void> _choose(MusicTrack track) async {
    _clipTimer?.cancel();
    await _player.pause();
    if (!mounted) return;
    setState(() => _playingId = null);
    Navigator.of(
      context,
    ).pop(track.copyWith(clipStartSeconds: track.clipStartSeconds));
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(title: 'Add music'),
      body: ResponsiveContent(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: AppSearchField(
                  controller: _controller,
                  placeholder: 'Search songs or artists',
                  onChanged: _onChanged,
                  onSubmitted: _search,
                  autofocus: false,
                ),
              ),
              Expanded(child: _body()),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Music powered by Audius',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.secondaryLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _results.isEmpty) {
      return ListView.builder(
        itemCount: 9,
        itemBuilder: (context, index) => const _MusicLoadingRow(),
      );
    }
    final error = _error;
    if (error != null && _results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.secondaryLabel),
              ),
              const SizedBox(height: 14),
              AdaptiveButton.child(
                onPressed: () => _search(_lastQuery),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No songs found',
          style: TextStyle(color: context.colors.secondaryLabel),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (context, index) => Container(
        height: .5,
        margin: const EdgeInsets.only(left: 82),
        color: context.colors.separator,
      ),
      itemBuilder: (context, index) {
        final track = _results[index];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _choose(track),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: track.artworkUrl.isEmpty
                      ? ColoredBox(
                          color: context.colors.systemGrey5,
                          child: SizedBox.square(
                            dimension: 56,
                            child: Icon(AppIcons.music_note),
                          ),
                        )
                      : Image.network(
                          track.artworkUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              ColoredBox(
                                color: context.colors.systemGrey5,
                                child: SizedBox.square(
                                  dimension: 56,
                                  child: Icon(AppIcons.music_note),
                                ),
                              ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _togglePreview(track),
                  child: SizedBox.square(
                    dimension: 44,
                    child: Icon(
                      _playingId == track.id
                          ? AppIcons.pause_fill
                          : AppIcons.play_fill,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MusicLoadingRow extends StatefulWidget {
  const _MusicLoadingRow();
  @override
  State<_MusicLoadingRow> createState() => _MusicLoadingRowState();
}

class _MusicLoadingRowState extends State<_MusicLoadingRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final block = context.colors.systemGrey5;
    final highlight = Color.lerp(block, CupertinoColors.white, .16)!;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final position = -1.5 + (_controller.value * 3);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(position, 0),
            end: Alignment(position + 1, 0),
            colors: [block, block, highlight, block, block],
            stops: const [0, .32, .5, .68, 1],
          ).createShader(bounds),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(width: 56, height: 56, color: block),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 150, height: 14, color: block),
                      const SizedBox(height: 8),
                      Container(width: 90, height: 12, color: block),
                    ],
                  ),
                ),
                Container(width: 28, height: 28, color: block),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MusicClipEditorScreen extends StatefulWidget {
  const MusicClipEditorScreen({super.key, required this.track});

  final MusicTrack track;

  @override
  State<MusicClipEditorScreen> createState() => _MusicClipEditorScreenState();
}

class _MusicClipEditorScreenState extends State<MusicClipEditorScreen>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  Timer? _clipTimer;
  late double _start;
  bool _playing = false;
  bool _loading = false;

  int get _latestStart => (widget.track.durationSeconds - 60).clamp(0, 86400);
  int get _trackDuration => widget.track.durationSeconds;

  @override
  void initState() {
    super.initState();
    _start = widget.track.clipStartSeconds.toDouble();
  }

  @override
  void dispose() {
    _clipTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _preview() async {
    if (_playing) {
      _clipTimer?.cancel();
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);

      debugPrint('MusicClipEditor: previewing ${widget.track.streamUrl}');
      await _player.stop();
      await _player.setUrl(widget.track.streamUrl);
      await _player.seek(Duration(seconds: _start.round()));
      await _player.play();

      _clipTimer?.cancel();
      _clipTimer = Timer(const Duration(seconds: 60), () async {
        await _player.pause();
        if (mounted) setState(() => _playing = false);
      });
      if (mounted) {
        setState(() {
          _loading = false;
          _playing = true;
        });
      }
    } catch (e, s) {
      debugPrint('MusicClipEditor preview failed: $e');
      debugPrint('$s');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _moveStart(double value) async {
    _clipTimer?.cancel();
    await _player.pause();
    if (!mounted) return;
    setState(() {
      _start = value.clamp(0, _latestStart.toDouble());
      _playing = false;
    });
  }

  String _time(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxStart = _latestStart.toDouble();

    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(title: 'Choose clip'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: widget.track.artworkUrl.isEmpty
                    ? ColoredBox(
                        color: colors.systemGrey5,
                        child: SizedBox.square(
                          dimension: 150,
                          child: Icon(AppIcons.music_note, size: 48),
                        ),
                      )
                    : Image.network(
                        widget.track.artworkUrl,
                        width: 150,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colors.secondaryLabel),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _time(_start.round()),
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '-',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _time((_start.round() + 60).clamp(60, _trackDuration)),
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.secondaryLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (maxStart > 0) ...[
                _WaveformScrubber(
                  durationSeconds: _trackDuration,
                  clipLength: 60,
                  maxStart: maxStart,
                  start: _start.clamp(0, maxStart),
                  onChanged: _moveStart,
                  onChangeEnd: _moveStart,
                ),
              ] else ...[
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors.systemGrey5.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.separator),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Full track • 60 sec clip',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.secondaryLabel,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _loading ? null : _preview,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colors.separator),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_loading)
                        const AppSpinner(radius: 7)
                      else
                        Icon(
                          _playing ? AppIcons.pause_fill : AppIcons.play_fill,
                          size: 14,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        _loading ? 'Loading' : (_playing ? 'Pause' : 'Preview'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: AdaptiveButton.child(
                  onPressed: () => Navigator.of(context).pop(
                    widget.track.copyWith(clipStartSeconds: _start.round()),
                  ),
                  child: const Text('Use this song'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveformScrubber extends StatelessWidget {
  const _WaveformScrubber({
    required this.durationSeconds,
    required this.clipLength,
    required this.maxStart,
    required this.start,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final int durationSeconds;
  final int clipLength;
  final double maxStart;
  final double start;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final barCount = 40;
    final random = math.Random(durationSeconds.hashCode);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final barWidth = (width - (barCount - 1) * 2) / barCount;
        final startRatio = maxStart <= 0 ? 0.0 : (start / maxStart);
        final clipWidth =
            (clipLength / durationSeconds.clamp(clipLength, 600)) * width;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            final dx = details.localPosition.dx.clamp(0, width);
            final progress = dx / width;
            final value = (progress * maxStart).clamp(0, maxStart).toDouble();
            onChanged(value);
          },
          onHorizontalDragEnd: (details) {
            onChangeEnd(start);
          },
          onTapUp: (details) {
            final dx = details.localPosition.dx.clamp(0, width);
            final progress = dx / width;
            final value = (progress * maxStart).clamp(0, maxStart).toDouble();
            onChanged(value);
            onChangeEnd(value);
          },
          child: SizedBox(
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var i = 0; i < barCount; i++)
                      Container(
                        width: barWidth,
                        height:
                            10 +
                            (random.nextDouble() * 18) +
                            math.sin(i / 4) * 6,
                        decoration: BoxDecoration(
                          color: colors.separator,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                  ],
                ),
                Positioned(
                  left: startRatio * width,
                  child: Container(
                    width: clipWidth,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: colors.label.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Positioned(
                  left: startRatio * width,
                  top: 5,
                  bottom: 5,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: colors.label,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Positioned(
                  left: startRatio * width + clipWidth - 2,
                  top: 5,
                  bottom: 5,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: colors.label,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

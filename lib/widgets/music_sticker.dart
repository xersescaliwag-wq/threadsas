// lib/widgets/music_sticker.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/models/music_track.dart';

/// A compact Threads-style 30-second music clip with a soundwave UI.
class MusicSticker extends StatefulWidget {
  const MusicSticker({super.key, required this.track});

  final MusicTrack track;

  @override
  State<MusicSticker> createState() => _MusicStickerState();
}

class _MusicStickerState extends State<MusicSticker>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _player;
  late final AnimationController _waveController;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<ProcessingState>? _processingStateSub;
  StreamSubscription<Duration>? _positionSub;
  Timer? _clipTimer;

  bool _playing = false;
  bool _loading = false;
  bool _failed = false;

  Duration get _clipStart => Duration(seconds: widget.track.clipStartSeconds);
  Duration get _clipEnd => _clipStart + const Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _playerStateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final isPlaying = state.playing;

      if (isPlaying != _playing) {
        setState(() => _playing = isPlaying);
      }

      if (isPlaying) {
        if (!_waveController.isAnimating) {
          _waveController.repeat(reverse: true);
        }
      } else {
        if (_waveController.isAnimating) {
          _waveController.stop();
        }
      }
    });

    _processingStateSub = _player.processingStateStream.listen((state) {
      if (!mounted) return;
      if (state == ProcessingState.ready || state == ProcessingState.buffering) {
        if (_loading) {
          setState(() => _loading = false);
        }
      } else if (state == ProcessingState.idle) {
        if (_loading) {
          setState(() => _loading = false);
        }
      } else if (state == ProcessingState.completed) {
        _finishClip();
      }
    });

    _positionSub = _player.positionStream.listen((position) {
      if (!mounted) return;
      if (!_playing) return;
      if (position >= _clipEnd) {
        _finishClip();
      }
    });
  }

  @override
  void dispose() {
    _clipTimer?.cancel();
    _playerStateSub?.cancel();
    _processingStateSub?.cancel();
    _positionSub?.cancel();
    try {
      if (_waveController.isAnimating) {
        _waveController.stop();
      }
    } catch (_) {}
    _waveController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading) return;

    if (_playing) {
      _clipTimer?.cancel();
      await _player.pause();
      try {
        if (_waveController.isAnimating) {
          _waveController.stop();
        }
      } catch (_) {}
      if (mounted) setState(() => _playing = false);
      return;
    }

    setState(() {
      _loading = true;
      _failed = false;
    });

    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);

      debugPrint('MusicSticker: loading ${widget.track.streamUrl}');
      await _player.stop();
      await _player.setUrl(widget.track.streamUrl);
      await _player.seek(_clipStart);
      await _player.play();

      _clipTimer?.cancel();
      _clipTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) {
          _finishClip();
        }
      });

      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted && _loading && _player.playing) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e, s) {
      debugPrint('MusicSticker play failed: $e');
      debugPrint('$s');
      if (!mounted) return;
      try {
        if (_waveController.isAnimating) {
          _waveController.stop();
        }
      } catch (_) {}
      setState(() {
        _loading = false;
        _playing = false;
        _failed = true;
      });
    }
  }

  Future<void> _finishClip() async {
    if (!mounted) return;
    _clipTimer?.cancel();
    try {
      await _player.pause();
      await _player.seek(_clipStart);
    } catch (_) {}
    try {
      if (_waveController.isAnimating) {
        _waveController.stop();
      }
    } catch (_) {}
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: colors.separator),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: _loading && !_playing
                    ? const AppSpinner(radius: 7)
                    : Icon(
                        _playing
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                        size: 16,
                        color: colors.label,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: widget.track.artworkUrl.isEmpty
                ? Container(
                    width: 34,
                    height: 34,
                    color: colors.systemGrey5,
                    child: Icon(
                      AppIcons.music_note,
                      size: 16,
                      color: colors.secondaryLabel,
                    ),
                  )
                : Image.network(
                    widget.track.artworkUrl,
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 34,
                      height: 34,
                      color: colors.systemGrey5,
                      child: Icon(
                        AppIcons.music_note,
                        size: 16,
                        color: colors.secondaryLabel,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  widget.track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.0,
                    color: colors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SoundWave(
            controller: _waveController,
            isPlaying: _playing,
            color: _failed ? colors.systemRed : colors.secondaryLabel,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _SoundWave extends StatelessWidget {
  const _SoundWave({
    required this.controller,
    required this.isPlaying,
    required this.color,
  });

  final AnimationController controller;
  final bool isPlaying;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bars = <double>[0.24, 0.5, 0.34, 0.72, 0.4, 0.62, 0.3];
    return SizedBox(
      height: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < bars.length; i++)
            AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                final t = isPlaying
                    ? (math.sin((controller.value + i * 0.16) * math.pi) * 0.36 +
                        0.64)
                    : 0.38;
                final height = 14 * bars[i] * t;
                return Container(
                  width: 1.8,
                  height: height.clamp(3, 14),
                  margin: const EdgeInsets.symmetric(horizontal: 0.9),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

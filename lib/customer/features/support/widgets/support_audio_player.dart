import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/i18n/i18n.dart';
import '../../home/widgets/premium/premium_tokens.dart';

/// Telegram-style voice-note player: a play/pause button, a seekable progress
/// slider, and an mm:ss elapsed / duration label. Loads [url] lazily on the
/// first play so a thread of many clips doesn't fan out N network buffers at
/// once.
///
/// Resilient by design: admin voice notes may be webm/opus, which `just_audio`
/// can fail to decode on iOS. A load/playback error never crashes the bubble —
/// it surfaces a small "couldn't play" state with a retry tap instead.
class SupportAudioPlayer extends StatefulWidget {
  const SupportAudioPlayer({
    super.key,
    required this.url,
    required this.mine,
  });

  final String url;

  /// Outgoing bubble (terracotta fill, white controls) vs incoming (surface
  /// fill, accent controls).
  final bool mine;

  @override
  State<SupportAudioPlayer> createState() => _SupportAudioPlayerState();
}

class _SupportAudioPlayerState extends State<SupportAudioPlayer> {
  final _player = AudioPlayer();
  bool _loaded = false;
  bool _loading = false;
  bool _failed = false;

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded || _loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await _player.setUrl(widget.url);
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _toggle() async {
    if (_failed) {
      await _ensureLoaded();
      return;
    }
    if (!_loaded) {
      await _ensureLoaded();
      if (!_loaded) return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      // Restart from the top once playback completed.
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final controlColor = widget.mine ? Colors.white : accent;
    final trackColor = widget.mine
        ? Colors.white.withValues(alpha: 0.35)
        : accent.withValues(alpha: 0.20);
    final labelColor = widget.mine
        ? Colors.white.withValues(alpha: 0.85)
        : pt.grey;

    if (_failed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.refresh, size: 18, color: controlColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                tr('support.audio_failed'),
                style: PremiumTokens.body(size: 12.5, color: labelColor),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlayButton(
            loading: _loading,
            color: controlColor,
            playing: _player.playing,
            onTap: _toggle,
            player: _player,
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 140, maxWidth: 180),
            child: StreamBuilder<Duration?>(
              stream: _player.durationStream,
              builder: (context, durSnap) {
                final duration = durSnap.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (context, posSnap) {
                    var position = posSnap.data ?? Duration.zero;
                    if (position > duration) position = duration;
                    final maxMs = duration.inMilliseconds.toDouble();
                    final value = maxMs <= 0
                        ? 0.0
                        : position.inMilliseconds.toDouble().clamp(0, maxMs);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            activeTrackColor: controlColor,
                            inactiveTrackColor: trackColor,
                            thumbColor: controlColor,
                            overlayShape: SliderComponentShape.noOverlay,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                          ),
                          child: Slider(
                            value: value.toDouble(),
                            max: maxMs <= 0 ? 1 : maxMs,
                            onChanged: maxMs <= 0
                                ? null
                                : (v) => _player.seek(
                                    Duration(milliseconds: v.round()),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Text(
                            '${_fmt(position)} / ${_fmt(duration)}',
                            style: PremiumTokens.body(
                              size: 11,
                              weight: FontWeight.w500,
                              color: labelColor,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.loading,
    required this.color,
    required this.playing,
    required this.onTap,
    required this.player,
  });

  final bool loading;
  final Color color;
  final bool playing;
  final VoidCallback onTap;
  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: color.withValues(alpha: 0.16),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onTap,
          child: loading
              ? Padding(
                  padding: const EdgeInsets.all(11),
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              : StreamBuilder<PlayerState>(
                  stream: player.playerStateStream,
                  builder: (context, snap) {
                    final isPlaying = snap.data?.playing ?? false;
                    final completed =
                        snap.data?.processingState ==
                        ProcessingState.completed;
                    return Icon(
                      isPlaying && !completed
                          ? Iconsax.pause
                          : Iconsax.play,
                      size: 18,
                      color: color,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

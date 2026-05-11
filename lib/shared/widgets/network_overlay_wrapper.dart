import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/connectivity/network_cubit.dart';
import '../../core/i18n/i18n.dart';

/// Wraps the entire `MaterialApp` content with a top-anchored connectivity
/// banner.
///
/// Behaviour (driven by [NetworkCubit]):
///
/// - `initial`  → no banner is mounted at all.
/// - `offline`  → a red pill slides in from above the status bar with
///   "Internet aloqasi yo'q" + wifi-off icon. Stays until reconnected.
/// - `online` after `offline` → the pill flips to green, shows
///   "Aloqa tiklandi" for [_restoredHold] ≈ 2s, then slides back up.
/// - Cold-boot `online` (never went offline) → banner stays hidden.
///
/// The pill is positioned via [AnimatedPositioned] inside a [Stack] — it
/// lives above the route content but does NOT use a modal barrier (the
/// user can keep tapping cached UI underneath; favorites, cart, etc. all
/// work offline thanks to Hive). [SafeArea] keeps it below the status bar
/// without overlapping it, and a [Material] ancestor stops the default
/// debug double-underline on uncoloured text.
class NetworkOverlayWrapper extends StatefulWidget {
  const NetworkOverlayWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<NetworkOverlayWrapper> createState() => _NetworkOverlayWrapperState();
}

class _NetworkOverlayWrapperState extends State<NetworkOverlayWrapper> {
  static const _slideDuration = Duration(milliseconds: 320);
  static const _restoredHold = Duration(seconds: 2);

  /// Local UI phase — separates "still offline" from the brief
  /// "you just came back" celebration.
  _BannerPhase _phase = _BannerPhase.hidden;
  Timer? _hideTimer;

  void _onNetworkChange(NetworkStatus next) {
    switch (next) {
      case NetworkStatus.initial:
        _hideTimer?.cancel();
        setState(() => _phase = _BannerPhase.hidden);
      case NetworkStatus.offline:
        _hideTimer?.cancel();
        setState(() => _phase = _BannerPhase.offline);
      case NetworkStatus.online:
        if (_phase == _BannerPhase.offline) {
          setState(() => _phase = _BannerPhase.restored);
          _hideTimer?.cancel();
          _hideTimer = Timer(_restoredHold, () {
            if (mounted) setState(() => _phase = _BannerPhase.hidden);
          });
        } else {
          _hideTimer?.cancel();
          setState(() => _phase = _BannerPhase.hidden);
        }
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NetworkCubit, NetworkStatus>(
      listenWhen: (prev, next) => prev != next,
      listener: (_, next) => _onNetworkChange(next),
      child: Stack(
        children: [
          // The actual app stays fully interactive — no barrier — so users
          // can browse cached pages while offline.
          Positioned.fill(child: widget.child),
          _BannerLayer(phase: _phase, slideDuration: _slideDuration),
        ],
      ),
    );
  }
}

enum _BannerPhase { hidden, offline, restored }

/// Animates the pill into / out of view. Splits cleanly from the wrapper so
/// the wrapper can stay focused on phase transitions / timers.
class _BannerLayer extends StatelessWidget {
  const _BannerLayer({required this.phase, required this.slideDuration});

  final _BannerPhase phase;
  final Duration slideDuration;

  // Distance the pill travels from "fully visible" to "fully off-screen".
  // Generous so the SafeArea top padding never leaves a sliver peeking out
  // on devices with a tall notch.
  static const _hiddenOffset = -140.0;
  static const _visibleTopGap = 16.0;

  @override
  Widget build(BuildContext context) {
    final visible = phase != _BannerPhase.hidden;
    final isOffline = phase == _BannerPhase.offline;

    return AnimatedPositioned(
      duration: slideDuration,
      curve: visible ? Curves.easeOutCubic : Curves.easeInCubic,
      top: visible ? 0 : _hiddenOffset,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        // The SafeArea takes care of dropping the pill below the status
        // bar; this small gap gives it room to breathe before any AppBar
        // (or the home feed's pinned eyebrow) starts.
        minimum: const EdgeInsets.only(top: _visibleTopGap),
        child: IgnorePointer(
          // Informational only — taps pass through to AppBar actions /
          // bottom sheets / etc. underneath.
          child: AnimatedOpacity(
            duration: slideDuration,
            opacity: visible ? 1 : 0,
            curve: Curves.easeOut,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _BannerPill(isOffline: isOffline),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerPill extends StatelessWidget {
  const _BannerPill({required this.isOffline});

  final bool isOffline;

  // Premium modern reds/greens — read as "alert" and "success" without
  // clashing with the Woody terracotta brand.
  static const _offlineRed = Color(0xFFE63946);
  static const _onlineGreen = Color(0xFF2A9D8F);

  @override
  Widget build(BuildContext context) {
    final color = isOffline ? _offlineRed : _onlineGreen;
    final icon = isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded;
    final label = isOffline ? tr('offline.banner') : tr('offline.restored');

    // Material(type: transparency) gives the Text a proper Material
    // ancestor — without it, debug builds draw the yellow double-underline
    // that screams "you forgot a Scaffold". `transparency` keeps our own
    // BoxDecoration colour intact.
    return Material(
      type: MaterialType.transparency,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                // Explicit decoration: none — defends against any inherited
                // TextStyle (e.g. from a missing Material ancestor further
                // up the tree during route transitions) that would re-add
                // the yellow underline.
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// iOS-style activity indicator used everywhere the app shows "loading…".
///
/// Wraps [CupertinoActivityIndicator] with a brand-aware default tint so
/// callers don't have to pass a color on every screen. Use this in place
/// of [CircularProgressIndicator] for any in-app loading state — that way
/// the busy spinner matches the pull-to-refresh indicator and the whole
/// app reads as iOS-native regardless of the host platform.
class BrandLoadingIndicator extends StatelessWidget {
  const BrandLoadingIndicator({
    super.key,
    this.color,
    this.radius = 12,
  });

  /// Tick color. Defaults to `ColorScheme.primary` so the spinner picks
  /// up seller indigo or customer terracotta from the inherited theme.
  final Color? color;

  /// Half-width of the indicator, in logical pixels. iOS's stock value
  /// (~10) reads slightly small for a centered full-screen loader, hence
  /// the bumped default of 12.
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CupertinoActivityIndicator(
      color: color ?? Theme.of(context).colorScheme.primary,
      radius: radius,
    );
  }
}

/// Pull-to-refresh wrapper that always renders the iOS-style indicator
/// (`CupertinoActivityIndicator`) regardless of the host platform.
///
/// Implemented as a thin wrapper around `RefreshIndicator.adaptive`: by
/// overriding the inherited `Theme.platform` to iOS we coax the adaptive
/// constructor into picking the Cupertino branch on Android too — same
/// "ticks fade in → spin" animation users expect from iOS apps, with no
/// custom paint or scroll listener of our own to maintain.
class BrandRefreshIndicator extends StatelessWidget {
  const BrandRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.backgroundColor,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  /// Tint of the activity-indicator ticks. Defaults to the inherited
  /// `ColorScheme.primary` (seller indigo / customer terracotta) so each
  /// surface stays on-brand without per-screen plumbing.
  final Color? color;

  /// Reserved for API symmetry with the previous custom indicator —
  /// `CupertinoActivityIndicator` paints its own ticks and has no card
  /// behind it, so this is currently unused. Left in place so callers
  /// that already passed it don't break.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      // Force the adaptive constructor to take the Cupertino branch on
      // every platform. Scoped to this subtree only — the rest of the app
      // keeps its real platform.
      data: theme.copyWith(platform: TargetPlatform.iOS),
      child: RefreshIndicator.adaptive(
        onRefresh: onRefresh,
        color: color ?? theme.colorScheme.primary,
        child: child,
      ),
    );
  }
}

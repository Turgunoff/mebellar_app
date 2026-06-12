import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'flashscore_network_modal.dart';
import 'top_toast.dart';

/// Drives the two non-inline tiers of the network-UX flow for ANY Bloc/Cubit,
/// so every primary data screen degrades identically.
///
///  • **Tier 3 (critical):** when [isCritical] turns true while the screen is
///    visible, opens the blocking [FlashscoreNetworkModal] exactly once. The
///    modal is bloc-driven and owns its own dismissal — it pops the moment
///    [isRecovered] turns true, covering BOTH the user's "Try Again" and a
///    background auto-retry, with no double-pop race. The gate only guards
///    re-opening (so a failed retry, `failure → loading → failure`, never
///    stacks a second modal).
///  • **Tier 1 (graceful):** when a background refresh fails while data is
///    still on screen, [backgroundError] yields a message and a non-blocking
///    top-toast is shown.
///
/// **Visibility guard.** The customer tabs live in an [IndexedStack] — hidden
/// tabs stay mounted and their listeners keep firing. [isActive] gates every
/// modal/toast so a hidden tab never interrupts the visible one. It defaults to
/// `ModalRoute.of(context)?.isCurrent` (correct for pushed routes); a
/// tab-resident screen must pass an explicit predicate, e.g.
/// `(ctx) => CustomerShellScope.of(ctx).index == myTab`. Reading it in `build`
/// registers the dependency, so the gate re-resolves visibility on tab change.
class NetworkErrorGate<B extends StateStreamableSource<S>, S>
    extends StatefulWidget {
  const NetworkErrorGate({
    super.key,
    required this.isCritical,
    required this.isRecovered,
    required this.isRetrying,
    required this.onRetry,
    this.backgroundError,
    this.isActive,
    required this.child,
  });

  /// No data on screen + a hard failure → show the blocking modal.
  final bool Function(S state) isCritical;

  /// The feed recovered (success) → dismiss the modal.
  final bool Function(S state) isRecovered;

  /// A load/retry is in flight → show the modal's button spinner.
  final bool Function(S state) isRetrying;

  /// Fire one retry on the bloc/cubit. The widget is rebuilt from the
  /// resulting state, so this is fire-and-forget.
  final void Function(B bloc) onRetry;

  /// Returns the message to surface as a non-blocking top-toast when a
  /// *background* refresh fails while data is still on screen, or null to skip.
  /// Pass null for sources with no cached fallback.
  final String? Function(S state)? backgroundError;

  /// Whether this gate's screen is the visible one. Defaults to the route
  /// being current ([ModalRoute.isCurrent]).
  final bool Function(BuildContext context)? isActive;

  final Widget child;

  @override
  State<NetworkErrorGate<B, S>> createState() => _NetworkErrorGateState<B, S>();
}

class _NetworkErrorGateState<B extends StateStreamableSource<S>, S>
    extends State<NetworkErrorGate<B, S>> {
  bool _modalOpen = false;
  bool _active = true;

  @override
  Widget build(BuildContext context) {
    // Resolve visibility here — the legal place to read InheritedWidgets (the
    // shell scope / ModalRoute) — and cache it for the listener, which fires
    // between builds. A tab switch updates that dependency → rebuild → fresh
    // `_active`, so a hidden tab's listener reads `false`.
    _active =
        widget.isActive?.call(context) ??
        (ModalRoute.of(context)?.isCurrent ?? true);

    return BlocListener<B, S>(
      listenWhen: (p, c) =>
          widget.isCritical(p) != widget.isCritical(c) ||
          (widget.backgroundError != null &&
              widget.backgroundError!(p) != widget.backgroundError!(c)),
      listener: (context, state) {
        if (widget.isCritical(state) && _active && !_modalOpen) {
          _openModal(context);
        }
        final bg = widget.backgroundError?.call(state);
        if (bg != null && _active && !widget.isCritical(state)) {
          showTopToast(context, message: bg, icon: Icons.wifi_off_rounded);
        }
      },
      child: widget.child,
    );
  }

  void _openModal(BuildContext context) {
    _modalOpen = true;
    final bloc = context.read<B>();
    showNetworkErrorModal(
      context,
      builder: (_) => BlocProvider<B>.value(
        value: bloc,
        // Single owner of dismissal: this inner listener pops the modal the
        // instant the feed recovers, whichever path got there.
        child: BlocListener<B, S>(
          listenWhen: (p, c) => widget.isRecovered(p) != widget.isRecovered(c),
          listener: (modalCtx, s) {
            if (widget.isRecovered(s)) Navigator.of(modalCtx).pop();
          },
          child: BlocBuilder<B, S>(
            builder: (modalCtx, s) => FlashscoreNetworkModal(
              retrying: widget.isRetrying(s),
              onRetry: () => widget.onRetry(modalCtx.read<B>()),
            ),
          ),
        ),
      ),
    ).then((_) {
      if (mounted) _modalOpen = false;
    });
  }
}

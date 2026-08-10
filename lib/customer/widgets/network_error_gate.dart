import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/connectivity/network_cubit.dart';
import 'top_toast.dart';

/// Bridges the **global** connectivity state to a screen's own refresh, so the
/// whole customer flow recovers identically with no per-screen wiring.
///
/// There is deliberately **no modal** here — the old blocking
/// `FlashscoreNetworkModal` gate is gone. Scenario A (deep offline / no cache)
/// is now an inline `ErrorState` the screen renders as its body; this gate
/// only owns the two non-blocking behaviours:
///
///  • **Auto-recovery.** When the global [NetworkCubit] flips offline → online
///    while this screen is visible, [onRetry] fires once to silently refresh
///    the screen's data. A screen showing the inline `ErrorState`
///    repopulates itself; a screen with stale data refreshes quietly. The only
///    visible cue is the global green "Tarmoq tiklandi" banner.
///  • **Background-failure toast (Tier 1).** When a background refresh fails
///    while data is still on screen, [backgroundError] yields a message and a
///    non-blocking top-toast is shown.
///
/// **Visibility guard.** Customer tabs live in an [IndexedStack] — hidden tabs
/// stay mounted and their listeners keep firing. [isActive] gates both the
/// retry and the toast so a hidden tab never refreshes (or interrupts) on the
/// visible one's behalf. It defaults to `ModalRoute.of(context)?.isCurrent`
/// (correct for pushed routes); a tab-resident screen passes an explicit
/// predicate, e.g. `(ctx) => CustomerShellScope.of(ctx).index == myTab`.
/// Reading it in `build` registers the dependency, so the gate re-resolves
/// visibility on tab change.
class NetworkErrorGate<B extends StateStreamableSource<S>, S>
    extends StatefulWidget {
  const NetworkErrorGate({
    super.key,
    required this.onRetry,
    this.backgroundError,
    this.isActive,
    required this.child,
  });

  /// Fire one refresh on the bloc/cubit when connectivity returns.
  /// Fire-and-forget: the screen rebuilds from the resulting state.
  final void Function(B bloc) onRetry;

  /// Returns the message to surface as a non-blocking top-toast when a
  /// *background* refresh fails while data is still on screen, or null to skip.
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
  bool _active = true;

  @override
  Widget build(BuildContext context) {
    // Resolve visibility here — the legal place to read InheritedWidgets (the
    // shell scope / ModalRoute) — and cache it for the listeners, which fire
    // between builds. A tab switch updates that dependency → rebuild → fresh
    // `_active`, so a hidden tab's listeners read `false`.
    _active =
        widget.isActive?.call(context) ??
        (ModalRoute.of(context)?.isCurrent ?? true);

    return MultiBlocListener(
      listeners: [
        // Centralised auto-recovery: the offline → online edge silently
        // refreshes the visible screen's data.
        BlocListener<NetworkCubit, NetworkStatus>(
          listenWhen: (prev, next) =>
              prev == NetworkStatus.offline && next == NetworkStatus.online,
          listener: (context, _) {
            if (_active) widget.onRetry(context.read<B>());
          },
        ),
        if (widget.backgroundError != null)
          BlocListener<B, S>(
            listenWhen: (p, c) =>
                widget.backgroundError!(p) != widget.backgroundError!(c),
            listener: (context, state) {
              final bg = widget.backgroundError!(state);
              if (bg != null && _active) {
                showTopToast(
                  context,
                  message: bg,
                  icon: Icons.wifi_off_rounded,
                );
              }
            },
          ),
      ],
      child: widget.child,
    );
  }
}

import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

/// Global navigation tracer. As a [NavigatorObserver] it prints every route
/// push / pop / replace / remove; the static [logTabSwitch] covers bottom-nav
/// tab changes, which never reach a [NavigatorObserver] because the tab shells
/// swap an `IndexedStack` index instead of pushing a route.
///
/// Every line carries the `[NAV]` prefix so the stream is greppable in the IDE
/// console, and rides the `dart:developer` `nav` channel — plain console lines
/// so console-only debugging works.
///
///   [NAV] 🟢 PUSHED: /products/abc-123 (from /)
///   [NAV] 🔴 POPPED: /products/abc-123 (back to /)
///   [NAV] 🔵 REPLACED: /login with /home
///   [NAV] ⚪ REMOVED: /modal (parent: /)
///   [NAV] 🟡 TAB SWITCHED: Index 2 (Cart)
class AppNavigationLogger extends NavigatorObserver {
  AppNavigationLogger({this.tag = 'NAV'});

  final String tag;

  /// Logs a bottom-nav tab switch. Static because the tab shells (customer
  /// `IndexedStack`, seller `StatefulShellRoute`) change an index rather than
  /// pushing a route, so a [NavigatorObserver] never sees them — the call site
  /// inside the shell's `onTap`/`onChanged` reports the switch instead.
  static void logTabSwitch(int index, String label) {
    developer.log('[NAV] 🟡 TAB SWITCHED: Index $index ($label)', name: 'nav');
  }

  /// A readable id for a route: its `settings.name` (the matched path under
  /// GoRouter), falling back to the route's runtime type when it is unnamed —
  /// so an anonymous dialog/sheet route logs as e.g. `_DialogRoute<dynamic>`
  /// rather than crashing on a null name.
  String _name(Route<dynamic>? route) {
    if (route == null) return '<none>';
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) return name;
    return route.runtimeType.toString();
  }

  void _log(String line) => developer.log(line, name: tag.toLowerCase());

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('[$tag] 🟢 PUSHED: ${_name(route)} (from ${_name(previousRoute)})');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('[$tag] 🔴 POPPED: ${_name(route)} (back to ${_name(previousRoute)})');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _log('[$tag] 🔵 REPLACED: ${_name(oldRoute)} with ${_name(newRoute)}');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('[$tag] ⚪ REMOVED: ${_name(route)} (parent: ${_name(previousRoute)})');
  }
}

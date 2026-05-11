import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

/// Prints concise navigation events to the IDE console:
///
///   [NAV] PUSH    /products/abc-123  (from /)
///   [NAV] POP     /products/abc-123  -> /
///   [NAV] REPLACE /home              -> /catalog
///   [NAV] REMOVE  /modal             (parent: /)
///
/// Sits alongside `TalkerRouteObserver`: that one feeds the in-app log screen,
/// this one writes plain lines to stdout so console-only debugging works
/// without opening the Talker overlay. Uses `dart:developer` log so the
/// output is grouped under a `nav` channel in IDE consoles.
class ConsoleNavObserver extends NavigatorObserver {
  ConsoleNavObserver({this.tag = 'NAV'});

  final String tag;

  String _name(Route<dynamic>? route) {
    if (route == null) return '<none>';
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) return name;
    return route.runtimeType.toString();
  }

  void _log(String line) {
    developer.log(line, name: tag.toLowerCase());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('PUSH    ${_name(route)}  (from ${_name(previousRoute)})');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('POP     ${_name(route)}  -> ${_name(previousRoute)}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _log('REPLACE ${_name(oldRoute)}  -> ${_name(newRoute)}');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('REMOVE  ${_name(route)}  (parent: ${_name(previousRoute)})');
  }

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    _log('GESTURE-START ${_name(route)}');
  }

  @override
  void didStopUserGesture() {
    _log('GESTURE-STOP');
  }
}

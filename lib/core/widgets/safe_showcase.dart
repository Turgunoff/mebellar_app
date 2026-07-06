import 'package:flutter/widgets.dart';
import 'package:showcaseview/showcaseview.dart';

import '../logging/app_logger.dart';

/// Starts a first-launch spotlight only after every [keys] target is mounted.
///
/// showcaseview dereferences `GlobalKey.currentContext!` internally — calling
/// [ShowCaseWidgetState.startShowCase] on the first post-frame callback often
/// races the initial layout pass and crashes with "Null check operator used on
/// a null value".
Future<void> safeStartShowCase(
  BuildContext context,
  List<GlobalKey> keys, {
  int maxAttempts = 12,
  Duration retryDelay = const Duration(milliseconds: 100),
}) async {
  if (keys.isEmpty) return;

  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (!context.mounted) return;
    final ready = keys.every((key) => key.currentContext != null);
    if (!ready) {
      await Future<void>.delayed(retryDelay);
      continue;
    }
    try {
      ShowCaseWidget.of(context).startShowCase(keys);
    } catch (e, st) {
      appLog.warning('Showcase start skipped', e, st);
    }
    return;
  }
}

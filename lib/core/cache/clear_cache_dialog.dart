import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../i18n/i18n.dart';
import 'app_cache_cubit.dart';

/// Shared confirm-then-clear flow used by both the customer and seller settings
/// screens. Shows a localized confirmation dialog and, on confirm, triggers the
/// scoped cache wipe via [AppCacheCubit]. The [AlertDialog] inherits the ambient
/// Material theme, so it renders correctly in either mode and in light/dark.
Future<void> confirmAndClearCache(BuildContext context) async {
  // Resolve the cubit before the await gap so we don't reach back through a
  // possibly-deactivated context afterwards.
  final cubit = context.read<AppCacheCubit>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('settings.clear_cache')),
      content: Text(tr('settings.clear_cache_message')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(tr('common.cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(tr('settings.clear_cache_confirm')),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await cubit.clearCache();
  }
}

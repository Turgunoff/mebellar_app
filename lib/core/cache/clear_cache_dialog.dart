import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_cache_cubit.dart';

/// Shared confirm-then-clear flow used by both the customer and seller settings
/// screens. Shows the Uzbek confirmation dialog and, on confirm, triggers the
/// scoped cache wipe via [AppCacheCubit]. The [AlertDialog] inherits the ambient
/// Material theme, so it renders correctly in either mode and in light/dark.
Future<void> confirmAndClearCache(BuildContext context) async {
  // Resolve the cubit before the await gap so we don't reach back through a
  // possibly-deactivated context afterwards.
  final cubit = context.read<AppCacheCubit>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Keshni tozalash'),
      content: const Text(
        'Haqiqatan ham barcha vaqtinchalik fayllar va rasmlar keshini '
        'tozalamoqchimisiz?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Bekor qilish'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Tozalash'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await cubit.clearCache();
  }
}

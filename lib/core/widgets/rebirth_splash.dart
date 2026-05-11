import 'package:flutter/material.dart';

/// Briefly shows an opaque branded splash so Phoenix.rebirth() doesn't reveal
/// a frame of the dismantled tree to the user.
///
/// Usage: [showRebirthSplash] before destructive scope work, then call
/// `Phoenix.rebirth(context)`. The new tree replaces the splash naturally.
Future<void> showRebirthSplash(
  BuildContext context, {
  Duration linger = const Duration(milliseconds: 200),
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Theme.of(context).colorScheme.surface,
    transitionDuration: Duration.zero,
    pageBuilder: (_, _, _) => const _RebirthSplashContent(),
  );
}

class _RebirthSplashContent extends StatefulWidget {
  const _RebirthSplashContent();

  @override
  State<_RebirthSplashContent> createState() => _RebirthSplashContentState();
}

class _RebirthSplashContentState extends State<_RebirthSplashContent> {
  @override
  void initState() {
    super.initState();
    // Auto-dismiss after a short delay so this runs as a fire-and-forget call;
    // the caller follows up with Phoenix.rebirth which replaces this frame.
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(color: scheme.primary),
        ),
      ),
    );
  }
}

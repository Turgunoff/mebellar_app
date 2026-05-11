import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

import '../../core/connectivity/connectivity_service.dart';
import '../../core/di/service_locator.dart';

/// Sticky banner that animates in/out of view when [ConnectivityService]
/// flips online в†” offline. Wrap the page body to render it at the top:
/// ```dart
/// body: Column(children: [const OfflineBanner(), Expanded(child: ...)])
/// ```
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!sl.isRegistered<ConnectivityService>()) {
      return const SizedBox.shrink();
    }
    final service = sl<ConnectivityService>();
    return StreamBuilder<ConnectivityStatus>(
      stream: service.watch(),
      initialData: service.status,
      builder: (context, snap) {
        final offline = snap.data == ConnectivityStatus.offline;
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: offline
              ? _Banner()
              : const SizedBox(width: double.infinity, height: 0),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined, color: scheme.onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Text(
            tr('offline.banner'),
            style: TextStyle(
              color: scheme.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

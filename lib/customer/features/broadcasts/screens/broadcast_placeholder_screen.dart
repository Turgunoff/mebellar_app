import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../shared/widgets/empty_state.dart';

/// Stand-in target for `promo` / `news` / `system_alert` notification taps
/// before the dedicated screens land.
///
/// Why a single shared screen rather than three real ones: the dedicated
/// promo and news feeds aren't designed yet, but the routing interceptor
/// in `notifications_screen.dart` already resolves these kinds to a path.
/// Without *some* route registered, GoRouter would land on its error page,
/// which would be the user's first impression of a fresh promo push. This
/// placeholder is loud about being a placeholder (visible icon + title +
/// the resolved deep-link id, when present) so the wiring is testable end
/// to end and the gap is obvious to whoever picks up the screens next.
class BroadcastPlaceholderScreen extends StatelessWidget {
  const BroadcastPlaceholderScreen({
    super.key,
    required this.kind,
    this.referenceId,
  });

  /// Which placeholder to render. Drives the icon + the title copy.
  final BroadcastKind kind;

  /// Optional deep-link id from the URL — surfaces in the body so it's
  /// obvious that the routing layer did its job and the gap is purely the
  /// missing destination UI.
  final String? referenceId;

  @override
  Widget build(BuildContext context) {
    final hasId = referenceId != null && referenceId!.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(_title(kind)),
      ),
      body: EmptyState(
        icon: _icon(kind),
        title: _title(kind),
        message: hasId
            ? 'Placeholder — id: $referenceId\n'
                'The dedicated screen lands in a follow-up Sprint.'
            : 'Placeholder — the dedicated screen lands in a follow-up Sprint.',
        actionLabel: 'Bosh sahifaga',
        action: () => context.go('/'),
      ),
    );
  }

  static IconData _icon(BroadcastKind kind) {
    return switch (kind) {
      BroadcastKind.promo => Iconsax.discount_shape,
      BroadcastKind.news => Iconsax.global,
      BroadcastKind.systemAlert => Iconsax.danger,
    };
  }

  static String _title(BroadcastKind kind) {
    return switch (kind) {
      BroadcastKind.promo => 'Aksiya',
      BroadcastKind.news => 'Yangiliklar',
      BroadcastKind.systemAlert => 'Tizim ogohlantirishi',
    };
  }
}

enum BroadcastKind { promo, news, systemAlert }

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:woody_app/core/i18n/i18n.dart';

/// Placeholder shown in place of seller surfaces whose backend is not live
/// yet — orders, shop settings, seller services, KYC verification.
///
/// Gated by `AppConfig.sellerFulfillmentEnabled` (ROADMAP A.2): when the flag
/// is off, the affected screens return this instead of wiring a mock-backed
/// bloc, so a release build never shows fake data to a real seller.
class ComingSoonBetaWidget extends StatelessWidget {
  const ComingSoonBetaWidget({super.key, this.title});

  /// When non-null the widget wraps itself in a [Scaffold] + [AppBar] (a back
  /// button and this title) — use for screens reached as a pushed route.
  /// When null only the centered placeholder body is returned — use when the
  /// widget is embedded directly as a tab body.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final body = ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Iconsax.clock,
                  size: 38,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                tr('beta.coming_soon_title'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                tr('beta.coming_soon_message'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );

    if (title == null) return body;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(title!)),
      body: body,
    );
  }
}

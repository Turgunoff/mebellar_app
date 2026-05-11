import 'package:cached_network_image/cached_network_image.dart';
import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/shop.dart';

/// Shop summary card surfaced inside the product detail screen. Renders the
/// logo, name + verified badge, and quick-contact buttons (phone, Telegram).
/// Calls fall back to copying the number to the clipboard if `tel:` URLs
/// can't launch on the device (e.g. iOS sim without dialer).
class ShopCard extends StatelessWidget {
  const ShopCard({super.key, required this.shop, this.onTap});

  final Shop shop;
  final VoidCallback? onTap;

  Future<void> _callPhone(BuildContext context) async {
    final phone = shop.contactPhone;
    if (phone == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Clipboard.setData(ClipboardData(text: phone));
      messenger.showSnackBar(
        SnackBar(content: Text(tr('shop.phone_copied', args: [phone]))),
      );
    }
  }

  Future<void> _openTelegram(BuildContext context) async {
    final username = shop.telegramUsername;
    if (username == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse('https://t.me/$username');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('shop.telegram_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    final hasPhone = shop.contactPhone != null;
    final hasTelegram = shop.telegramUsername != null;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.surfaceContainerHighest,
                backgroundImage: shop.logoUrl != null
                    ? CachedNetworkImageProvider(shop.logoUrl!)
                    : null,
                child: shop.logoUrl == null
                    ? Icon(Icons.storefront_outlined, color: scheme.outline)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            shop.name.get(lang),
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (shop.isVerified) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.verified,
                            size: 18,
                            color: scheme.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shop.isVerified
                          ? tr('shop.verified')
                          : tr('shop.not_verified'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: shop.isVerified
                                ? scheme.primary
                                : scheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              if (hasPhone)
                IconButton.filledTonal(
                  tooltip: tr('shop.call'),
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () => _callPhone(context),
                ),
              if (hasTelegram) ...[
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: tr('shop.telegram'),
                  icon: const Icon(Icons.send_outlined),
                  onPressed: () => _openTelegram(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

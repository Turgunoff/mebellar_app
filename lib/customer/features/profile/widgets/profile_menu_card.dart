import 'package:flutter/material.dart';

import '../../home/widgets/premium/premium_tokens.dart';

/// One row in the [MenuListCard].
class MenuEntry {
  const MenuEntry({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

/// Card grouping the settings / help / about navigation rows.
class MenuListCard extends StatelessWidget {
  const MenuListCard({super.key, required this.items});

  final List<MenuEntry> items;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _MenuRow(entry: items[i]),
            if (i != items.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Divider(height: 1, color: pt.divider),
              ),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.entry});

  final MenuEntry entry;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final radius = BorderRadius.circular(20);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: entry.onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: pt.imageBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(entry.icon, size: 18, color: pt.dark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  entry.label,
                  style: PremiumTokens.body(size: 14, weight: FontWeight.w500),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: pt.greyLight),
            ],
          ),
        ),
      ),
    );
  }
}

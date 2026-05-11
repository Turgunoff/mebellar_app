import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

class AttributesBlock extends StatelessWidget {
  const AttributesBlock({super.key, required this.attributes});

  final Map<String, dynamic> attributes;

  String _labelFor(String key) {
    // Try i18n first, fall back to a humanised version of the raw key.
    final tk = 'attributes.$key';
    final translated = tr(tk);
    if (translated == tk) {
      return key
          .replaceAll('_', ' ')
          .replaceFirstMapped(RegExp(r'^.'), (m) => m[0]!.toUpperCase());
    }
    return translated;
  }

  @override
  Widget build(BuildContext context) {
    if (attributes.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('product.attributes'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (var i = 0; i < attributes.length; i++) ...[
                if (i != 0) Divider(height: 1, color: scheme.outlineVariant),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          _labelFor(attributes.keys.elementAt(i)),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: scheme.outline,
                                  ),
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Text(
                          '${attributes.values.elementAt(i)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

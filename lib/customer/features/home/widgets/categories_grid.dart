import 'package:cached_network_image/cached_network_image.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

import '../../../../shared/models/category.dart';

class CategoriesGrid extends StatelessWidget {
  const CategoriesGrid({super.key, required this.categories, this.onTap});

  final List<Category> categories;
  final ValueChanged<Category>? onTap;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final cat = categories[i];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap == null ? null : () => onTap!(cat),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: cat.iconUrl != null && cat.iconUrl!.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CachedNetworkImage(
                          imageUrl: cat.iconUrl!,
                          // ROADMAP B.7 — category icons render small; decode
                          // them small too.
                          memCacheWidth: 200,
                          errorWidget: (_, _, _) => Icon(
                            Icons.category_outlined,
                            color: scheme.primary,
                          ),
                        ),
                      )
                    : Icon(Icons.category_outlined, color: scheme.primary),
              ),
              const SizedBox(height: 6),
              Text(
                cat.name.get(lang),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

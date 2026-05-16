import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/seller_product.dart';
import '../widgets/product_preview/attributes_card.dart';
import '../widgets/product_preview/bottom_action_bar.dart';
import '../widgets/product_preview/description_card.dart';
import '../widgets/product_preview/meta_card.dart';
import '../widgets/product_preview/preview_app_bar.dart';
import '../widgets/product_preview/preview_summary_cards.dart';
import '../widgets/product_preview/product_preview_kit.dart';
import '../widgets/product_preview/spec_cards.dart';

/// Customer-style preview of a seller's own product — gallery, title/price,
/// status and the buyer-facing content cards, with an Edit primary action.
///
/// ROADMAP B.4 — the original 1,261-line file was split: every section lives
/// under `widgets/product_preview/`, leaving this file as the scroll shell.
class SellerProductDetailScreen extends StatelessWidget {
  const SellerProductDetailScreen({super.key, this.onEdit});

  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    const product = kPreviewMockProduct;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          PreviewAppBar(images: product.images),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  PreviewModeBanner(),
                  SizedBox(height: 14),
                  StatusCard(
                    status: SellerProductStatus.approved,
                    updatedAtLabel: '02 May 2026, 18:42',
                  ),
                  SizedBox(height: 14),
                  TitlePriceCard(product: product),
                  SizedBox(height: 14),
                  MetaCard(
                    sku: 'MH-KIT-010',
                    category: 'Oshxona jihozlari',
                    stock: 2,
                  ),
                  SizedBox(height: 14),
                  DescriptionCard(
                    text:
                        'Klassik uslubdagi premium oshxona jihozlari to\'plami. '
                        'Tabiiy yong\'oq daraxtidan ishlangan, qo\'lda jilolangan '
                        'sirt va mis dastalar bilan bezatilgan. Komplektga oshxona '
                        'shkafi, ish stoli, hamda 4 ta yumshoq stul kiradi. '
                        'Materiallar O\'zbekistonda yetishtirilgan, eko-do\'st '
                        'lak bilan qoplangan. Yetkazib berish va yig\'ish '
                        'xizmati shahar ichida bepul.',
                  ),
                  SizedBox(height: 14),
                  AttributesCard(
                    rows: [
                      ('Material', 'Yong\'oq daraxti'),
                      ('Rang', 'Tabiiy jigarrang'),
                      ('Uslub', 'Klassik'),
                      ('Kafolat muddati', '24 oy'),
                      ('Ishlab chiqaruvchi', "O'zbekiston"),
                    ],
                  ),
                  SizedBox(height: 14),
                  DimensionsCard(
                    lengthCm: 220,
                    widthCm: 80,
                    heightCm: 95,
                    weightKg: 64.5,
                  ),
                  SizedBox(height: 14),
                  IdentifiersCard(
                    productId: 'pr_01HVZ8N7K4Q9X2',
                    createdAtLabel: '14 Apr 2026',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(onEdit: onEdit),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/theme/app_colors.dart';

// =============================================================================
// Local design tokens — Plus Jakarta Sans is applied per-`Text` so the surface
// is immune to the M3 surface tint that the teal seller seed would otherwise
// bleed onto neutral backgrounds. Mirrors the convention used in
// `profile_screen.dart` and `shop_settings_screen.dart`.
// =============================================================================
const _ink = Color(0xFF1D1D1D);
const _grey = Color(0xFF757575);
const _greyMid = Color(0xFFBDBDBD);
const _divider = Color(0xFFEFEFEF);
const _chipIdle = Color(0xFFF1F1F1);
const _replyBg = Color(0xFFF5F5F5);
const _amber = Color(0xFFF5A623);
const _terracottaTint = Color(0x14C27A5F);

// =============================================================================
// 1. Filter model
// =============================================================================
enum _ReviewFilter { all, pending, fiveStar, critical }

extension _ReviewFilterX on _ReviewFilter {
  String get label {
    switch (this) {
      case _ReviewFilter.all:
        return 'Barchasi';
      case _ReviewFilter.pending:
        return 'Javob kutilmoqda';
      case _ReviewFilter.fiveStar:
        return '5 Yulduz';
      case _ReviewFilter.critical:
        return '1-2 Yulduz';
    }
  }
}

// =============================================================================
// 2. Mock review entity
// =============================================================================
class _Review {
  const _Review({
    required this.id,
    required this.productName,
    required this.productImage,
    required this.customerName,
    required this.rating,
    required this.text,
    required this.timeAgo,
    this.sellerReply,
  });

  final String id;
  final String productName;
  final String productImage;
  final String customerName;
  final int rating;
  final String text;
  final String timeAgo;
  final String? sellerReply;

  bool get hasReply => sellerReply != null && sellerReply!.isNotEmpty;
}

const _mockReviews = <_Review>[
  _Review(
    id: 'r1',
    productName: 'Klassik kuxnya jihozlari',
    productImage:
        'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=200',
    customerName: 'Aziza Karimova',
    rating: 5,
    text:
        "Juda ajoyib mebel ekan, yetkazib berish ham tez bo'ldi. Hammaga tavsiya qilaman!",
    timeAgo: '2 soat oldin',
  ),
  _Review(
    id: 'r2',
    productName: 'Zamonaviy divan "Loft"',
    productImage:
        'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=200',
    customerName: 'Sardor Aliyev',
    rating: 4,
    text:
        "Sifati yaxshi, lekin yig'ish bo'yicha ko'rsatma biroz noaniq edi. Umuman olganda mamnunman.",
    timeAgo: '5 soat oldin',
    sellerReply:
        "Sardor aka, fikr-mulohazangiz uchun rahmat! Ko'rsatmani yaxshilash ustida ishlayapmiz.",
  ),
  _Review(
    id: 'r3',
    productName: 'Yotoq xonasi to\'plami',
    productImage:
        'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?w=200',
    customerName: 'Malika Tursunova',
    rating: 2,
    text:
        "Yetkazib berish kechikdi va karobka ozgina shikastlangan edi. Mahsulotning o'zi yaxshi, lekin xizmat darajasini ko'tarish kerak.",
    timeAgo: '1 kun oldin',
  ),
  _Review(
    id: 'r4',
    productName: 'Yog\'och ish stoli',
    productImage:
        'https://images.unsplash.com/photo-1518455027359-f3f8164ba6bd?w=200',
    customerName: 'Bekzod Rahmonov',
    rating: 5,
    text:
        "Aynan o'zim qidirgan stol! Materiali tabiiy, yig'ish oson. Rahmat!",
    timeAgo: '3 kun oldin',
    sellerReply: 'Bekzod aka, xaridingiz uchun rahmat! Sog\'-omon foydalaning.',
  ),
  _Review(
    id: 'r5',
    productName: 'Ofis kresllosi Pro',
    productImage:
        'https://images.unsplash.com/photo-1592078615290-033ee584e267?w=200',
    customerName: 'Nilufar Yusupova',
    rating: 1,
    text:
        "Rasmda ko'rsatilgani bilan farqi katta. Qaytarish jarayoni ham juda murakkab.",
    timeAgo: '4 kun oldin',
  ),
];

// =============================================================================
// 3. Screen
// =============================================================================
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  _ReviewFilter _filter = _ReviewFilter.all;

  List<_Review> get _filtered {
    switch (_filter) {
      case _ReviewFilter.all:
        return _mockReviews;
      case _ReviewFilter.pending:
        return _mockReviews.where((r) => !r.hasReply).toList();
      case _ReviewFilter.fiveStar:
        return _mockReviews.where((r) => r.rating == 5).toList();
      case _ReviewFilter.critical:
        return _mockReviews.where((r) => r.rating <= 2).toList();
    }
  }

  int get _pendingCount => _mockReviews.where((r) => !r.hasReply).length;

  void _openReplySheet(_Review review) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ReplySheet(review: review),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reviews = _filtered;
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: const _ReviewsAppBar(),
      body: Column(
        children: [
          _FilterTabs(
            current: _filter,
            pendingCount: _pendingCount,
            onChanged: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: reviews.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    itemCount: reviews.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _ReviewCard(
                      review: reviews[i],
                      onReply: () => _openReplySheet(reviews[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 4. App bar — clean white, bold title
// =============================================================================
class _ReviewsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ReviewsAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: _ink,
      leading: IconButton(
        icon: const Icon(Iconsax.arrow_left_2, size: 22, color: _ink),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        'Mijozlar sharhlari',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _ink,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

// =============================================================================
// 5. Filter tabs — horizontally scrollable choice chips
// =============================================================================
class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.current,
    required this.pendingCount,
    required this.onChanged,
  });

  final _ReviewFilter current;
  final int pendingCount;
  final ValueChanged<_ReviewFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (final f in _ReviewFilter.values) ...[
              _FilterChip(
                label: f.label,
                selected: current == f,
                badgeCount: f == _ReviewFilter.pending ? pendingCount : null,
                onTap: () => onChanged(f),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? _ink : _chipIdle;
    final fg = selected ? Colors.white : _ink;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  height: 1.0,
                  letterSpacing: -0.1,
                ),
              ),
              if (badgeCount != null && badgeCount! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    color: AppColors.terracotta,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$badgeCount',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 6. Review card — thumbnail + product, divider, content, reply slot
// =============================================================================
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onReply});

  final _Review review;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(review: review),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: _divider),
          const SizedBox(height: 12),
          _CustomerLine(review: review),
          const SizedBox(height: 8),
          Text(
            review.text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF3A3A3A),
              height: 1.5,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 12),
          if (review.hasReply)
            _SellerReplyBlock(reply: review.sellerReply!)
          else
            _ReplyButton(onTap: onReply),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.review});

  final _Review review;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            review.productImage,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 40,
              height: 40,
              color: _chipIdle,
              alignment: Alignment.center,
              child: const Icon(Iconsax.box, size: 18, color: _greyMid),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            review.productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _ink,
              height: 1.25,
              letterSpacing: -0.1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          review.timeAgo,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _grey,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _CustomerLine extends StatelessWidget {
  const _CustomerLine({required this.review});

  final _Review review;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            review.customerName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _ink,
              height: 1.2,
              letterSpacing: -0.1,
            ),
          ),
        ),
        _StarRow(rating: review.rating),
      ],
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++) ...[
          Icon(
            Iconsax.star_1,
            size: 14,
            color: i <= rating ? _amber : const Color(0xFFE3E3E3),
          ),
          if (i < 5) const SizedBox(width: 2),
        ],
      ],
    );
  }
}

// =============================================================================
// 7. Reply button — terracotta outlined
// =============================================================================
class _ReplyButton extends StatelessWidget {
  const _ReplyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Iconsax.edit, size: 16, color: AppColors.terracotta),
        label: Text(
          'Javob yozish',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.terracotta,
            letterSpacing: -0.1,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: const BorderSide(color: AppColors.terracotta, width: 1.2),
          backgroundColor: _terracottaTint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 8. Seller reply block — soft grey, nested feel
// =============================================================================
class _SellerReplyBlock extends StatelessWidget {
  const _SellerReplyBlock({required this.reply});

  final String reply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: _replyBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: _terracottaTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Iconsax.shop,
              size: 16,
              color: AppColors.terracotta,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sizning javobingiz',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.terracotta,
                    height: 1.2,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reply,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _ink,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 9. Reply bottom sheet (mock — hook up to a bloc later)
// =============================================================================
class _ReplySheet extends StatefulWidget {
  const _ReplySheet({required this.review});

  final _Review review;

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + viewInsets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE3E3E3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Javob yozish',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.review.customerName} • ${widget.review.productName}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _grey,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 5,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _ink,
              height: 1.45,
            ),
            decoration: InputDecoration(
              hintText: 'Mijozga samimiy javob yozing...',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _greyMid,
              ),
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.terracotta,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Yuborish',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 10. Empty state
// =============================================================================
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: _chipIdle,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Iconsax.messages_2,
                size: 32,
                color: _greyMid,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sharhlar topilmadi',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _ink,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tanlangan filtr bo\'yicha sharhlar yo\'q.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _grey,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

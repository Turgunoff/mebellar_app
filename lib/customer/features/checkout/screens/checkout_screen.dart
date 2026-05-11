import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_cubit.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/models/cart_item_model.dart';
import '../../../../shared/repositories/cart_repository.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../cubit/checkout_cubit.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key, required this.items});

  final List<CartItemModel> items;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CheckoutCubit(
        items: items,
        supabase: sl<SupabaseClient>(),
        cartRepo: sl<CartRepository>(),
      ),
      child: const _CheckoutView(),
    );
  }
}

class _CheckoutView extends StatelessWidget {
  const _CheckoutView();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return BlocConsumer<CheckoutCubit, CheckoutState>(
      listenWhen: (a, b) => a.status != b.status,
      listener: (ctx, state) {
        if (state.status == CheckoutStatus.success) {
          _showSuccessDialog(ctx);
        }
        if (state.status == CheckoutStatus.failure) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(state.error ?? 'Xatolik yuz berdi'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      },
      builder: (ctx, state) {
        return Scaffold(
          backgroundColor: pt.background,
          appBar: AppBar(
            backgroundColor: pt.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(Iconsax.arrow_left, color: pt.dark),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Rasmiylashtirish',
              style: PremiumTokens.display(size: 20, letterSpacing: -0.4),
            ),
            centerTitle: false,
          ),
          body: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 160),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _DeliveryCard(state: state, pt: pt),
                        const SizedBox(height: 16),
                        _PaymentCard(state: state, pt: pt),
                        const SizedBox(height: 16),
                        _SummaryCard(state: state, pt: pt),
                      ]),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ConfirmBar(state: state, pt: pt),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final pt = PremiumTokens.of(ctx);
        return AlertDialog(
          backgroundColor: pt.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: PremiumTokens.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.tick_circle,
                  color: PremiumTokens.accent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Buyurtmangiz qabul qilindi!',
                textAlign: TextAlign.center,
                style: PremiumTokens.display(size: 20, letterSpacing: -0.3),
              ),
              const SizedBox(height: 10),
              Text(
                'Buyurtmangiz muvaffaqiyatli joylashtirildi. Tez orada siz bilan bog\'lanamiz.',
                textAlign: TextAlign.center,
                style: PremiumTokens.body(
                  size: 14,
                  color: pt.grey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (context.mounted) context.go('/');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: PremiumTokens.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Asosiy sahifaga qaytish',
                    style: PremiumTokens.body(
                      size: 15,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Section 1: Delivery ──────────────────────────────────────────────────────

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.state, required this.pt});
  final CheckoutState state;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    final hasAddress = state.hasAddress;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _showAddressSheet(context, state.deliveryAddress),
        borderRadius: BorderRadius.circular(20),
        splashColor: PremiumTokens.accent.withValues(alpha: 0.06),
        highlightColor: PremiumTokens.accent.withValues(alpha: 0.04),
        child: _SectionCard(
          pt: pt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SectionHeader(
                      icon: Iconsax.location,
                      label: 'Yetkazib berish manzili',
                      pt: pt,
                    ),
                  ),
                  Icon(
                    Iconsax.arrow_right_3,
                    size: 16,
                    color: pt.greyLight,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasAddress
                          ? PremiumTokens.accent.withValues(alpha: 0.1)
                          : pt.imageBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      hasAddress ? Iconsax.map : Iconsax.location_add,
                      color: hasAddress ? PremiumTokens.accent : pt.greyLight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: hasAddress
                        ? Text(
                            state.deliveryAddress,
                            style: PremiumTokens.body(
                              size: 14,
                              weight: FontWeight.w600,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manzilni kiriting...',
                                style: PremiumTokens.body(
                                  size: 14,
                                  weight: FontWeight.w500,
                                  color: pt.greyLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Yetkazib berish manzilini tanlang',
                                style:
                                    PremiumTokens.body(size: 12, color: pt.greyLight),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
              if (!hasAddress) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Iconsax.info_circle,
                        size: 14,
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Buyurtma uchun manzil talab qilinadi',
                        style: PremiumTokens.body(
                          size: 12,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAddressSheet(BuildContext context, String currentAddress) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _AddressSheet(
        initialAddress: currentAddress,
        onConfirm: (address) =>
            context.read<CheckoutCubit>().updateAddress(address),
      ),
    );
  }
}

// ── Address bottom sheet ──────────────────────────────────────────────────────

class _AddressSheet extends StatefulWidget {
  const _AddressSheet({
    required this.initialAddress,
    required this.onConfirm,
  });

  final String initialAddress;
  final ValueChanged<String> onConfirm;

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialAddress);
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: pt.divider,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          // Title row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PremiumTokens.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Iconsax.location,
                  color: PremiumTokens.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Yetkazib berish manzili',
                style:
                    PremiumTokens.display(size: 18, letterSpacing: -0.3),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Address field
          TextField(
            controller: _ctrl,
            focusNode: _focusNode,
            maxLines: 3,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: PremiumTokens.body(size: 15),
            decoration: InputDecoration(
              hintText:
                  'Masalan: Toshkent shahar, Yunusobod tumani, 1-mavze, 12-uy',
              hintStyle: PremiumTokens.body(size: 14, color: pt.greyLight),
              filled: true,
              fillColor: pt.imageBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: pt.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: PremiumTokens.accent,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: () {
                final text = _ctrl.text.trim();
                if (text.isEmpty) return;
                widget.onConfirm(text);
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: PremiumTokens.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Tasdiqlash',
                style: PremiumTokens.body(
                  size: 15,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section 2: Payment ───────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.state, required this.pt});
  final CheckoutState state;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      pt: pt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Iconsax.card,
            label: "To'lov usuli",
            pt: pt,
          ),
          const SizedBox(height: 8),
          _PaymentTile(
            icon: Iconsax.money,
            title: 'Naqd pul',
            subtitle: "Yetkazib berishda to'lash",
            selected: state.payment == CheckoutPayment.cash,
            onTap: () => context
                .read<CheckoutCubit>()
                .selectPayment(CheckoutPayment.cash),
            pt: pt,
          ),
          const SizedBox(height: 8),
          _PaymentTile(
            icon: Iconsax.card,
            title: 'Karta',
            subtitle: 'Tez orada mavjud bo\'ladi',
            selected: state.payment == CheckoutPayment.card,
            onTap: null,
            pt: pt,
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.pt,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected
              ? PremiumTokens.accent.withValues(alpha: 0.07)
              : pt.imageBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? PremiumTokens.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: disabled
                  ? pt.greyLight
                  : (selected ? PremiumTokens.accent : pt.dark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: PremiumTokens.body(
                      size: 14,
                      weight: FontWeight.w600,
                      color: disabled ? pt.greyLight : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: PremiumTokens.body(
                      size: 12,
                      color: disabled ? pt.greyLight : pt.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (!disabled)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? PremiumTokens.accent : Colors.transparent,
                  border: Border.all(
                    color:
                        selected ? PremiumTokens.accent : pt.greyLight,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Section 3: Summary ───────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state, required this.pt});
  final CheckoutState state;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      pt: pt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Iconsax.receipt,
            label: 'Buyurtma jami',
            pt: pt,
          ),
          const SizedBox(height: 16),
          _SummaryRow(
            label: 'Mahsulotlar',
            value: '${_fmt(state.subtotal)} UZS',
            pt: pt,
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Yetkazib berish',
            value: '${_fmt(CheckoutState.deliveryFee)} UZS',
            pt: pt,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: pt.divider, height: 1),
          ),
          _SummaryRow(
            label: 'Jami',
            value: '${_fmt(state.grandTotal)} UZS',
            isBold: true,
            pt: pt,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.pt,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    final weight = isBold ? FontWeight.w700 : FontWeight.w400;
    final size = isBold ? 16.0 : 14.0;
    return Row(
      children: [
        Text(
          label,
          style: PremiumTokens.body(
            size: size,
            weight: weight,
            color: isBold ? pt.dark : pt.grey,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: PremiumTokens.body(
            size: size,
            weight: weight,
            color: isBold ? PremiumTokens.accent : pt.dark,
          ),
        ),
      ],
    );
  }
}

// ── Confirm bar ───────────────────────────────────────────────────────────────

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.state, required this.pt});
  final CheckoutState state;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    final isBusy = state.status == CheckoutStatus.submitting;
    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, -4),
            blurRadius: 18,
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: isBusy ? null : () => _onConfirm(context),
          style: FilledButton.styleFrom(
            backgroundColor: PremiumTokens.accent,
            disabledBackgroundColor:
                PremiumTokens.accent.withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: isBusy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Buyurtmani tasdiqlash',
                      style: PremiumTokens.body(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Iconsax.arrow_right_1,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _onConfirm(BuildContext context) {
    HapticFeedback.mediumImpact();
    if (!state.hasAddress) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Iltimos, yetkazib berish manzilini kiriting'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFEF4444),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    final authState = context.read<AuthCubit>().state;
    if (authState is! AppAuthAuthenticated) return;
    context.read<CheckoutCubit>().submit(authState.userId);
  }
}

// ── Shared card / header widgets ─────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, required this.pt});
  final Widget child;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: PremiumTokens.cardShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.pt,
  });

  final IconData icon;
  final String label;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: PremiumTokens.accent),
        const SizedBox(width: 8),
        Text(
          label,
          style: PremiumTokens.body(
            size: 13,
            weight: FontWeight.w700,
            color: pt.grey,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmt(num value) {
  final s = value.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i != 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

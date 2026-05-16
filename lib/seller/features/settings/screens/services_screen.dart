import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/config/app_config.dart';
import 'package:woody_app/core/widgets/coming_soon_beta_widget.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/shop_service_config.dart';
import '../../../../shared/repositories/seller_services_repository.dart';
import '../../../../shared/widgets/error_state.dart';
import '../bloc/services_bloc.dart';

// Local design tokens — explicit so the screen stays neutral and
// doesn't pick up the M3 surface tint that the seller seed otherwise
// bleeds onto white cards. Plus Jakarta Sans is applied to every
// `Text` directly via `AppFonts.seller`.
const _ink = Color(0xFF1D1D1D);
const _grey = Color(0xFF757575);
const _divider = Color(0xFFEFEFEF);
const _outline = Color(0xFFE3E3E3);
const _terracottaTint = Color(0x14C27A5F);

class SellerServicesScreen extends StatelessWidget {
  const SellerServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ROADMAP A.2 — seller services is mock-only; show a placeholder instead
    // of wiring the mock bloc when the fulfillment flag is off.
    if (!AppConfig.sellerFulfillmentEnabled) {
      return ComingSoonBetaWidget(title: tr('services.title'));
    }
    return BlocProvider(
      create: (_) => ServicesBloc(sl<SellerServicesRepository>())
        ..add(const ServicesRequested()),
      child: const _ServicesView(),
    );
  }
}

// =============================================================================
// 1. View — owns scaffold, snackbar, save button wiring
// =============================================================================
class _ServicesView extends StatelessWidget {
  const _ServicesView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ServicesBloc, ServicesState>(
      listenWhen: (a, b) =>
          a.status != b.status &&
          (b.status == ServicesStatus.saved ||
              b.status == ServicesStatus.failure),
      listener: (context, state) {
        if (state.status == ServicesStatus.saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: _ink,
              behavior: SnackBarBehavior.floating,
              content: Text(
                tr('services.saved_toast'),
                style: TextStyle(fontFamily: AppFonts.seller, 
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          );
        } else if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(
                state.error!,
                style: TextStyle(fontFamily: AppFonts.seller, fontWeight: FontWeight.w600),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: const _ServicesAppBar(),
          body: switch (state.status) {
            ServicesStatus.initial ||
            ServicesStatus.loading =>
              const Center(
                child: CircularProgressIndicator(color: AppColors.terracotta),
              ),
            ServicesStatus.failure when state.configs.isEmpty => ErrorState(
                message: state.error,
                onRetry: () => context
                    .read<ServicesBloc>()
                    .add(const ServicesRequested()),
              ),
            _ => _ServicesForm(configs: state.configs),
          },
          bottomNavigationBar: state.configs.isEmpty
              ? null
              : _SaveBottomBar(
                  saving: state.status == ServicesStatus.saving,
                  onSave: () => context
                      .read<ServicesBloc>()
                      .add(const ServicesSaved()),
                ),
        );
      },
    );
  }
}

// =============================================================================
// 2. App bar — clean white, bold title, no actions
// =============================================================================
class _ServicesAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ServicesAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.lightBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: _ink,
      leading: IconButton(
        icon: const Icon(Iconsax.arrow_left_2, size: 22, color: _ink),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        tr('services.title'),
        style: TextStyle(fontFamily: AppFonts.seller, 
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
// 3. Form — three logical groups, each its own card
// =============================================================================
class _ServicesForm extends StatelessWidget {
  const _ServicesForm({required this.configs});

  final List<ShopServiceConfig> configs;

  ShopServiceConfig? _find(String code) {
    for (final c in configs) {
      if (c.service.code == code) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final freeDelivery = _find('free_delivery');
    final express = _find('express_delivery');
    final assembly = _find('assembly');
    final warranty = _find('warranty');
    final installment = _find('installment');
    final customOrder = _find('custom_order');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        _SectionTitle('Logistika'),
        _Card(
          children: [
            if (freeDelivery != null)
              _ServiceTile(
                config: freeDelivery,
                icon: Iconsax.truck_fast,
                title: 'Bepul yetkazib berish',
                input: _InputSpec.amount(
                  label: tr('services.min_order_amount'),
                  initial: freeDelivery.minOrderAmount,
                  apply: (v, c) =>
                      c.copyWith(minOrderAmount: v, clearMinOrder: v == null),
                ),
              ),
            if (freeDelivery != null && express != null) const _RowDivider(),
            if (express != null)
              _ServiceTile(
                config: express,
                icon: Iconsax.flash_1,
                title: 'Tezkor yetkazish',
              ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionTitle('Xizmatlar va Kafolat'),
        _Card(
          children: [
            if (assembly != null)
              _ServiceTile(
                config: assembly,
                icon: Iconsax.setting_2,
                title: "Yig'ish xizmati",
                input: _InputSpec.amount(
                  label: tr('services.fee_amount'),
                  initial: assembly.feeAmount,
                  apply: (v, c) =>
                      c.copyWith(feeAmount: v, clearFee: v == null),
                ),
              ),
            if (assembly != null && warranty != null) const _RowDivider(),
            if (warranty != null)
              _ServiceTile(
                config: warranty,
                icon: Iconsax.shield_tick,
                title: 'Kafolat',
                input: _InputSpec.months(
                  label: tr('services.warranty_months'),
                  initial: warranty.warrantyMonths,
                  apply: (v, c) => c.copyWith(warrantyMonths: v),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionTitle('Sotuv shartlari'),
        _Card(
          children: [
            if (installment != null)
              _ServiceTile(
                config: installment,
                icon: Iconsax.wallet_money,
                title: "Bo'lib to'lash",
              ),
            if (installment != null && customOrder != null) const _RowDivider(),
            if (customOrder != null)
              _ServiceTile(
                config: customOrder,
                icon: Iconsax.brush_2,
                title: 'Buyurtma asosida',
                subtitle: "Mijoz o'lchamlari bo'yicha yasaladi",
              ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// 4. Section title — bold Jakarta header above each card
// =============================================================================
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: TextStyle(fontFamily: AppFonts.seller, 
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _ink,
          letterSpacing: -0.2,
          height: 1.2,
        ),
      ),
    );
  }
}

// =============================================================================
// 5. Card shell — pure white, 16px radius, soft shadow
// =============================================================================
class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: _divider);
  }
}

// =============================================================================
// 6. Service tile — header row + animated input slot below
// =============================================================================
class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.config,
    required this.icon,
    required this.title,
    this.subtitle,
    this.input,
  });

  final ShopServiceConfig config;
  final IconData icon;
  final String title;
  final String? subtitle;
  final _InputSpec? input;

  @override
  Widget build(BuildContext context) {
    final hasInput = input != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IconBadge(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontFamily: AppFonts.seller, 
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(fontFamily: AppFonts.seller, 
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _grey,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: config.enabled,
                onChanged: (v) => context.read<ServicesBloc>().add(
                      ServiceToggled(service: config.service, enabled: v),
                    ),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.terracotta,
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: hasInput && config.enabled
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _ServiceInput(
                      key: ValueKey(
                        '${config.service.code}.${input!.kind.name}',
                      ),
                      config: config,
                      spec: input!,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _terracottaTint,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: AppColors.terracotta),
    );
  }
}

// =============================================================================
// 7. Input spec — small DSL so each tile declares what its TextField means
// =============================================================================
enum _InputKind { amount, months }

class _InputSpec {
  const _InputSpec._({
    required this.kind,
    required this.label,
    required this.initial,
    required this.apply,
  });

  factory _InputSpec.amount({
    required String label,
    required num? initial,
    required ShopServiceConfig Function(num? value, ShopServiceConfig current)
        apply,
  }) =>
      _InputSpec._(
        kind: _InputKind.amount,
        label: label,
        initial: initial,
        apply: apply,
      );

  factory _InputSpec.months({
    required String label,
    required int? initial,
    required ShopServiceConfig Function(int? value, ShopServiceConfig current)
        apply,
  }) =>
      _InputSpec._(
        kind: _InputKind.months,
        label: label,
        initial: initial,
        apply: (v, c) => apply(v?.toInt(), c),
      );

  final _InputKind kind;
  final String label;
  final num? initial;
  final ShopServiceConfig Function(num? value, ShopServiceConfig current) apply;
}

// =============================================================================
// 8. Service input — controllerful TextField, dispatches config changes
// =============================================================================
class _ServiceInput extends StatefulWidget {
  const _ServiceInput({
    super.key,
    required this.config,
    required this.spec,
  });

  final ShopServiceConfig config;
  final _InputSpec spec;

  @override
  State<_ServiceInput> createState() => _ServiceInputState();
}

class _ServiceInputState extends State<_ServiceInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _initialText());
  }

  String _initialText() {
    final v = widget.spec.initial;
    if (v == null) return '';
    return switch (widget.spec.kind) {
      _InputKind.amount => _formatAmount(v.toInt()),
      _InputKind.months => v.toInt().toString(),
    };
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    final num? parsed = digits.isEmpty ? null : num.tryParse(digits);
    final next = widget.spec.apply(parsed, widget.config);
    context.read<ServicesBloc>().add(ServiceConfigChanged(next));
  }

  @override
  Widget build(BuildContext context) {
    final isAmount = widget.spec.kind == _InputKind.amount;
    final suffix = isAmount ? 'UZS' : tr('services.months_suffix');
    final formatters = <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
      if (isAmount) _ThousandsFormatter(),
    ];
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _outline, width: 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            widget.spec.label,
            style: TextStyle(fontFamily: AppFonts.seller, 
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _grey,
              letterSpacing: 0.1,
            ),
          ),
        ),
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: formatters,
          cursorColor: AppColors.terracotta,
          style: TextStyle(fontFamily: AppFonts.seller, 
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _ink,
            letterSpacing: -0.1,
          ),
          onChanged: _onChanged,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            suffixText: suffix,
            suffixStyle: TextStyle(fontFamily: AppFonts.seller, 
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _grey,
              letterSpacing: 0.2,
            ),
            filled: true,
            fillColor: Colors.white,
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.terracotta,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 9. Save bottom bar — fixed terracotta button with safe-area + soft top shadow
// =============================================================================
class _SaveBottomBar extends StatelessWidget {
  const _SaveBottomBar({required this.saving, required this.onSave});

  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: FilledButton(
              onPressed: saving ? null : onSave,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.terracotta,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.terracotta.withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: TextStyle(fontFamily: AppFonts.seller, 
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              child: saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    )
                  : Text(tr('common.save')),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 10. Thousands formatter — formats `1500000` as `1 500 000` while typing
// =============================================================================
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue();
    }
    final formatted = _formatAmount(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatAmount(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  final n = s.length;
  for (var i = 0; i < n; i++) {
    if (i > 0 && (n - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

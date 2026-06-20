import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/seller_product.dart';
import '../../../../shared/models/tariff.dart';
import '../bloc/add_product_cubit.dart';
import '../controller/product_form_controllers.dart';
import '../data/add_product_repository.dart';
import '../data/attributes_repository.dart';
import '../data/exchange_rate_service.dart';
import '../widgets/product_form/ai_loading_overlay.dart';
import '../widgets/product_form/product_form_app_bar.dart';
import '../widgets/product_form/product_form_body.dart';
import '../widgets/product_form/save_bottom_bar.dart';
import '../widgets/product_form/tariff_blocked_view.dart';
import '../widgets/product_form/wallet_suspended_view.dart';
import '../widgets/tariff_limit_dialog.dart';

/// "Add product" screen — also serves as the edit screen when [initial] is
/// set: the form opens prefilled and saving PATCHes the existing row instead
/// of creating a new one (the backend sends any edit back to moderation).
///
/// ROADMAP B.4 — the original 1,976-line file was split: the UI sections live
/// under `widgets/product_form/`, the text-controller bundle under
/// `controller/`, and this file is now only the BlocProvider shell + the
/// screen-level orchestration (`_save`, tariff-block handling).
class ProductFormScreen extends StatelessWidget {
  const ProductFormScreen({super.key, this.initial});

  /// Product being edited; null opens the blank create form.
  final SellerProduct? initial;

  @override
  Widget build(BuildContext context) {
    // Warm the (large) AI Lottie decode in the background while the seller
    // fills the form, so the loading overlay shows instantly on first tap.
    AiLoadingOverlay.preload();
    final product = initial;
    return BlocProvider(
      create: (_) {
        final cubit = AddProductCubit(
          repository: sl<AddProductRepository>(),
          attributesRepository: sl<AttributesRepository>(),
          exchangeRates: sl<ExchangeRateService>(),
          analytics: sl<AnalyticsService>(),
        );
        product == null ? cubit.loadContext() : cubit.loadForEdit(product);
        return cubit;
      },
      child: _ProductFormView(isEditing: product != null),
    );
  }
}

class _ProductFormView extends StatefulWidget {
  const _ProductFormView({required this.isEditing});

  final bool isEditing;

  @override
  State<_ProductFormView> createState() => _ProductFormViewState();
}

class _ProductFormViewState extends State<_ProductFormView> {
  late final ProductFormControllers _controllers;
  final ImagePicker _picker = ImagePicker();
  bool _tariffPromptShown = false;

  /// Edit mode: the text controllers are free-standing (they never read from
  /// cubit state), so they're written once from the prefilled state on the
  /// first `ready` transition.
  late bool _pendingPrefillSync = widget.isEditing;

  @override
  void initState() {
    super.initState();
    _controllers = ProductFormControllers();
  }

  void _syncControllersFromState(AddProductState state) {
    _controllers.name.text = state.name;
    _controllers.description.text = state.description;
    _controllers.price.text = state.price > 0
        ? state.price.toInt().toString()
        : '';
    _controllers.productionDays.text = state.productionTimeDays;
    _controllers.deliveryPrice.text = state.deliveryPrice > 0
        ? state.deliveryPrice.toInt().toString()
        : '';
    _controllers.installationPrice.text = state.installationPrice > 0
        ? state.installationPrice.toInt().toString()
        : '';
    _controllers.warrantyMonths.text = '${state.warrantyMonths}';
  }

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  void _handleTariffBlocked(BuildContext context, TariffSnapshot? snap) {
    if (_tariffPromptShown || snap == null) return;
    _tariffPromptShown = true;
    final navigator = Navigator.of(context);
    showTariffLimitDialog(context, snapshot: snap).then((_) {
      if (mounted) navigator.maybePop();
    });
  }

  Future<void> _save(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final cubit = context.read<AddProductCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await cubit.submit();
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1D1D1D),
          behavior: SnackBarBehavior.floating,
          content: Text(
            widget.isEditing
                ? 'Mahsulot yangilandi va qayta tekshiruvga yuborildi'
                : "Mahsulot e'lon qilindi",
            style: const TextStyle(
              fontFamily: AppFonts.seller,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
      navigator.maybePop(true);
    } else {
      final err = cubit.state.error;
      if (err != null) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            content: Text(
              err,
              style: const TextStyle(
                fontFamily: AppFonts.seller,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AddProductCubit, AddProductState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == AddProductStatus.tariffBlocked) {
          _handleTariffBlocked(
            context,
            context.read<AddProductCubit>().tariffSnapshot,
          );
        }
        // loadForEdit emits `ready` once, with the form fully prefilled —
        // mirror those values into the free-standing text controllers.
        if (_pendingPrefillSync && state.status == AddProductStatus.ready) {
          _pendingPrefillSync = false;
          _syncControllersFromState(state);
        }
      },
      builder: (context, state) {
        final isLoadingContext =
            state.status == AddProductStatus.loadingContext;
        return Stack(
          children: [
            Scaffold(
              backgroundColor: SellerColors.of(context).background,
              appBar: ProductFormAppBar(editing: widget.isEditing),
              // Render the form shell immediately — categories/plan load in the
              // background. A thin progress line above the body signals the
              // load; the save CTA stays disabled via `canSubmit` until ready.
              body: switch (state.status) {
                AddProductStatus.walletSuspended =>
                  const WalletSuspendedView(),
                AddProductStatus.tariffBlocked => TariffBlockedView(
                  snapshot: context.read<AddProductCubit>().tariffSnapshot,
                ),
                _ => Column(
                  children: [
                    SizedBox(
                      height: 2,
                      child: isLoadingContext
                          ? LinearProgressIndicator(
                              minHeight: 2,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : null,
                    ),
                    Expanded(
                      child: ProductFormBody(
                        controllers: _controllers,
                        picker: _picker,
                        state: state,
                      ),
                    ),
                  ],
                ),
              },
              bottomNavigationBar:
                  state.status == AddProductStatus.tariffBlocked ||
                      state.status == AddProductStatus.walletSuspended
                  ? null
                  : SaveBottomBar(
                      enabled:
                          state.canSubmit &&
                          state.status != AddProductStatus.saving,
                      busy: state.status == AddProductStatus.saving,
                      onSave: () => _save(context),
                      editing: widget.isEditing,
                    ),
            ),
            // Blocks the whole screen (incl. app bar + save bar) while the AI
            // request runs, so nothing behind it can be edited.
            AiLoadingOverlay(visible: state.isAiBusy),
          ],
        );
      },
    );
  }
}

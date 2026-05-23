import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/tariff.dart';
import '../bloc/add_product_cubit.dart';
import '../controller/product_form_controllers.dart';
import '../data/add_product_repository.dart';
import '../data/attributes_repository.dart';
import '../widgets/product_form/product_form_app_bar.dart';
import '../widgets/product_form/product_form_body.dart';
import '../widgets/product_form/save_bottom_bar.dart';
import '../widgets/product_form/tariff_blocked_view.dart';
import '../widgets/tariff_limit_dialog.dart';

/// "Add product" screen.
///
/// ROADMAP B.4 — the original 1,976-line file was split: the UI sections live
/// under `widgets/product_form/`, the text-controller bundle under
/// `controller/`, and this file is now only the BlocProvider shell + the
/// screen-level orchestration (`_save`, tariff-block handling).
class ProductFormScreen extends StatelessWidget {
  const ProductFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AddProductCubit(
        repository: sl<AddProductRepository>(),
        attributesRepository: sl<AttributesRepository>(),
        analytics: sl<AnalyticsService>(),
      )..loadContext(),
      child: const _ProductFormView(),
    );
  }
}

class _ProductFormView extends StatefulWidget {
  const _ProductFormView();

  @override
  State<_ProductFormView> createState() => _ProductFormViewState();
}

class _ProductFormViewState extends State<_ProductFormView> {
  late final ProductFormControllers _controllers;
  final ImagePicker _picker = ImagePicker();
  bool _tariffPromptShown = false;

  @override
  void initState() {
    super.initState();
    _controllers = ProductFormControllers();
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
        const SnackBar(
          backgroundColor: Color(0xFF1D1D1D),
          behavior: SnackBarBehavior.floating,
          content: Text(
            "Mahsulot e'lon qilindi",
            style: TextStyle(
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
      },
      builder: (context, state) {
        final isLoadingContext = state.status == AddProductStatus.loadingContext;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: const ProductFormAppBar(),
          // Render the form shell immediately — categories/plan load in the
          // background. A thin progress line above the body signals the
          // load; the save CTA stays disabled via `canSubmit` until ready.
          body: switch (state.status) {
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
          bottomNavigationBar: state.status == AddProductStatus.tariffBlocked
              ? null
              : SaveBottomBar(
                  enabled: state.canSubmit &&
                      state.status != AddProductStatus.saving,
                  busy: state.status == AddProductStatus.saving,
                  onSave: () => _save(context),
                ),
        );
      },
    );
  }
}

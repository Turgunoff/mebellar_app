import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:woody_app/config/app_config.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/widgets/coming_soon_beta_widget.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/repositories/shop_settings_repository.dart';
import '../../../../shared/widgets/error_state.dart';
import '../bloc/shop_settings_bloc.dart';
import '../widgets/shop_settings/settings_app_bar.dart';
import '../widgets/shop_settings/settings_form.dart';
import '../widgets/shop_settings/settings_form_kit.dart';
import '../widgets/shop_settings/settings_save_bar.dart';

/// Seller shop-settings screen.
///
/// ROADMAP B.4 — the original 1,355-line file was split: each settings
/// section lives under `widgets/shop_settings/`, and this file is the
/// BlocProvider shell + the status-driven Scaffold.
class ShopSettingsScreen extends StatelessWidget {
  const ShopSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ROADMAP A.2 — shop settings is mock-only; show a placeholder instead of
    // wiring the mock bloc when the fulfillment flag is off.
    if (!AppConfig.sellerFulfillmentEnabled) {
      return ComingSoonBetaWidget(title: tr('shop_settings.title'));
    }
    return BlocProvider(
      create: (_) => ShopSettingsBloc(sl<ShopSettingsRepository>())
        ..add(const ShopSettingsRequested()),
      child: const _ShopSettingsView(),
    );
  }
}

class _ShopSettingsView extends StatelessWidget {
  const _ShopSettingsView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ShopSettingsBloc, ShopSettingsState>(
      listenWhen: (a, b) =>
          a.status != b.status &&
          (b.status == ShopSettingsStatus.saved ||
              b.status == ShopSettingsStatus.failure),
      listener: (context, state) {
        if (state.status == ShopSettingsStatus.saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: kInk,
              behavior: SnackBarBehavior.floating,
              content: Text(
                tr('shop_settings.saved_toast'),
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
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
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: const ShopSettingsAppBar(),
          body: switch (state.status) {
            ShopSettingsStatus.initial ||
            ShopSettingsStatus.loading =>
              const Center(
                child: CircularProgressIndicator(
                  color: AppColors.terracotta,
                ),
              ),
            ShopSettingsStatus.failure when state.settings == null =>
              ErrorState(
                message: state.error,
                onRetry: () => context
                    .read<ShopSettingsBloc>()
                    .add(const ShopSettingsRequested()),
              ),
            _ => SettingsForm(state: state),
          },
          bottomNavigationBar: state.settings == null
              ? null
              : SettingsSaveBar(
                  saving: state.status == ShopSettingsStatus.saving,
                  onSave: () => context
                      .read<ShopSettingsBloc>()
                      .add(const ShopSettingsSaved()),
                ),
        );
      },
    );
  }
}

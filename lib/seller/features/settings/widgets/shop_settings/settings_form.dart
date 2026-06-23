import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../../core/logging/talker.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import '../../../../../shared/models/shop_settings.dart';
import '../../../../../shared/models/working_hours.dart';
import '../../../../../shared/utils/image_upload.dart';
import '../../../../../shared/widgets/image_crop_screen.dart';
import '../../../../../customer/features/checkout/screens/map_address_picker_screen.dart';
import '../../bloc/shop_settings_bloc.dart';
import '../brand_color_picker.dart';
import 'basic_info_card.dart';
import 'brand_location_card.dart';
import 'cover_header.dart';
import 'visibility_card.dart';
import 'working_hours_card.dart';

/// Scrollable shop-settings form. Owns the six text controllers and dispatches
/// partial `ShopSettingsBloc` events as the seller edits each section.
class SettingsForm extends StatefulWidget {
  const SettingsForm({super.key, required this.state});

  final ShopSettingsState state;

  @override
  State<SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<SettingsForm> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _telegram;

  @override
  void initState() {
    super.initState();
    final s = widget.state.settings!;
    _name = TextEditingController(text: s.name);
    _description = TextEditingController(text: s.description);
    _phone = TextEditingController(text: s.contactPhone ?? '');
    _email = TextEditingController(text: s.contactEmail ?? '');
    _telegram = TextEditingController(text: s.telegramUsername ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    _email.dispose();
    _telegram.dispose();
    super.dispose();
  }

  void _emitBasics() {
    context.read<ShopSettingsBloc>().add(
      ShopSettingsBasicsChanged(
        name: _name.text,
        description: _description.text,
        contactPhone: _phone.text,
        contactEmail: _email.text,
        telegramUsername: _telegram.text,
      ),
    );
  }

  /// Opens the shared Yandex map picker (the same one the onboarding flow and
  /// checkout use) and writes the chosen address + coordinates back in one
  /// `ShopSettingsAddressChanged` — so the persisted `latitude`/`longitude`
  /// always match the displayed address.
  Future<void> _pickAddress() async {
    final s = widget.state.settings;
    if (s == null) return;
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/map-address-picker'),
        builder: (_) => MapAddressPickerScreen(
          initialAddress: s.address,
          initialLatitude: s.lat,
          initialLongitude: s.lng,
          accent: AppColors.sellerPrimary,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    context.read<ShopSettingsBloc>().add(
      ShopSettingsAddressChanged(
        address: picked.address,
        lat: picked.latitude,
        lng: picked.longitude,
      ),
    );
  }

  /// Entry point for a logo/cover tap: with no image yet it goes straight to
  /// the picker; with an existing image it offers replace / remove.
  Future<void> _assetTap(String kind) async {
    final s = widget.state.settings;
    if (s == null) return;
    final url = kind == 'logo' ? s.logoUrl : s.coverUrl;
    if (url == null || url.isEmpty) {
      await _pickAsset(kind);
      return;
    }

    final c = SellerColors.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Text(
              tr(
                kind == 'logo'
                    ? 'shop_settings.asset_logo_title'
                    : 'shop_settings.asset_cover_title',
              ),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 6),
            ListTile(
              leading: const Icon(
                Iconsax.camera,
                color: AppColors.sellerPrimary,
              ),
              title: Text(
                tr('shop_settings.asset_replace'),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
              onTap: () => Navigator.of(sheetContext).pop('replace'),
            ),
            ListTile(
              leading: Icon(Iconsax.trash, color: Colors.red.shade600),
              title: Text(
                tr('shop_settings.asset_remove'),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600,
                ),
              ),
              onTap: () => Navigator.of(sheetContext).pop('remove'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'replace':
        await _pickAsset(kind);
      case 'remove':
        context.read<ShopSettingsBloc>().add(ShopSettingsAssetRemoved(kind));
    }
  }

  Future<void> _pickAsset(String kind) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      talker.info('[shop-settings] pick asset kind=$kind');
      final picked = await ImageUploadHelper().pick(
        source: ImageSource.gallery,
      );
      if (picked == null) {
        talker.info('[shop-settings] pick cancelled kind=$kind');
        return;
      }
      if (!mounted) return;
      talker.info(
        '[shop-settings] picked kind=$kind ext=${picked.extension} '
        'bytes=${picked.bytes}',
      );
      // Telegram-style fit step: the seller zooms/pans the photo inside the
      // exact frame it will be displayed in (circle for the logo, banner
      // ratio for the cover) before anything is uploaded.
      final cropped = await openImageCropScreen(
        context,
        file: picked.file,
        aspectRatio: kind == 'logo' ? 1 : 2.4,
        circle: kind == 'logo',
        maxOutputWidth: kind == 'logo' ? 1024 : 1600,
      );
      if (cropped == null) {
        talker.info('[shop-settings] crop cancelled kind=$kind');
        return;
      }
      if (!mounted) return;
      context.read<ShopSettingsBloc>().add(
        ShopSettingsAssetUploaded(
          kind: kind,
          file: cropped,
          fileExtension: 'png',
        ),
      );
    } on ImagePickError catch (e, st) {
      talker.handle(e, st, '[shop-settings] image pick error kind=$kind');
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e, st) {
      talker.handle(e, st, '[shop-settings] pick asset failed kind=$kind');
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _pickColor() async {
    final s = widget.state.settings!;
    final hex = await pickBrandColor(context, initial: s.brandColor);
    if (hex == null || !mounted) return;
    context.read<ShopSettingsBloc>().add(ShopSettingsBrandColorChanged(hex));
  }

  void _changeDayHours(DayOfWeek day, DayHours hours) {
    context.read<ShopSettingsBloc>().add(
      ShopSettingsHoursChanged(day: day, hours: hours),
    );
  }

  void _changeVisibility(bool isPublic) {
    context.read<ShopSettingsBloc>().add(
      ShopSettingsVisibilityChanged(
        isPublic ? ShopVisibility.public : ShopVisibility.hidden,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final s = state.settings!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        CoverHeader(
          coverUrl: s.coverUrl,
          logoUrl: s.logoUrl,
          uploadingKind: state.uploadingKind,
          onTapCover: () => _assetTap('cover'),
          onTapLogo: () => _assetTap('logo'),
        ),
        const SizedBox(height: 20),
        BasicInfoCard(
          nameController: _name,
          descriptionController: _description,
          phoneController: _phone,
          emailController: _email,
          telegramController: _telegram,
          onChanged: _emitBasics,
        ),
        const SizedBox(height: 20),
        BrandLocationCard(
          brandHex: s.brandColor,
          brandColor: s.brandColorValue,
          onPickColor: _pickColor,
          address: s.address,
          onPickAddress: _pickAddress,
        ),
        const SizedBox(height: 20),
        WorkingHoursCard(hours: s.workingHours, onDayChanged: _changeDayHours),
        const SizedBox(height: 20),
        VisibilityCard(isPublic: s.isPublic, onChanged: _changeVisibility),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../../customer/features/profile/addresses/screens/region_picker_screen.dart';
import '../../../../../shared/models/shop_settings.dart';
import '../../../../../shared/models/working_hours.dart';
import '../../../../../shared/utils/image_upload.dart';
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
  late final TextEditingController _street;

  @override
  void initState() {
    super.initState();
    final s = widget.state.settings!;
    _name = TextEditingController(text: s.name.uz ?? '');
    _description = TextEditingController(text: s.description.uz ?? '');
    _phone = TextEditingController(text: s.contactPhone ?? '');
    _email = TextEditingController(text: s.contactEmail ?? '');
    _telegram = TextEditingController(text: s.telegramUsername ?? '');
    _street = TextEditingController(text: s.streetLine);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    _email.dispose();
    _telegram.dispose();
    _street.dispose();
    super.dispose();
  }

  void _emitBasics() {
    // Only `nameUz` / `descriptionUz` are sent; the bloc handler preserves
    // RU/EN via `?? s.name.ru` fallbacks. Phone/email/telegram, however, are
    // assigned directly in the handler — passing null would nuke them, so we
    // always send the current controller values.
    context.read<ShopSettingsBloc>().add(ShopSettingsBasicsChanged(
          nameUz: _name.text,
          descriptionUz: _description.text,
          contactPhone: _phone.text,
          contactEmail: _email.text,
          telegramUsername: _telegram.text,
        ));
  }

  void _emitStreet() {
    context.read<ShopSettingsBloc>().add(
          ShopSettingsAddressChanged(streetLine: _street.text),
        );
  }

  Future<void> _pickAsset(String kind) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImageUploadHelper().pick(
        source: ImageSource.gallery,
      );
      if (picked == null || !mounted) return;
      context.read<ShopSettingsBloc>().add(
            ShopSettingsAssetUploaded(
              kind: kind,
              file: picked.file,
              fileExtension: picked.extension,
            ),
          );
    } on ImagePickError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _pickRegion() async {
    final result = await Navigator.of(context).push<RegionPickerResult>(
      MaterialPageRoute(builder: (_) => const RegionPickerScreen()),
    );
    if (result == null || !mounted) return;
    context.read<ShopSettingsBloc>().add(
          ShopSettingsAddressChanged(
            region: result.region,
            city: result.city,
            district: result.district,
            clearDistrict: result.district == null,
          ),
        );
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
    final lang = context.locale.languageCode;

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
          onTapCover: () => _pickAsset('cover'),
          onTapLogo: () => _pickAsset('logo'),
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
          regionLabel: s.region.name.get(lang),
          citySublabel: [
            s.city.name.get(lang),
            if (s.district != null) s.district!.name.get(lang),
          ].join(', '),
          onPickRegion: _pickRegion,
          streetController: _street,
          onStreetChanged: _emitStreet,
        ),
        const SizedBox(height: 20),
        WorkingHoursCard(
          hours: s.workingHours,
          onDayChanged: _changeDayHours,
        ),
        const SizedBox(height: 20),
        VisibilityCard(
          isPublic: s.isPublic,
          onChanged: _changeVisibility,
        ),
      ],
    );
  }
}

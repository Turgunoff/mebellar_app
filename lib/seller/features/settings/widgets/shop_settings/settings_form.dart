import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/logging/talker.dart';
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
  late final TextEditingController _address;

  @override
  void initState() {
    super.initState();
    final s = widget.state.settings!;
    _name = TextEditingController(text: s.name);
    _description = TextEditingController(text: s.description);
    _phone = TextEditingController(text: s.contactPhone ?? '');
    _email = TextEditingController(text: s.contactEmail ?? '');
    _telegram = TextEditingController(text: s.telegramUsername ?? '');
    _address = TextEditingController(text: s.address);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    _email.dispose();
    _telegram.dispose();
    _address.dispose();
    super.dispose();
  }

  void _emitBasics() {
    context.read<ShopSettingsBloc>().add(ShopSettingsBasicsChanged(
          name: _name.text,
          description: _description.text,
          contactPhone: _phone.text,
          contactEmail: _email.text,
          telegramUsername: _telegram.text,
        ));
  }

  void _emitAddress() {
    context.read<ShopSettingsBloc>().add(
          ShopSettingsAddressChanged(address: _address.text),
        );
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
      context.read<ShopSettingsBloc>().add(
            ShopSettingsAssetUploaded(
              kind: kind,
              file: picked.file,
              fileExtension: picked.extension,
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
          addressController: _address,
          onAddressChanged: _emitAddress,
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

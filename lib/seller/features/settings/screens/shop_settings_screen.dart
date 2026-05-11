import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../customer/features/profile/addresses/screens/region_picker_screen.dart';
import '../../../../shared/models/shop_settings.dart';
import '../../../../shared/models/working_hours.dart';
import '../../../../shared/repositories/shop_settings_repository.dart';
import '../../../../shared/utils/image_upload.dart';
import '../../../../shared/widgets/error_state.dart';
import '../bloc/shop_settings_bloc.dart';
import '../widgets/brand_color_picker.dart';

// Local tokens — kept here so the screen reads top-to-bottom without
// chasing theme indirection. Plus Jakarta Sans is applied to every
// `Text` explicitly via `AppFonts.seller` so the surface
// is immune to the M3 surface tint that the teal seller seed otherwise
// bleeds onto neutral backgrounds.
const _ink = Color(0xFF1D1D1D);
const _grey = Color(0xFF757575);
const _greyMid = Color(0xFFBDBDBD);
const _divider = Color(0xFFEFEFEF);
const _outline = Color(0xFFE3E3E3);
const _fillSoft = Color(0xFFF7F7F7);
const _terracottaTint = Color(0x14C27A5F);

class ShopSettingsScreen extends StatelessWidget {
  const ShopSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              backgroundColor: _ink,
              behavior: SnackBarBehavior.floating,
              content: Text(
                tr('shop_settings.saved_toast'),
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
                style: TextStyle(fontFamily: AppFonts.seller, 
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
          appBar: const _SettingsAppBar(),
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
            _ => _SettingsForm(state: state),
          },
          bottomNavigationBar: state.settings == null
              ? null
              : _SaveBottomBar(
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

// =============================================================================
// 1. App bar — back arrow + bold title, transparent so cover flows under it
// =============================================================================
class _SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SettingsAppBar();

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
        tr('shop_settings.title'),
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
// 2. Form — owns text controllers, dispatches partial bloc events on edit
// =============================================================================
class _SettingsForm extends StatefulWidget {
  const _SettingsForm({required this.state});

  final ShopSettingsState state;

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
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
    // RU/EN via `?? s.name.ru` fallbacks. Phone/email/telegram, however,
    // are assigned directly in the handler — passing null would nuke
    // them, so we always send the current controller values.
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
    context
        .read<ShopSettingsBloc>()
        .add(ShopSettingsBrandColorChanged(hex));
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
        _CoverHeader(
          coverUrl: s.coverUrl,
          logoUrl: s.logoUrl,
          uploadingKind: state.uploadingKind,
          onTapCover: () => _pickAsset('cover'),
          onTapLogo: () => _pickAsset('logo'),
        ),
        const SizedBox(height: 20),
        _BasicInfoCard(
          nameController: _name,
          descriptionController: _description,
          phoneController: _phone,
          emailController: _email,
          telegramController: _telegram,
          onChanged: _emitBasics,
        ),
        const SizedBox(height: 20),
        _BrandLocationCard(
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
        _WorkingHoursCard(
          hours: s.workingHours,
          onDayChanged: _changeDayHours,
        ),
        const SizedBox(height: 20),
        _VisibilityCard(
          isPublic: s.isPublic,
          onChanged: _changeVisibility,
        ),
      ],
    );
  }
}

// =============================================================================
// 3. Section title — bold Jakarta header above each card
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
// 4. Form card — pure white, 16px radius, soft shadow
// =============================================================================
class _FormCard extends StatelessWidget {
  const _FormCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
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
      child: child,
    );
  }
}

// =============================================================================
// 5. Cover header — full-width cover (140) + overlapping circular logo +
//    "Logoni almashtirish" outlined button beside it
// =============================================================================
class _CoverHeader extends StatelessWidget {
  const _CoverHeader({
    required this.coverUrl,
    required this.logoUrl,
    required this.uploadingKind,
    required this.onTapCover,
    required this.onTapLogo,
  });

  final String? coverUrl;
  final String? logoUrl;
  final String? uploadingKind;
  final VoidCallback onTapCover;
  final VoidCallback onTapLogo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _CoverImage(
                url: coverUrl,
                uploading: uploadingKind == 'cover',
                onTap: onTapCover,
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _CoverEditPill(onTap: onTapCover),
              ),
              Positioned(
                left: 12,
                bottom: 0,
                child: _LogoAvatar(
                  url: logoUrl,
                  uploading: uploadingKind == 'logo',
                  onTap: onTapLogo,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: _ChangeLogoButton(onTap: onTapLogo),
        ),
      ],
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({
    required this.url,
    required this.uploading,
    required this.onTap,
  });

  final String? url;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      bottom: 40,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Material(
              color: _fillSoft,
              child: InkWell(
                onTap: onTap,
                child: url == null || url!.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Iconsax.gallery_add,
                              size: 28,
                              color: _greyMid,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tr('shop_settings.upload_cover'),
                              style: TextStyle(fontFamily: AppFonts.seller, 
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: url!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            const ColoredBox(color: _fillSoft),
                      ),
              ),
            ),
            if (uploading)
              const ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoverEditPill extends StatelessWidget {
  const _CoverEditPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(999),
      elevation: 1,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.camera, size: 14, color: _ink),
              const SizedBox(width: 6),
              Text(
                tr('shop_settings.upload_cover'),
                style: TextStyle(fontFamily: AppFonts.seller, 
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoAvatar extends StatelessWidget {
  const _LogoAvatar({
    required this.url,
    required this.uploading,
    required this.onTap,
  });

  final String? url;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: _fillSoft,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url == null || url!.isEmpty)
                const Center(
                  child: Icon(
                    Iconsax.shop,
                    size: 28,
                    color: AppColors.terracotta,
                  ),
                )
              else
                CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const Center(
                    child: Icon(
                      Iconsax.shop,
                      size: 28,
                      color: AppColors.terracotta,
                    ),
                  ),
                ),
              if (uploading)
                const ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangeLogoButton extends StatelessWidget {
  const _ChangeLogoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _outline, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Iconsax.camera,
                  size: 16,
                  color: AppColors.terracotta,
                ),
                const SizedBox(width: 8),
                Text(
                  tr('shop_settings.upload_logo'),
                  style: TextStyle(fontFamily: AppFonts.seller, 
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.terracotta,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 6. Basic info card — name, description, phone, email, telegram
// =============================================================================
class _BasicInfoCard extends StatelessWidget {
  const _BasicInfoCard({
    required this.nameController,
    required this.descriptionController,
    required this.phoneController,
    required this.emailController,
    required this.telegramController,
    required this.onChanged,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController telegramController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(tr('shop_settings.basics_title')),
        _FormCard(
          child: Column(
            children: [
              _FormField(
                controller: nameController,
                label: tr('onboarding.shop_name'),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 14),
              _FormField(
                controller: descriptionController,
                label: tr('onboarding.shop_description'),
                minLines: 3,
                maxLines: 5,
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 14),
              _FormField(
                controller: phoneController,
                label: tr('onboarding.contact_phone'),
                keyboardType: TextInputType.phone,
                hint: '+998 90 111 22 33',
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 14),
              _FormField(
                controller: emailController,
                label: tr('onboarding.contact_email'),
                keyboardType: TextInputType.emailAddress,
                hint: 'info@example.uz',
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 14),
              _FormField(
                controller: telegramController,
                label: tr('onboarding.telegram'),
                hint: 'username',
                prefix: '@',
                onChanged: (_) => onChanged(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 7. Brand & location card — color tile + region picker + street field
// =============================================================================
class _BrandLocationCard extends StatelessWidget {
  const _BrandLocationCard({
    required this.brandHex,
    required this.brandColor,
    required this.onPickColor,
    required this.regionLabel,
    required this.citySublabel,
    required this.onPickRegion,
    required this.streetController,
    required this.onStreetChanged,
  });

  final String? brandHex;
  final Color? brandColor;
  final VoidCallback onPickColor;
  final String regionLabel;
  final String citySublabel;
  final VoidCallback onPickRegion;
  final TextEditingController streetController;
  final VoidCallback onStreetChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(tr('shop_settings.brand_color')),
        _FormCard(
          child: Column(
            children: [
              _ListRow(
                onTap: onPickColor,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: brandColor ?? AppColors.terracotta,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _outline, width: 1),
                  ),
                ),
                title: tr('shop_settings.brand_color'),
                subtitle: brandHex ?? '#5E35B1',
                trailing: const Icon(
                  Iconsax.colorfilter,
                  size: 18,
                  color: _greyMid,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, thickness: 1, color: _divider),
              ),
              _ListRow(
                onTap: onPickRegion,
                leading: const _IconTile(icon: Iconsax.location),
                title: regionLabel,
                subtitle: citySublabel.isEmpty ? '—' : citySublabel,
                trailing: const Icon(
                  Iconsax.arrow_right_3,
                  size: 18,
                  color: _greyMid,
                ),
              ),
              const SizedBox(height: 14),
              _FormField(
                controller: streetController,
                label: tr('address.street'),
                hint: "Ko'cha, uy raqami yoki mo'ljal",
                onChanged: (_) => onStreetChanged(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _terracottaTint,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: AppColors.terracotta),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontFamily: AppFonts.seller, 
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontFamily: AppFonts.seller, 
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 8. Working hours card — 7 day rows with proper " - " separator + switch
// =============================================================================
class _WorkingHoursCard extends StatelessWidget {
  const _WorkingHoursCard({
    required this.hours,
    required this.onDayChanged,
  });

  final WeeklyHours hours;
  final void Function(DayOfWeek day, DayHours hours) onDayChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(tr('shop_settings.hours_title')),
        _FormCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < DayOfWeek.values.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, thickness: 1, color: _divider),
                _DayRow(
                  day: DayOfWeek.values[i],
                  hours: hours[DayOfWeek.values[i]],
                  onChanged: (next) =>
                      onDayChanged(DayOfWeek.values[i], next),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.hours,
    required this.onChanged,
  });

  final DayOfWeek day;
  final DayHours hours;
  final ValueChanged<DayHours> onChanged;

  Future<void> _pickTime(BuildContext context, {required bool isOpen}) async {
    final initial = _parseHHmm(isOpen ? hours.open : hours.close) ??
        const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.terracotta,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _ink,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    final formatted = _formatHHmm(picked);
    onChanged(
      isOpen
          ? hours.copyWith(open: formatted, closed: false)
          : hours.copyWith(close: formatted, closed: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              tr('day.${day.code}'),
              style: TextStyle(fontFamily: AppFonts.seller, 
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ink,
                letterSpacing: -0.1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: hours.closed
                ? Text(
                    tr('shop_settings.closed'),
                    style: TextStyle(fontFamily: AppFonts.seller, 
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _greyMid,
                    ),
                  )
                : Row(
                    children: [
                      _TimePill(
                        label: hours.open ?? '09:00',
                        onTap: () => _pickTime(context, isOpen: true),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '-',
                        style: TextStyle(fontFamily: AppFonts.seller, 
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _greyMid,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TimePill(
                        label: hours.close ?? '18:00',
                        onTap: () => _pickTime(context, isOpen: false),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: !hours.closed,
            onChanged: (open) {
              onChanged(
                open
                    ? DayHours(
                        open: hours.open ?? '09:00',
                        close: hours.close ?? '18:00',
                      )
                    : DayHours.closedDay,
              );
            },
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.terracotta,
          ),
        ],
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: _fillSoft,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline, width: 1),
            ),
            child: Text(
              label,
              style: TextStyle(fontFamily: AppFonts.seller, 
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ink,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 9. Visibility card — switch with title + subtitle, terracotta accent
// =============================================================================
class _VisibilityCard extends StatelessWidget {
  const _VisibilityCard({required this.isPublic, required this.onChanged});

  final bool isPublic;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(tr('shop_settings.visibility_title')),
        _FormCard(
          child: Row(
            children: [
              _IconTile(
                icon: isPublic ? Iconsax.eye : Iconsax.eye_slash,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(isPublic
                          ? 'shop_settings.public'
                          : 'shop_settings.hidden'),
                      style: TextStyle(fontFamily: AppFonts.seller, 
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(isPublic
                          ? 'shop_settings.public_hint'
                          : 'shop_settings.hidden_hint'),
                      style: TextStyle(fontFamily: AppFonts.seller, 
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _grey,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isPublic,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.terracotta,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 10. Form field — label above outlined input, terracotta focus border
// =============================================================================
class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    this.hint,
    this.prefix,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? prefix;
  final TextInputType? keyboardType;
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _outline, width: 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(
            label,
            style: TextStyle(fontFamily: AppFonts.seller, 
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _grey,
              letterSpacing: 0.1,
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          minLines: minLines,
          maxLines: maxLines,
          cursorColor: AppColors.terracotta,
          style: TextStyle(fontFamily: AppFonts.seller, 
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _ink,
            letterSpacing: -0.1,
          ),
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            hintText: hint,
            hintStyle: TextStyle(fontFamily: AppFonts.seller, 
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _greyMid,
            ),
            prefixText: prefix,
            prefixStyle: TextStyle(fontFamily: AppFonts.seller, 
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _greyMid,
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
// 11. Bottom bar — fixed terracotta save button with safe-area + top divider
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
// 12. Time helpers — HH:mm parsing + formatting for the day rows
// =============================================================================
TimeOfDay? _parseHHmm(String? value) {
  if (value == null || !value.contains(':')) return null;
  final parts = value.split(':');
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return TimeOfDay(hour: h, minute: m);
}

String _formatHHmm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

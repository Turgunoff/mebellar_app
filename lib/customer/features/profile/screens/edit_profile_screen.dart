import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/storage/r2_upload_client.dart';
import '../../../../shared/utils/image_upload.dart';
import '../../../../shared/utils/phone_format.dart';
import '../../../../shared/widgets/image_crop_screen.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../cubit/profile_cubit.dart';
import '../widgets/user_card.dart';

/// Full-screen profile editor — avatar, name, email; phone is shown locked
/// (it's the login identity). Expects an ancestor `BlocProvider<ProfileCubit>`.
///
/// The avatar is uploaded to the public `user-avatars` R2 bucket and the
/// returned permanent URL is persisted via PATCH `/me` together with the
/// name/email — a single round-trip on save.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});

  final ProfileState profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;

  PickedImage? _picked;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.name ?? '');
    _emailCtrl = TextEditingController(text: widget.profile.email ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImageUploadHelper().pick(
        source: ImageSource.gallery,
      );
      if (picked == null || !mounted) return;
      // Telegram-style fit step: zoom/pan inside the circular frame the
      // avatar is shown in everywhere — same flow as the seller logo.
      final cropped = await openImageCropScreen(
        context,
        file: picked.file,
        aspectRatio: 1,
        circle: true,
        maxOutputWidth: 1024,
      );
      if (cropped == null || !mounted) return;
      setState(
        () => _picked = PickedImage(
          file: cropped,
          extension: 'png',
          bytes: cropped.lengthSync(),
        ),
      );
    } on ImagePickError catch (e, st) {
      appLog.handle(e, st, '[edit-profile] avatar pick error');
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e, st) {
      appLog.handle(e, st, '[edit-profile] avatar pick failed');
      messenger.showSnackBar(
        SnackBar(content: Text(tr('profile.avatar_pick_failed'))),
      );
    }
  }

  Future<String> _uploadAvatar(PickedImage picked) async {
    final userId = widget.profile.id;
    final bytes = await picked.file.readAsBytes();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final result = await sl<R2UploadClient>().upload(
      bucket: R2Bucket.userAvatars,
      path: '$userId/$ts.${picked.extension}',
      bytes: bytes,
      contentType: _contentType(picked.extension),
    );
    final url = result.publicUrl;
    if (url == null || url.isEmpty) {
      // Bytes are in R2 but the server returned no public URL — the
      // `user-avatars` public base isn't configured. Fail loudly rather than
      // silently saving the profile without the new photo.
      throw StateError('avatar public_url missing — R2 base not configured');
    }
    return url;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final cubit = context.read<ProfileCubit>();
    try {
      String? avatarUrl;
      if (_picked != null) {
        avatarUrl = await _uploadAvatar(_picked!);
      }
      final email = _emailCtrl.text.trim();
      await cubit.updateProfile(
        name: _nameCtrl.text.trim(),
        email: email.isEmpty ? null : email,
        avatarUrl: avatarUrl,
      );
      if (!mounted) return;
      navigator.pop();
    } catch (e, st) {
      appLog.handle(e, st, '[edit-profile] save failed');
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(tr('profile.save_failed_retry'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Scaffold(
      backgroundColor: pt.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          tr('profile.edit_title'),
          style: PremiumTokens.display(size: 20, letterSpacing: -0.3),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Center(
              child: _EditableAvatar(
                profile: widget.profile,
                picked: _picked,
                onTap: _saving ? null : _pickAvatar,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _saving ? null : _pickAvatar,
                icon: const Icon(Iconsax.gallery_edit, size: 16),
                label: Text(tr('profile.change_photo')),
                style: TextButton.styleFrom(
                  foregroundColor: PremiumTokens.accent,
                  textStyle: PremiumTokens.body(
                    size: 13,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Label(pt: pt, text: tr('profile.label_full_name')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              style: PremiumTokens.body(size: 14, weight: FontWeight.w500),
              validator: (v) =>
                  (v == null || v.trim().length < 2)
                  ? tr('profile.validation_name_required')
                  : null,
              decoration: _fieldDecoration(
                pt,
                hint: tr('profile.hint_full_name'),
                prefix: Iconsax.user,
              ),
            ),
            const SizedBox(height: 16),
            _Label(pt: pt, text: tr('profile.label_email_optional')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailCtrl,
              enabled: !_saving,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              style: PremiumTokens.body(size: 14, weight: FontWeight.w500),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null; // optional
                return _emailRe.hasMatch(t)
                    ? null
                    : tr('profile.validation_email_invalid');
              },
              onFieldSubmitted: (_) => _submit(),
              decoration: _fieldDecoration(
                pt,
                hint: 'siz@example.com',
                prefix: Iconsax.sms,
              ),
            ),
            const SizedBox(height: 16),
            _Label(pt: pt, text: tr('profile.label_phone')),
            const SizedBox(height: 8),
            _LockedPhoneField(pt: pt, phone: widget.profile.phone ?? ''),
            const SizedBox(height: 6),
            Text(
              tr('profile.phone_locked_note'),
              style: PremiumTokens.body(size: 12, color: pt.greyLight),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: PremiumTokens.accent,
                  disabledBackgroundColor: PremiumTokens.accent.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        tr('profile.save'),
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
      ),
    );
  }

  InputDecoration _fieldDecoration(
    PremiumTokens pt, {
    required String hint,
    IconData? prefix,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: pt.divider),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: PremiumTokens.body(size: 14, color: pt.greyLight),
      prefixIcon: prefix == null
          ? null
          : Icon(prefix, size: 18, color: pt.grey),
      filled: true,
      fillColor: pt.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PremiumTokens.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.error,
          width: 1.5,
        ),
      ),
    );
  }
}

String _contentType(String ext) {
  switch (ext.toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    default:
      return 'image/jpeg';
  }
}

class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({
    required this.profile,
    required this.picked,
    required this.onTap,
  });

  final ProfileState profile;
  final PickedImage? picked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ProfileAvatar(
            avatarUrl: profile.avatarUrl,
            name: profile.hasName ? profile.name : null,
            localImage: picked?.file,
            size: 104,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: PremiumTokens.accent,
                shape: BoxShape.circle,
                border: Border.all(color: pt.background, width: 3),
              ),
              child: const Icon(Iconsax.camera, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.pt, required this.text});

  final PremiumTokens pt;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: PremiumTokens.body(
        size: 13,
        weight: FontWeight.w600,
        color: pt.grey,
      ),
    );
  }
}

/// Read-only phone display styled as an intentionally locked field.
class _LockedPhoneField extends StatelessWidget {
  const _LockedPhoneField({required this.pt, required this.phone});

  final PremiumTokens pt;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pt.divider),
      ),
      child: Row(
        children: [
          Icon(Iconsax.call, size: 18, color: pt.greyLight),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              phone.isEmpty ? '—' : formatUzPhone(phone),
              style: PremiumTokens.body(
                size: 14,
                weight: FontWeight.w500,
                color: pt.grey,
              ),
            ),
          ),
          Icon(Iconsax.lock_1, size: 16, color: pt.greyLight),
        ],
      ),
    );
  }
}

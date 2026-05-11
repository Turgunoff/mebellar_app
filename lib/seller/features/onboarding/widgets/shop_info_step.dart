import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mebellar_app/core/i18n/i18n.dart';

import '../bloc/onboarding_bloc.dart';

/// Shop name + short description.
///
/// We deliberately don't ask for Uz/Ru/En variants here — brand names rarely
/// translate, and forcing a tabbed multilingual form was the #1 friction
/// point in onboarding. The single value is stored under `shopNameUz` /
/// `shopDescriptionUz`; the localized getter falls back to whichever locale
/// is non-null when other locales view the shop.
class ShopInfoStep extends StatefulWidget {
  const ShopInfoStep({super.key, required this.formKey});

  final GlobalKey<FormState> formKey;

  @override
  State<ShopInfoStep> createState() => _ShopInfoStepState();
}

class _ShopInfoStepState extends State<ShopInfoStep> {
  late final TextEditingController _name;
  late final TextEditingController _desc;

  String? _nameValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 3) return 'Kamida 3 ta belgi kiriting';
    return null;
  }

  @override
  void initState() {
    super.initState();
    final draft = context.read<OnboardingBloc>().state.draft;
    _name = TextEditingController(text: draft.shopNameUz ?? '');
    _desc = TextEditingController(text: draft.shopDescriptionUz ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _emit() {
    context.read<OnboardingBloc>().add(
      OnboardingShopInfoChanged(
        shopNameUz: _name.text,
        shopDescriptionUz: _desc.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tr('onboarding.step_shop_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            tr('onboarding.step_shop_subtitle'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: tr('onboarding.shop_name'),
              border: const OutlineInputBorder(),
            ),
            validator: _nameValidator,
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _desc,
            maxLines: 4,
            maxLength: 300,
            decoration: InputDecoration(
              labelText: tr('onboarding.shop_description'),
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => _emit(),
          ),
        ],
      ),
    );
  }
}

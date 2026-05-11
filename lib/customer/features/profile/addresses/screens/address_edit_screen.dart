import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/models/address.dart';
import '../bloc/addresses_bloc.dart';
import '../widgets/map_preview.dart';
import 'region_picker_screen.dart';

class AddressEditScreen extends StatefulWidget {
  const AddressEditScreen({super.key, this.address});

  final Address? address;

  bool get isEdit => address != null;

  @override
  State<AddressEditScreen> createState() => _AddressEditScreenState();
}

class _AddressEditScreenState extends State<AddressEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _street;
  late final TextEditingController _apartment;
  late final TextEditingController _landmark;

  RegionPickerResult? _region;
  double? _lat;
  double? _lng;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    _label = TextEditingController(text: a?.label ?? '');
    _name = TextEditingController(text: a?.recipientName ?? '');
    _phone = TextEditingController(text: a?.phone ?? '');
    _street = TextEditingController(text: a?.streetLine ?? '');
    _apartment = TextEditingController(text: a?.apartment ?? '');
    _landmark = TextEditingController(text: a?.landmark ?? '');
    if (a != null) {
      _region = RegionPickerResult(
        region: a.region,
        city: a.city,
        district: a.district,
      );
      _lat = a.lat;
      _lng = a.lng;
      _isDefault = a.isDefault;
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _name.dispose();
    _phone.dispose();
    _street.dispose();
    _apartment.dispose();
    _landmark.dispose();
    super.dispose();
  }

  Future<void> _pickRegion() async {
    final result = await Navigator.of(context).push<RegionPickerResult>(
      MaterialPageRoute(builder: (_) => const RegionPickerScreen()),
    );
    if (result != null) setState(() => _region = result);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_region == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('address.region_required'))),
      );
      return;
    }
    final base = widget.address;
    final next = Address(
      id: base?.id ?? 'addr-tmp',
      label: _label.text.trim().isEmpty ? tr('address.default_label') : _label.text.trim(),
      recipientName: _name.text.trim(),
      phone: _phone.text.trim(),
      region: _region!.region,
      city: _region!.city,
      district: _region!.district,
      streetLine: _street.text.trim(),
      apartment: _apartment.text.trim().isEmpty ? null : _apartment.text.trim(),
      landmark: _landmark.text.trim().isEmpty ? null : _landmark.text.trim(),
      lat: _lat,
      lng: _lng,
      isDefault: _isDefault,
    );
    if (widget.isEdit) {
      context.read<AddressesBloc>().add(AddressUpdated(next));
    } else {
      context.read<AddressesBloc>().add(AddressCreated(next));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit
            ? tr('address.edit_title')
            : tr('address.create_title')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _label,
              decoration: InputDecoration(
                labelText: tr('address.label'),
                hintText: tr('address.label_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: tr('address.recipient'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? tr('auth.validation_required') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: tr('address.phone'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 9) ? tr('auth.validation_required') : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              leading: const Icon(Icons.location_on_outlined),
              title: Text(_region == null
                  ? tr('address.select_region')
                  : _region!.region.name.get(lang)),
              subtitle: _region == null
                  ? null
                  : Text([
                      _region!.city.name.get(lang),
                      if (_region!.district != null) _region!.district!.name.get(lang),
                    ].join(', ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickRegion,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _street,
              decoration: InputDecoration(
                labelText: tr('address.street'),
                hintText: tr('address.street_hint'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? tr('auth.validation_required') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _apartment,
              decoration: InputDecoration(
                labelText: tr('address.apartment'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _landmark,
              decoration: InputDecoration(
                labelText: tr('address.landmark'),
                hintText: tr('address.landmark_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('address.map_label'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            MapPreview(
              lat: _lat,
              lng: _lng,
              onChanged: (lat, lng) => setState(() {
                _lat = lat;
                _lng = lng;
              }),
            ),
            if (_lat != null && _lng != null) ...[
              const SizedBox(height: 6),
              Text(
                'lat: ${_lat!.toStringAsFixed(5)}, lng: ${_lng!.toStringAsFixed(5)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            SwitchListTile(
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
              title: Text(tr('address.set_default')),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(tr('common.save')),
            ),
          ],
        ),
      ),
    );
  }
}

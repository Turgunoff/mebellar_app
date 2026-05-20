import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_fonts.dart';
import '../../../../../shared/models/attribute_definition.dart';
import '../../../../../shared/models/attribute_option.dart';
import '../../bloc/add_product_cubit.dart';
import 'form_kit.dart';

/// Renders the dynamic-schema portion of the add-product form. Each
/// definition in [state.attributeSchema] becomes a widget keyed by its
/// `data_type`; values flow back through [AddProductCubit.setAttribute] so
/// the JSONB payload is always in sync with what the user sees.
///
/// Hidden when no category is selected and no schema is loaded — the form
/// keeps a clean look until the seller commits to a category.
class DynamicAttributesSection extends StatelessWidget {
  const DynamicAttributesSection({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final AddProductState state;
  final void Function(String key, dynamic value) onChanged;

  @override
  Widget build(BuildContext context) {
    if (state.categoryId == null) return const SizedBox.shrink();
    if (state.attributeSchema.isEmpty && !state.isLoadingSchema) {
      return const SizedBox.shrink();
    }
    final locale = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Xususiyatlar'),
        FormCard(
          child: state.isLoadingSchema && state.attributeSchema.isEmpty
              ? const _SchemaLoadingPlaceholder()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < state.attributeSchema.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      _AttributeField(
                        definition: state.attributeSchema[i],
                        value: state.attributes[state.attributeSchema[i].key],
                        locale: locale,
                        onChanged: (v) =>
                            onChanged(state.attributeSchema[i].key, v),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _SchemaLoadingPlaceholder extends StatelessWidget {
  const _SchemaLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(primary),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Xususiyatlar yuklanmoqda…',
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kGrey,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single attribute row — picks the renderer matching the definition's
/// `data_type`. Kept as a stateless dispatch so the parent can rebuild the
/// whole schema list cheaply when the cubit emits.
class _AttributeField extends StatelessWidget {
  const _AttributeField({
    required this.definition,
    required this.value,
    required this.locale,
    required this.onChanged,
  });

  final AttributeDefinition definition;
  final dynamic value;
  final String locale;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = definition.labelFor(locale);
    final labelWidget = _FieldLabel(
      label: label,
      isRequired: definition.isRequired,
    );
    switch (definition.dataType) {
      case AttributeDataType.select:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labelWidget,
            const SizedBox(height: 8),
            _OptionChipRow(
              options: definition.options,
              selectedValue: value as String?,
              locale: locale,
              onSelected: (v) => onChanged(v == value ? null : v),
            ),
          ],
        );
      case AttributeDataType.multiselect:
        final selected = (value as List?)?.cast<String>() ?? const <String>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labelWidget,
            const SizedBox(height: 8),
            _OptionChipRow(
              options: definition.options,
              selectedValues: selected,
              locale: locale,
              onSelectedMany: (next) =>
                  onChanged(next.isEmpty ? null : next),
            ),
          ],
        );
      case AttributeDataType.number:
        return _NumberField(
          label: label,
          isRequired: definition.isRequired,
          unit: definition.unit,
          value: value is num ? value : null,
          onChanged: (v) => onChanged(v),
        );
      case AttributeDataType.text:
        return _TextField(
          label: label,
          isRequired: definition.isRequired,
          value: value as String? ?? '',
          onChanged: (v) => onChanged(v.isEmpty ? null : v),
        );
      case AttributeDataType.bool_:
        return _BoolToggle(
          label: label,
          isRequired: definition.isRequired,
          value: value as bool? ?? false,
          onChanged: (v) => onChanged(v),
        );
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.isRequired});

  final String label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kGrey,
                letterSpacing: 0.1,
              ),
            ),
          ),
          if (isRequired)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                '*',
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OptionChipRow extends StatelessWidget {
  const _OptionChipRow({
    required this.options,
    required this.locale,
    this.selectedValue,
    this.selectedValues,
    this.onSelected,
    this.onSelectedMany,
  });

  final List<AttributeOption> options;
  final String locale;
  final String? selectedValue;
  final List<String>? selectedValues;
  final ValueChanged<String>? onSelected;
  final ValueChanged<List<String>>? onSelectedMany;

  bool _isSelected(String value) {
    if (selectedValues != null) return selectedValues!.contains(value);
    return selectedValue == value;
  }

  void _handleTap(String value) {
    if (onSelectedMany != null) {
      final next = [...(selectedValues ?? const <String>[])];
      if (next.remove(value)) {
        onSelectedMany!(next);
      } else {
        next.add(value);
        onSelectedMany!(next);
      }
      return;
    }
    onSelected?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _OptionChip(
            label: option.labelFor(locale),
            selected: _isSelected(option.value),
            onTap: () => _handleTap(option.value),
          ),
      ],
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final tint = primary.withValues(alpha: 0.08);
    return Material(
      color: selected ? tint : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? primary : kOutline,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? primary : kInk,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.isRequired,
    required this.unit,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool isRequired;
  final String? unit;
  final num? value;
  final ValueChanged<num?> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value == null ? '' : widget.value!.toString(),
    );
  }

  @override
  void didUpdateWidget(covariant _NumberField old) {
    super.didUpdateWidget(old);
    final next = widget.value == null ? '' : widget.value!.toString();
    if (next != _controller.text) {
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormTextField(
      controller: _controller,
      label: widget.isRequired ? '${widget.label} *' : widget.label,
      hint: widget.unit ?? '',
      suffix: widget.unit,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      onChanged: (raw) {
        if (raw.isEmpty) {
          widget.onChanged(null);
          return;
        }
        final normalised = raw.replaceAll(',', '.');
        final parsed = num.tryParse(normalised);
        widget.onChanged(parsed);
      },
    );
  }
}

class _TextField extends StatefulWidget {
  const _TextField({
    required this.label,
    required this.isRequired,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool isRequired;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _TextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormTextField(
      controller: _controller,
      label: widget.isRequired ? '${widget.label} *' : widget.label,
      onChanged: widget.onChanged,
    );
  }
}

class _BoolToggle extends StatelessWidget {
  const _BoolToggle({
    required this.label,
    required this.isRequired,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool isRequired;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Expanded(child: _FieldLabel(label: label, isRequired: isRequired)),
        Switch.adaptive(
          value: value,
          activeThumbColor: primary,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

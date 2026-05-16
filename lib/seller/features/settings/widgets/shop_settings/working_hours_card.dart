import 'package:flutter/material.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import '../../../../../shared/models/working_hours.dart';
import 'settings_form_kit.dart';

/// Seven day-rows, each with an open/close time pair and an open/closed
/// switch.
class WorkingHoursCard extends StatelessWidget {
  const WorkingHoursCard({
    super.key,
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
        SectionTitle(tr('shop_settings.hours_title')),
        SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < DayOfWeek.values.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, thickness: 1, color: kDivider),
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
              onSurface: kInk,
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
              style: const TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kInk,
                letterSpacing: -0.1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: hours.closed
                ? Text(
                    tr('shop_settings.closed'),
                    style: const TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kGreyMid,
                    ),
                  )
                : Row(
                    children: [
                      _TimePill(
                        label: hours.open ?? '09:00',
                        onTap: () => _pickTime(context, isOpen: true),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '-',
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kGreyMid,
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
        color: kFillSoft,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kOutline, width: 1),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kInk,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// HH:mm parsing + formatting for the day rows.
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

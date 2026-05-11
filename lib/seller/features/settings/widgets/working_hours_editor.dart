import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

import '../../../../shared/models/working_hours.dart';

/// Per-day open/close picker. Each row toggles "closed" with a switch and
/// reveals two `showTimePicker` buttons when open.
class WorkingHoursEditor extends StatelessWidget {
  const WorkingHoursEditor({
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
        for (final day in DayOfWeek.values) ...[
          _DayRow(
            day: day,
            hours: hours[day],
            onChanged: (next) => onDayChanged(day, next),
          ),
          if (day != DayOfWeek.sunday) const Divider(height: 1),
        ],
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

  Future<void> _pickTime(
    BuildContext context, {
    required bool isOpen,
  }) async {
    final initial = _parseHHmm(isOpen ? hours.open : hours.close) ??
        const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final formatted = _formatHHmm(picked);
    onChanged(isOpen
        ? hours.copyWith(open: formatted, closed: false)
        : hours.copyWith(close: formatted, closed: false));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              tr('day.${day.code}'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 8),
          if (hours.closed)
            Expanded(
              child: Text(
                tr('shop_settings.closed'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.outline,
                    ),
              ),
            )
          else
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(context, isOpen: true),
                      child: Text(hours.open ?? '09:00'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('вЂ”'),
                  const SizedBox(width: 4),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(context, isOpen: false),
                      child: Text(hours.close ?? '18:00'),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          Switch(
            value: !hours.closed,
            onChanged: (open) {
              if (open) {
                onChanged(DayHours(
                  open: hours.open ?? '09:00',
                  close: hours.close ?? '18:00',
                ));
              } else {
                onChanged(DayHours.closedDay);
              }
            },
          ),
        ],
      ),
    );
  }
}

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

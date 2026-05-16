import 'package:equatable/equatable.dart';

/// Open/close window for one day. We store the times as `HH:mm` strings
/// (not `TimeOfDay`) so the Hive cache and JSON serialisation stays trivial.
class DayHours extends Equatable {
  const DayHours({this.open, this.close, this.closed = false});

  /// `null` open/close or `closed=true` means the shop doesn't operate that
  /// day. Backend will normalise to ISO time when wired up.
  final String? open;
  final String? close;
  final bool closed;

  bool get isOpen24h => !closed && open == '00:00' && close == '23:59';
  bool get hasWindow => !closed && open != null && close != null;

  DayHours copyWith({String? open, String? close, bool? closed}) {
    return DayHours(
      open: open ?? this.open,
      close: close ?? this.close,
      closed: closed ?? this.closed,
    );
  }

  Map<String, dynamic> toJson() => {
        if (open != null) 'open': open,
        if (close != null) 'close': close,
        'closed': closed,
      };

  factory DayHours.fromJson(Map<String, dynamic> json) {
    return DayHours(
      open: json['open'] as String?,
      close: json['close'] as String?,
      closed: json['closed'] as bool? ?? false,
    );
  }

  static const closedDay = DayHours(closed: true);

  @override
  List<Object?> get props => [open, close, closed];
}

/// 7-entry list keyed by `DayOfWeek.monday`-`sunday`. Locale-agnostic so the
/// UI labels them via i18n.
enum DayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday;

  String get code => name;
}

class WeeklyHours extends Equatable {
  const WeeklyHours({required this.byDay});

  final Map<DayOfWeek, DayHours> byDay;

  DayHours operator [](DayOfWeek d) => byDay[d] ?? DayHours.closedDay;

  WeeklyHours setDay(DayOfWeek day, DayHours hours) {
    final next = Map<DayOfWeek, DayHours>.from(byDay);
    next[day] = hours;
    return WeeklyHours(byDay: next);
  }

  bool get hasAnyOpenDay => byDay.values.any((h) => h.hasWindow);

  /// Parses a `working_hours` jsonb object keyed by [DayOfWeek.code]
  /// (`monday`…`sunday`); a missing day degrades to [DayHours.closedDay].
  factory WeeklyHours.fromJson(Map<String, dynamic>? json) {
    if (json == null) return allClosed();
    final byDay = <DayOfWeek, DayHours>{};
    for (final day in DayOfWeek.values) {
      final raw = json[day.code];
      if (raw is Map<String, dynamic>) {
        byDay[day] = DayHours.fromJson(raw);
      }
    }
    return WeeklyHours(byDay: byDay);
  }

  /// Serialises to a jsonb object keyed by [DayOfWeek.code].
  Map<String, dynamic> toJson() => {
        for (final entry in byDay.entries)
          entry.key.code: entry.value.toJson(),
      };

  static WeeklyHours allClosed() => const WeeklyHours(byDay: {});

  static WeeklyHours weekdays9to6() => WeeklyHours(byDay: {
        for (final d in DayOfWeek.values)
          d: d == DayOfWeek.sunday
              ? DayHours.closedDay
              : const DayHours(open: '09:00', close: '18:00'),
      });

  @override
  List<Object?> get props => [byDay];
}

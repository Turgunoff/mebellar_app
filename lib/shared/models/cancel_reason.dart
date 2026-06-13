import 'package:equatable/equatable.dart';

/// One predefined cancellation reason from `GET /orders/cancel-reasons?role=…`.
/// [title] is already localised by the backend (it reads `Accept-Language`),
/// so the UI renders it directly; [code] is the stable key sent back on cancel.
/// `other` is special — the picker pairs it with a free-text field.
class CancelReason extends Equatable {
  const CancelReason({required this.code, required this.title});

  factory CancelReason.fromJson(Map<String, dynamic> json) => CancelReason(
    code: json['code'] as String? ?? '',
    title: json['title'] as String? ?? '',
  );

  final String code;
  final String title;

  static const otherCode = 'other';
  bool get isOther => code == otherCode;

  @override
  List<Object?> get props => [code, title];
}

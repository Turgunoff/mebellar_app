import 'package:equatable/equatable.dart';

/// Seller wallet snapshot — `GET /seller/wallet` (also embedded in the
/// dashboard payload). Money is integer so'm; `creditLimit` is a non-negative
/// magnitude and the balance floor is `-creditLimit` (the backend precomputes
/// it as [debtFloor] so no client re-derives the sign convention).
///
/// Soft-freeze ladder the UI mirrors:
///   * balance >= floor                → normal ([isHealthy])
///   * below floor, grace running     → warning banner ([isInGrace])
///   * grace lapsed                   → frozen ([isSuspendedDueToDebt])
class SellerWallet extends Equatable {
  const SellerWallet({
    this.balance = 0,
    this.creditLimit = 0,
    this.debtFloor = 0,
    this.isSuspendedDueToDebt = false,
    this.graceUntil,
    this.pendingTopUp,
    this.transactions = const [],
  });

  factory SellerWallet.fromJson(Map<String, dynamic> json) {
    final pending = json['pending_topup'];
    return SellerWallet(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      creditLimit: (json['credit_limit'] as num?)?.toInt() ?? 0,
      debtFloor: (json['debt_floor'] as num?)?.toInt() ?? 0,
      isSuspendedDueToDebt: json['is_suspended_due_to_debt'] as bool? ?? false,
      graceUntil: _parseDate(json['debt_grace_period_until']),
      pendingTopUp: pending is Map<String, dynamic>
          ? WalletTopUp.fromJson(pending)
          : null,
      transactions: ((json['transactions'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WalletTransaction.fromJson)
          .toList(growable: false),
    );
  }

  final int balance;
  final int creditLimit;
  final int debtFloor;
  final bool isSuspendedDueToDebt;
  final DateTime? graceUntil;
  final WalletTopUp? pendingTopUp;
  final List<WalletTransaction> transactions;

  bool get isHealthy => !isSuspendedDueToDebt && graceUntil == null;

  /// Below the floor with the grace clock running — warning, not frozen yet.
  bool get isInGrace => !isSuspendedDueToDebt && graceUntil != null;

  /// How much the seller must top up to climb back above the floor.
  int get debtAmount => balance < debtFloor ? debtFloor - balance : 0;

  /// Whole hours left in the grace window, floored at 1 so the banner never
  /// shows a paralysing "0 soat" while the sweeper hasn't fired yet.
  int graceHoursLeft([DateTime? now]) {
    final until = graceUntil;
    if (until == null) return 0;
    final left = until.difference(now ?? DateTime.now()).inHours;
    return left < 1 ? 1 : left;
  }

  @override
  List<Object?> get props => [
    balance,
    creditLimit,
    debtFloor,
    isSuspendedDueToDebt,
    graceUntil,
    pendingTopUp,
    transactions.length,
  ];
}

/// One immutable ledger row. Negative [amount] = debit (commission), positive
/// = credit (top-up / adjustment / refund).
class WalletTransaction extends Equatable {
  const WalletTransaction({
    required this.id,
    required this.amount,
    required this.balanceAfter,
    required this.type,
    required this.createdAt,
    this.note,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      balanceAfter: (json['balance_after'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? 'adjustment',
      note: json['note'] as String?,
      createdAt:
          _parseDate(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final int amount;
  final int balanceAfter;
  final String type;
  final String? note;
  final DateTime createdAt;

  bool get isDebit => amount < 0;

  String get typeLabel => switch (type) {
    'commission' => 'Komissiya',
    'topup' => "Hisob to'ldirish",
    'refund' => 'Qaytarish',
    _ => 'Tuzatish',
  };

  @override
  List<Object?> get props => [id, amount, balanceAfter, type, note, createdAt];
}

/// A top-up request riding the receipt-moderation flow (screenshot + admin
/// approval) — same trust model as tariff payments.
class WalletTopUp extends Equatable {
  const WalletTopUp({
    required this.id,
    required this.amount,
    required this.status,
    required this.submittedAt,
    this.rejectionReason,
  });

  factory WalletTopUp.fromJson(Map<String, dynamic> json) {
    return WalletTopUp(
      id: json['id'] as String,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'pending',
      submittedAt:
          _parseDate(json['submitted_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  final String id;
  final int amount;
  final String status;
  final DateTime submittedAt;
  final String? rejectionReason;

  bool get isPending => status == 'pending';

  bool get isApproved => status == 'approved';

  bool get isRejected => status == 'rejected';

  bool get isResolved => isApproved || isRejected || status == 'cancelled';

  /// 24-hour SLA — mirrors tariff manual-payment pending screens.
  Duration get slaRemaining {
    final due = submittedAt.add(const Duration(hours: 24));
    final left = due.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  List<Object?> get props => [id, amount, status, submittedAt, rejectionReason];
}

/// "1234567" → "1 234 567" — the so'm thousands grouping used across seller
/// screens. Keeps the minus sign in front for debts.
String formatSom(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return "${negative ? '-' : ''}$buf";
}

DateTime? _parseDate(Object? raw) =>
    raw is String ? DateTime.tryParse(raw) : null;

import 'package:equatable/equatable.dart';

import 'order.dart';
import 'tariff.dart';

class DailyRevenuePoint extends Equatable {
  const DailyRevenuePoint({required this.date, required this.amount});
  final DateTime date;
  final num amount;

  @override
  List<Object?> get props => [date, amount];
}

/// Numbers the dashboard shows above the fold + the analytics chart series.
class DashboardSnapshot extends Equatable {
  const DashboardSnapshot({
    required this.todaysOrders,
    required this.todaysRevenue,
    required this.pendingOrdersCount,
    required this.activeProductsCount,
    required this.tariff,
    required this.recentOrders,
    required this.last30Days,
  });

  final int todaysOrders;
  final num todaysRevenue;
  final int pendingOrdersCount;
  final int activeProductsCount;
  final TariffSnapshot tariff;
  final List<Order> recentOrders;
  final List<DailyRevenuePoint> last30Days;

  @override
  List<Object?> get props => [
        todaysOrders,
        todaysRevenue,
        pendingOrdersCount,
        activeProductsCount,
        tariff,
        recentOrders.length,
        last30Days.length,
      ];
}

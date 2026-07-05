/// A schedule that auto-opens a daily order (mirrors the web feature).
class RecurringOrder {
  final int id;
  final int restaurant;
  final String? restaurantName;
  final int? menu;
  final String? menuName;
  final String? collectorName;
  final String openAt; // "HH:MM:SS"
  final String weekdays; // csv "6,0,1,2,3" (0=Mon … 6=Sun)
  final int? cutoffAfterMinutes;
  final double deliveryFee;
  final double tip;
  final double serviceFee;
  final String feeSplitRule;
  final bool isActive;
  final String? lastRunDate;

  RecurringOrder({
    required this.id,
    required this.restaurant,
    this.restaurantName,
    this.menu,
    this.menuName,
    this.collectorName,
    required this.openAt,
    required this.weekdays,
    this.cutoffAfterMinutes,
    required this.deliveryFee,
    required this.tip,
    required this.serviceFee,
    required this.feeSplitRule,
    required this.isActive,
    this.lastRunDate,
  });

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  factory RecurringOrder.fromJson(Map<String, dynamic> json) {
    return RecurringOrder(
      id: json['id'] ?? 0,
      restaurant: json['restaurant'] ?? 0,
      restaurantName: json['restaurant_name'],
      menu: json['menu'],
      menuName: json['menu_name'],
      collectorName: json['collector_name'],
      openAt: json['open_at'] ?? '11:00:00',
      weekdays: json['weekdays'] ?? '6,0,1,2,3',
      cutoffAfterMinutes: json['cutoff_after_minutes'],
      deliveryFee: _d(json['delivery_fee']),
      tip: _d(json['tip']),
      serviceFee: _d(json['service_fee']),
      feeSplitRule: json['fee_split_rule'] ?? 'equal',
      isActive: json['is_active'] ?? true,
      lastRunDate: json['last_run_date'],
    );
  }

  /// "11:00:00" -> "11:00"
  String get openAtShort => openAt.length >= 5 ? openAt.substring(0, 5) : openAt;

  List<int> get weekdayList =>
      weekdays.split(',').where((d) => d.trim().isNotEmpty).map(int.parse).toList();
}

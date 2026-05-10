// lib/features/seller/model/seller_analytics_model.dart

class DailySalesData {
  final String date;
  final double revenue;
  final int orderCount;

  DailySalesData({
    required this.date,
    required this.revenue,
    required this.orderCount,
  });

  factory DailySalesData.fromJson(Map<String, dynamic> json) {
    return DailySalesData(
      date: json['date'] ?? '',
      revenue: (json['revenue'] ?? 0).toDouble(),
      orderCount: json['order_count'] ?? 0,
    );
  }
}

class AnalyticsResponse {
  final double todayRevenue;
  final int todayOrderCount;
  final double totalRevenue;
  final int totalOrderCount;
  final List<DailySalesData> dailyStats;

  AnalyticsResponse({
    required this.todayRevenue,
    required this.todayOrderCount,
    required this.totalRevenue,
    required this.totalOrderCount,
    required this.dailyStats,
  });

  factory AnalyticsResponse.fromJson(Map<String, dynamic> json) {
    return AnalyticsResponse(
      todayRevenue: (json['today_revenue'] ?? 0).toDouble(),
      todayOrderCount: json['today_order_count'] ?? 0,
      totalRevenue: (json['total_revenue'] ?? 0).toDouble(),
      totalOrderCount: json['total_order_count'] ?? 0,
      dailyStats: (json['daily_stats'] as List? ?? [])
          .map((item) => DailySalesData.fromJson(item))
          .toList(),
    );
  }
}

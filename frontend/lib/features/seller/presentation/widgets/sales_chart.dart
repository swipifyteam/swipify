// lib/features/seller/presentation/widgets/sales_chart.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swipify/features/seller/model/seller_analytics_model.dart';

class SalesChart extends StatelessWidget {
  final List<DailySalesData> data;

  const SalesChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text("No sales data available"));
    }

    final sortedData = List<DailySalesData>.from(data)
      ..sort((a, b) => a.date.compareTo(b.date));

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value < 0 || value >= sortedData.length) return const SizedBox();
                      if (value % 2 != 0) return const SizedBox(); // Show every 2 days
                      final dateStr = sortedData[value.toInt()].date;
                      final date = DateTime.parse(dateStr);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          DateFormat('MM/dd').format(date),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: sortedData.asMap().entries.map((entry) {
                    return FlSpot(entry.key.toDouble(), entry.value.revenue);
                  }).toList(),
                  isCurved: true,
                  color: Theme.of(context).primaryColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (touchedSpot) => Colors.blueAccent,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final item = sortedData[spot.x.toInt()];
                      return LineTooltipItem(
                        '₱${item.revenue.toStringAsFixed(2)}\n${item.orderCount} orders',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

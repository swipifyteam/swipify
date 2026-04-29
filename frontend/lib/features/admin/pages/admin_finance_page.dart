import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/services/admin_service.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminFinancePage extends StatefulWidget {
  const AdminFinancePage({super.key});

  @override
  State<AdminFinancePage> createState() => _AdminFinancePageState();
}

class _AdminFinancePageState extends State<AdminFinancePage> {
  bool _isLoading = true;
  Map<String, dynamic> _overview = {};

  @override
  void initState() {
    super.initState();
    _loadFinanceOverview();
  }

  Future<void> _loadFinanceOverview() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final result = await AdminService.getFinanceOverview();
        setState(() => _overview = result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading finance overview: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Finance Center', style: SwipifyTheme.heading1),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadFinanceOverview,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            // KPI Cards Grid
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 4;
                if (constraints.maxWidth < 800) crossAxisCount = 2;
                if (constraints.maxWidth < 400) crossAxisCount = 1;
                
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    _buildFinanceCard('Total GMV', '₱${(_overview['total_gmv'] ?? 0).toStringAsFixed(2)}', Icons.monetization_on, Colors.purple),
                    _buildFinanceCard('Net Revenue', '₱${(_overview['net_revenue'] ?? 0).toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.teal),
                    _buildFinanceCard('Total Payouts', '₱${(_overview['total_payouts'] ?? 0).toStringAsFixed(2)}', Icons.payments, Colors.blue),
                    _buildFinanceCard('Pending Refunds', '₱${(_overview['pending_refunds'] ?? 0).toStringAsFixed(2)}', Icons.assignment_return, Colors.red),
                  ],
                );
              },
            ),
            
            const SizedBox(height: 32),
            Text('Financial Activity', style: SwipifyTheme.heading2),
            const SizedBox(height: 16),
            
            // Temporary Chart Placeholder using fl_chart
            Container(
              height: 300,
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Revenue Breakdown', style: SwipifyTheme.productTitle),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final weeklyData = List<num>.from(_overview['weekly_revenue'] ?? [0.0, 0.0, 0.0, 0.0]);
                        final maxVal = weeklyData.reduce((curr, next) => curr > next ? curr : next).toDouble();
                        final double dynamicMaxY = maxVal > 0 ? maxVal * 1.2 : 1000.0;

                        return BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: dynamicMaxY,
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  return BarTooltipItem(
                                    '₱${rod.toY.toStringAsFixed(2)}',
                                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (double value, TitleMeta meta) {
                                    const style = TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12);
                                    String text;
                                    switch (value.toInt()) {
                                      case 0: text = 'Week 1'; break;
                                      case 1: text = 'Week 2'; break;
                                      case 2: text = 'Week 3'; break;
                                      case 3: text = 'Week 4'; break;
                                      default: text = ''; break;
                                    }
                                    return SideTitleWidget(
                                      meta: meta,
                                      space: 4,
                                      child: Text(text, style: style),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true, 
                                  reservedSize: 50,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0 || value == dynamicMaxY) return const SizedBox.shrink();
                                    return SideTitleWidget(
                                      meta: meta,
                                      space: 8,
                                      child: Text(
                                        value >= 1000 ? '${(value/1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0),
                                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: const FlGridData(show: true, drawVerticalLine: false),
                            borderData: FlBorderData(show: false),
                            barGroups: List.generate(4, (index) {
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: weeklyData.length > index ? weeklyData[index].toDouble() : 0.0,
                                    color: Colors.teal,
                                    width: 20,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  )
                                ],
                              );
                            }),
                          ),
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinanceCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

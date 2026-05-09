import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/services/admin_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:swipify/core/utils/responsive_helper.dart';

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
    final bool isMobile = ResponsiveHelper.isMobile(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Finance Center', 
                  style: isMobile ? SwipifyTheme.heading2 : SwipifyTheme.heading1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                int crossAxisCount = ResponsiveHelper.getCrossAxisCount(
                  context,
                  mobile: 1,
                  tablet: 2,
                  desktop: 4,
                );
                final bool isMobile = ResponsiveHelper.isMobile(context);
                final bool isTablet = ResponsiveHelper.isTablet(context);
                // Adjust aspect ratio based on width
                double childAspectRatio = isMobile ? 2.5 : (isTablet ? 1.8 : 1.5);
                
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: childAspectRatio,
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
            
            // Responsive Chart Container
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isMobile ? 16 : 24),
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
                  AspectRatio(
                    aspectRatio: isMobile ? 1.2 : 2.5,
                    child: Builder(
                      builder: (context) {
                        final weeklyData = List<num>.from(_overview['weekly_revenue'] ?? [0.0, 0.0, 0.0, 0.0]);
                        final maxVal = weeklyData.isEmpty ? 0.0 : weeklyData.reduce((curr, next) => curr > next ? curr : next).toDouble();
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
                                    const style = TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 10);
                                    String text;
                                    switch (value.toInt()) {
                                      case 0: text = isMobile ? 'W1' : 'Week 1'; break;
                                      case 1: text = isMobile ? 'W2' : 'Week 2'; break;
                                      case 2: text = isMobile ? 'W3' : 'Week 3'; break;
                                      case 3: text = isMobile ? 'W4' : 'Week 4'; break;
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
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0 || value == dynamicMaxY) return const SizedBox.shrink();
                                    return SideTitleWidget(
                                      meta: meta,
                                      space: 8,
                                      child: Text(
                                        value >= 1000 ? '${(value/1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0),
                                        style: const TextStyle(color: Colors.grey, fontSize: 9),
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
                                    width: isMobile ? 12 : 20,
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
      padding: const EdgeInsets.all(16), // Reduced from 20 for mobile
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
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

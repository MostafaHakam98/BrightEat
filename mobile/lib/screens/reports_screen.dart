import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/orders_provider.dart';
import '../providers/auth_provider.dart';
import '../services/orders_service.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  Widget _buildMetricCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: Consumer2<OrdersProvider, AuthProvider>(
        builder: (context, ordersProvider, authProvider, _) {
          return FutureBuilder<Map<String, dynamic>?>(
            future: ordersProvider.ordersService.getMonthlyReport(
              userId: authProvider.user?.id,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError || snapshot.data == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load report',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              final report = snapshot.data!;
              final month = report['month'] ?? 'N/A';
              final username = report['user']?['username'] ?? authProvider.user?.username ?? '';

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Report for $username',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            month,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Main Metrics Row
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _buildMetricCard(
                        'Total Spend',
                        '${(report['total_spend'] ?? 0.0).toStringAsFixed(2)} EGP',
                        Colors.blue,
                      ),
                      _buildMetricCard(
                        'Times as Collector',
                        '${report['collector_count'] ?? 0}',
                        Colors.green,
                      ),
                      _buildMetricCard(
                        'Unpaid Incidents',
                        '${report['unpaid_count'] ?? 0}',
                        Colors.red,
                      ),
                      _buildMetricCard(
                        'Total Collected',
                        '${(report['total_collected'] ?? 0.0).toStringAsFixed(2)} EGP',
                        Colors.purple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Secondary Metrics
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _buildMetricCard(
                        'Orders Participated',
                        '${report['total_orders_participated'] ?? 0}',
                        Colors.indigo,
                      ),
                      _buildMetricCard(
                        'Avg Order Value',
                        '${(report['avg_order_value'] ?? 0.0).toStringAsFixed(2)} EGP',
                        Colors.teal,
                      ),
                      _buildMetricCard(
                        'Total Fees Paid',
                        '${(report['total_fees_paid'] ?? 0.0).toStringAsFixed(2)} EGP',
                        Colors.orange,
                      ),
                      _buildMetricCard(
                        'Payment Completion',
                        '${(report['payment_completion_rate'] ?? 0.0).toStringAsFixed(1)}%',
                        Colors.cyan,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Additional Metrics
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _buildMetricCard(
                        'Total Pending',
                        '${(report['total_pending'] ?? 0.0).toStringAsFixed(2)} EGP',
                        Colors.pink,
                      ),
                      _buildMetricCard(
                        'Total Owed to You',
                        '${(report['total_owed_to_user'] ?? 0.0).toStringAsFixed(2)} EGP',
                        Colors.yellow.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Most Ordered Restaurant
                  if (report['most_ordered_restaurant'] != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Most Ordered Restaurant',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              report['most_ordered_restaurant'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${report['most_ordered_restaurant_count'] ?? 0} order${(report['most_ordered_restaurant_count'] ?? 0) != 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}


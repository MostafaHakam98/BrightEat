import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/orders_provider.dart';
import '../providers/auth_provider.dart';
import '../services/orders_service.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  Widget _buildMetricCard(
    String title,
    String value,
    Color color,
    String metricKey,
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: () => _showCalculation(context, metricKey),
      child: Card(
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
              const SizedBox(height: 2),
              Text(
                'Tap for details',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCalculation(BuildContext context, String metricKey) {
    final calculations = _getCalculations();
    final calc = calculations[metricKey];
    
    if (calc == null) return;

    final title = calc['title'] ?? 'Calculation';
    final formula = calc['formula'] ?? '';
    final explanation = calc['explanation'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calculation:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formula,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explanation:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      explanation,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Map<String, Map<String, String>> _getCalculations() {
    return {
      'total_spend': {
        'title': 'Total Spend Calculation',
        'formula': 'Sum of all payment amounts where you are the payer\n\nTotal Spend = Σ(Payment.amount)\nfor all payments where:\n- Payment.user = You\n- Payment.order.created_at >= Start of Month',
        'explanation': 'This is the total amount you have spent this month across all orders where you participated. It includes both item costs and your share of fees (delivery, tip, service fees) based on the fee split rule for each order.',
      },
      'collector_count': {
        'title': 'Times as Collector Calculation',
        'formula': 'Count of orders where you are the collector\n\nCollector Count = COUNT(CollectionOrder)\nwhere:\n- CollectionOrder.collector = You\n- CollectionOrder.created_at >= Start of Month',
        'explanation': 'This shows how many times you were the collector (person who places and collects the order) this month. As a collector, your own payment is automatically marked as paid.',
      },
      'unpaid_count': {
        'title': 'Unpaid Incidents Calculation',
        'formula': 'Count of unpaid payments\n\nUnpaid Count = COUNT(Payment)\nwhere:\n- Payment.user = You\n- Payment.is_paid = False\n- Payment.order.status IN (LOCKED, ORDERED, CLOSED)\n- Payment.order.created_at >= Start of Month',
        'explanation': 'This is the number of payments you still need to make. These are payments for orders that have been locked, ordered, or closed but you haven\'t marked as paid yet.',
      },
      'total_collected': {
        'title': 'Total Collected Calculation',
        'formula': 'Sum of payments from others when you were collector\n\nTotal Collected = Σ(Payment.amount)\nfor all payments where:\n- Payment.order.collector = You\n- Payment.user ≠ You\n- Payment.order.created_at >= Start of Month',
        'explanation': 'This is the total amount you collected from other participants when you were the collector. It represents the money others paid you for orders you collected.',
      },
      'total_orders_participated': {
        'title': 'Orders Participated Calculation',
        'formula': 'Count of distinct orders where you have items\n\nOrders Participated = COUNT(DISTINCT CollectionOrder)\nwhere:\n- OrderItem.user = You\n- OrderItem.order.created_at >= Start of Month',
        'explanation': 'This is the total number of unique orders you participated in this month (by adding items). It counts each order only once, even if you added multiple items to it.',
      },
      'avg_order_value': {
        'title': 'Average Order Value Calculation',
        'formula': 'Average total cost of orders you participated in\n\nAvg Order Value = Σ(Order.total_cost) / Orders Participated\n\nWhere Order.total_cost = Items Cost + Delivery Fee + Tip + Service Fee',
        'explanation': 'This is the average total cost (including all fees) of orders you participated in. It gives you an idea of the typical order size you\'re involved in.',
      },
      'total_fees_paid': {
        'title': 'Total Fees Paid Calculation',
        'formula': 'Sum of fees (delivery, tip, service) you paid\n\nTotal Fees Paid = Total Spend - Total Item Costs\n\nWhere:\n- Total Spend = Sum of all your payments\n- Total Item Costs = Sum of your order items',
        'explanation': 'This is the total amount you paid in fees (delivery, tip, and service fees) this month. It\'s calculated by subtracting your item costs from your total spend.',
      },
      'payment_completion_rate': {
        'title': 'Payment Completion Rate Calculation',
        'formula': 'Percentage of payments marked as paid\n\nPayment Completion Rate = (Paid Payments / Total Payments) × 100\n\nWhere:\n- Paid Payments = COUNT(Payment WHERE is_paid = True)\n- Total Payments = COUNT(Payment WHERE order.status IN (LOCKED, ORDERED, CLOSED))',
        'explanation': 'This shows what percentage of your payments you have marked as paid. A rate of 100% means you\'ve paid for all your orders this month.',
      },
      'total_pending': {
        'title': 'Total Pending Calculation',
        'formula': 'Sum of unpaid payment amounts\n\nTotal Pending = Σ(Payment.amount)\nwhere:\n- Payment.user = You\n- Payment.is_paid = False\n- Payment.order.status IN (LOCKED, ORDERED, CLOSED)\n- Payment.order.created_at >= Start of Month',
        'explanation': 'This is the total amount of money you still owe for orders this month. It\'s the sum of all unpaid payment amounts.',
      },
      'total_owed_to_user': {
        'title': 'Total Owed to You Calculation',
        'formula': 'Sum of unpaid payments from others when you were collector\n\nTotal Owed to You = Σ(Payment.amount)\nwhere:\n- Payment.order.collector = You\n- Payment.user ≠ You\n- Payment.is_paid = False\n- Payment.order.status IN (LOCKED, ORDERED, CLOSED)\n- Payment.order.created_at >= Start of Month',
        'explanation': 'This is the total amount others owe you for orders where you were the collector. These are payments that haven\'t been marked as paid yet.',
      },
      'most_ordered_restaurant': {
        'title': 'Most Ordered Restaurant Calculation',
        'formula': 'Restaurant with the most orders you participated in\n\nMost Ordered = Restaurant with MAX(COUNT(DISTINCT Order))\nwhere:\n- OrderItem.user = You\n- Order.created_at >= Start of Month\n\nGrouped by Restaurant',
        'explanation': 'This shows which restaurant you ordered from most frequently this month. It counts the number of distinct orders (not items) for each restaurant.',
      },
    };
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
                        'total_spend',
                        context,
                      ),
                      _buildMetricCard(
                        'Times as Collector',
                        '${report['collector_count'] ?? 0}',
                        Colors.green,
                        'collector_count',
                        context,
                      ),
                      _buildMetricCard(
                        'Unpaid Incidents',
                        '${report['unpaid_count'] ?? 0}',
                        Colors.red,
                        'unpaid_count',
                        context,
                      ),
                      _buildMetricCard(
                        'Total Collected',
                        '${(report['total_collected'] ?? 0.0).toStringAsFixed(2)} EGP',
                        Colors.purple,
                        'total_collected',
                        context,
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
                        'total_orders_participated',
                        context,
                      ),
                      _buildMetricCard(
                        'Avg Order Value',
                        '${(report['avg_order_value'] ?? 0.0).toStringAsFixed(2)} EGP',
                        Colors.teal,
                        'avg_order_value',
                        context,
                      ),
                      _buildMetricCard(
                        'Total Fees Paid',
                        '${(report['total_fees_paid'] ?? 0.0).toStringAsFixed(2)} EGP',
                        Colors.orange,
                        'total_fees_paid',
                        context,
                      ),
                      _buildMetricCard(
                        'Payment Completion',
                        '${(report['payment_completion_rate'] ?? 0.0).toStringAsFixed(1)}%',
                        Colors.cyan,
                        'payment_completion_rate',
                        context,
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
                        'total_pending',
                        context,
                      ),
                      _buildMetricCard(
                        'Total Owed to You',
                        '${(report['total_owed_to_user'] ?? 0.0).toStringAsFixed(2)} EGP',
                        Colors.yellow.shade700,
                        'total_owed_to_user',
                        context,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Most Ordered Restaurant
                  if (report['most_ordered_restaurant'] != null)
                    GestureDetector(
                      onTap: () => _showCalculation(context, 'most_ordered_restaurant'),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Most Ordered Restaurant',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Tap for details',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
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


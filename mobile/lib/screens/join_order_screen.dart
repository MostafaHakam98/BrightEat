import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/orders_provider.dart';

class JoinOrderScreen extends StatelessWidget {
  final String orderCode;

  const JoinOrderScreen({Key? key, required this.orderCode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Join Order $orderCode'),
      ),
      body: Consumer<OrdersProvider>(
        builder: (context, ordersProvider, _) {
          if (ordersProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final order = ordersProvider.currentOrder;

          if (order == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Order not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Go Home'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.restaurantName ?? order.restaurant.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Code: ${order.code}'),
                        Text('Collector: ${order.collectorName ?? order.collector.username}'),
                        Text('Status: ${order.status}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  // Register participation (adds you to the roster and notifies
                  // the collector) before navigating — matches the web app, so
                  // you're not invisible until you add an item.
                  onPressed: () async {
                    if (order.status == 'OPEN') {
                      await ordersProvider.joinOrder(order.id);
                    }
                    if (context.mounted) context.push('/orders/${order.code}');
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: Text(order.status == 'OPEN' ? 'Join & Add Items' : 'View Order Details'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/orders_provider.dart';

class PendingPaymentsScreen extends StatefulWidget {
  const PendingPaymentsScreen({Key? key}) : super(key: key);

  @override
  State<PendingPaymentsScreen> createState() => _PendingPaymentsScreenState();
}

class _PendingPaymentsScreenState extends State<PendingPaymentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrdersProvider>(context, listen: false).fetchPendingPayments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Payments'),
      ),
      body: Consumer<OrdersProvider>(
        builder: (context, ordersProvider, _) {
          if (ordersProvider.pendingPayments.isEmpty) {
            return const Center(child: Text('No pending payments'));
          }

          return ListView.builder(
            itemCount: ordersProvider.pendingPayments.length,
            itemBuilder: (context, index) {
              final payment = ordersProvider.pendingPayments[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(payment['restaurant_name'] ?? 'Unknown'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order: ${payment['order_code']}'),
                      Text('Collector: ${payment['collector_name']}'),
                      Text(
                        'Amount: ${payment['amount']?.toStringAsFixed(2) ?? '0.00'} EGP',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      final success = await ordersProvider.markPaymentAsPaid(
                        payment['payment_id'],
                      );
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payment marked as paid')),
                        );
                      }
                    },
                    child: const Text('Mark Paid'),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}


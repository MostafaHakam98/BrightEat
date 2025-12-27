import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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

  Widget _buildPaymentCard(
    Map<String, dynamic> payment,
    bool isOwedToMe,
    OrdersProvider ordersProvider,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isOwedToMe ? Colors.green : Colors.orange,
              width: 4,
            ),
          ),
        ),
        child: ListTile(
          title: Text(payment['restaurant_name'] ?? 'Unknown'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order: ${payment['order_code']}'),
              if (isOwedToMe)
                Text('Payer: ${payment['payer_name'] ?? 'Unknown'}')
              else
                Text('Collector: ${payment['collector_name'] ?? 'Unknown'}'),
              Text(
                'Amount: ${payment['amount']?.toStringAsFixed(2) ?? '0.00'} EGP',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isOwedToMe ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
          trailing: isOwedToMe
              ? IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    context.push('/orders/${payment['order_code']}');
                  },
                )
              : ElevatedButton(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Payments'),
      ),
      body: Consumer<OrdersProvider>(
        builder: (context, ordersProvider, _) {
          final paymentsIOwe = ordersProvider.pendingPayments;
          final paymentsOwedToMe = ordersProvider.pendingPaymentsToMe;

          if (paymentsIOwe.isEmpty && paymentsOwedToMe.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No pending payments',
                    style: TextStyle(color: Colors.grey[600], fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'re all caught up! 🎉',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView(
            children: [
              // Payments I Owe Section
              if (paymentsIOwe.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Text(
                        'Payments I Owe',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text('${paymentsIOwe.length}'),
                        backgroundColor: Colors.orange.withOpacity(0.2),
                      ),
                    ],
                  ),
                ),
                ...paymentsIOwe.map((payment) => _buildPaymentCard(
                      payment,
                      false,
                      ordersProvider,
                    )),
                const SizedBox(height: 16),
              ],

              // Payments Owed to Me Section
              if (paymentsOwedToMe.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Text(
                        'Payments Owed to Me',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text('${paymentsOwedToMe.length}'),
                        backgroundColor: Colors.green.withOpacity(0.2),
                      ),
                    ],
                  ),
                ),
                ...paymentsOwedToMe.map((payment) => _buildPaymentCard(
                      payment,
                      true,
                      ordersProvider,
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}


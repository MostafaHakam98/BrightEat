import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/orders_provider.dart';
import '../models/restaurant.dart';

class RestaurantsScreen extends StatefulWidget {
  const RestaurantsScreen({Key? key}) : super(key: key);

  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrdersProvider>(context, listen: false).fetchRestaurants();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurants'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddRestaurantDialog(context),
          ),
        ],
      ),
      body: Consumer<OrdersProvider>(
        builder: (context, ordersProvider, _) {
          if (ordersProvider.restaurants.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            itemCount: ordersProvider.restaurants.length,
            itemBuilder: (context, index) {
              final restaurant = ordersProvider.restaurants[index];
              return ListTile(
                title: Text(restaurant.name),
                subtitle: restaurant.description != null
                    ? Text(restaurant.description!)
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.restaurant_menu),
                  onPressed: () => context.push('/restaurants/${restaurant.id}/menus'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddRestaurantDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Restaurant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
              final success = await ordersProvider.createRestaurant({
                'name': nameController.text.trim(),
                'description': descriptionController.text.trim(),
              });

              if (success && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Restaurant created')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}


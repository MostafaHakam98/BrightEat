import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/orders_provider.dart';
import '../models/menu.dart';
import '../models/menu_item.dart';

class MenuManagementScreen extends StatefulWidget {
  final int restaurantId;

  const MenuManagementScreen({Key? key, required this.restaurantId}) : super(key: key);

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
      ordersProvider.fetchMenus(restaurantId: widget.restaurantId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Management'),
      ),
      body: Consumer<OrdersProvider>(
        builder: (context, ordersProvider, _) {
          if (ordersProvider.isLoadingMenus) {
            return const Center(child: CircularProgressIndicator());
          }

          if (ordersProvider.menus.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No menus found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: ordersProvider.menus.length,
            itemBuilder: (context, index) {
              final menu = ordersProvider.menus[index];
              return ListTile(
                title: Text(menu.name),
                subtitle: Text('Active: ${menu.isActive}'),
                onTap: () async {
                  // Show menu items
                  await ordersProvider.fetchMenuItems(menuId: menu.id);
                  if (mounted) {
                    _showMenuItemsDialog(context, menu, ordersProvider);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showMenuItemsDialog(
    BuildContext context,
    Menu menu,
    OrdersProvider ordersProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(menu.name),
        content: SizedBox(
          width: double.maxFinite,
          child: Consumer<OrdersProvider>(
            builder: (context, provider, _) {
              if (provider.isLoadingMenuItems) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (provider.menuItems.isEmpty) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant_menu, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No menu items found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SizedBox(
                height: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: provider.menuItems.length,
                  itemBuilder: (context, index) {
                    final item = provider.menuItems[index];
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text('${item.price.toStringAsFixed(2)} EGP'),
                      trailing: item.isAvailable
                          ? Icon(Icons.check_circle, color: Colors.green)
                          : Icon(Icons.cancel, color: Colors.red),
                    );
                  },
                ),
              );
            },
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
}


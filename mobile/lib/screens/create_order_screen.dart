import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/orders_provider.dart';
import '../providers/notifications_provider.dart';
import '../models/restaurant.dart';
import '../models/menu.dart';

class CreateOrderScreen extends StatefulWidget {
  final int? initialRestaurantId;
  
  const CreateOrderScreen({Key? key, this.initialRestaurantId}) : super(key: key);

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  int? _selectedRestaurantId;
  int? _selectedMenuId;
  DateTime? _cutoffTime;
  bool _isPrivate = false;
  bool _isLoading = false;
  List<Menu> _availableMenus = [];

  @override
  void initState() {
    super.initState();
    // Set initial restaurant if provided
    if (widget.initialRestaurantId != null) {
      _selectedRestaurantId = widget.initialRestaurantId;
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
      if (ordersProvider.restaurants.isEmpty) {
        ordersProvider.fetchRestaurants();
      }
      
      // Load menus if restaurant was pre-selected
      if (_selectedRestaurantId != null) {
        _onRestaurantChanged(_selectedRestaurantId);
      }
    });
  }

  Future<void> _onRestaurantChanged(int? restaurantId) async {
    setState(() {
      _selectedRestaurantId = restaurantId;
      _selectedMenuId = null;
      _availableMenus = [];
    });

    if (restaurantId != null) {
      final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
      await ordersProvider.fetchMenus(restaurantId: restaurantId);
      setState(() {
        _availableMenus = ordersProvider.menus.where((m) => m.isActive).toList();
      });
    }
  }

  Future<void> _createOrder() async {
    if (_selectedRestaurantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a restaurant'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Require menu if menus are available
    if (_availableMenus.isNotEmpty && _selectedMenuId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a menu for this restaurant'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    
    final orderData = <String, dynamic>{
      'restaurant': _selectedRestaurantId,
      'is_private': _isPrivate,
    };

    if (_selectedMenuId != null) {
      orderData['menu'] = _selectedMenuId;
    }

    if (_cutoffTime != null) {
      orderData['cutoff_time'] = _cutoffTime!.toIso8601String();
    }

    try {
      final success = await ordersProvider.createOrder(orderData);
      
      if (success && mounted) {
        final order = ordersProvider.currentOrder;
        if (order != null) {
          // Send notification about new order
          final notificationsProvider = Provider.of<NotificationsProvider>(context, listen: false);
          await notificationsProvider.notifyOrderCreated(
            orderCode: order.code,
            restaurantName: order.restaurant.name,
            orderId: order.id.toString(),
          );
          
          // Schedule cutoff time reminder if applicable
          if (order.cutoffTime != null) {
            await notificationsProvider.scheduleCutoffReminder(
              orderCode: order.code,
              cutoffTime: order.cutoffTime!,
              orderId: order.id.toString(),
            );
          }
          
          context.go('/orders/${order.code}');
        } else {
          context.go('/orders');
        }
      } else {
        if (mounted) {
          final errorMessage = ordersProvider.lastError ?? 'Failed to create order. Please try again.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectCutoffTime() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );

    if (picked != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      );

      if (time != null && mounted) {
        setState(() {
          _cutoffTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Order'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Consumer<OrdersProvider>(
          builder: (context, ordersProvider, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Restaurant selection
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Restaurant *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.restaurant),
                  ),
                  value: _selectedRestaurantId,
                  items: ordersProvider.restaurants.map((restaurant) {
                    return DropdownMenuItem<int>(
                      value: restaurant.id,
                      child: Text(restaurant.name),
                    );
                  }).toList(),
                  onChanged: (value) => _onRestaurantChanged(value),
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a restaurant';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Menu selection
                if (_selectedRestaurantId != null) ...[
                  if (ordersProvider.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Menu ${_availableMenus.isNotEmpty ? "*" : ""}',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.menu_book),
                        helperText: _availableMenus.isEmpty
                            ? 'No menus available. You can still create the order and add items manually.'
                            : 'Select a menu for this order',
                      ),
                      value: _selectedMenuId,
                      items: _availableMenus.map((menu) {
                        return DropdownMenuItem<int>(
                          value: menu.id,
                          child: Text(menu.name),
                        );
                      }).toList(),
                      onChanged: _availableMenus.isEmpty
                          ? null
                          : (value) {
                              setState(() {
                                _selectedMenuId = value;
                              });
                            },
                    ),
                  const SizedBox(height: 16),
                ],

                // Cutoff time
                InkWell(
                  onTap: _selectCutoffTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Cutoff Time (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(
                      _cutoffTime != null
                          ? '${_cutoffTime!.year}-${_cutoffTime!.month.toString().padLeft(2, '0')}-${_cutoffTime!.day.toString().padLeft(2, '0')} ${_cutoffTime!.hour.toString().padLeft(2, '0')}:${_cutoffTime!.minute.toString().padLeft(2, '0')}'
                          : 'Select cutoff time',
                      style: TextStyle(
                        color: _cutoffTime != null
                            ? Theme.of(context).textTheme.bodyLarge?.color
                            : Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Private order checkbox
                CheckboxListTile(
                  title: const Text('Private Order'),
                  subtitle: const Text(
                    'Only assigned users can see and join this order',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _isPrivate,
                  onChanged: (value) {
                    setState(() {
                      _isPrivate = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 24),

                // Create button
                ElevatedButton(
                  onPressed: _isLoading ? null : _createOrder,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: Colors.blue,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Create Order',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


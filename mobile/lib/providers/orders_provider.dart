import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/order.dart';
import '../models/restaurant.dart';
import '../models/menu.dart';
import '../models/menu_item.dart';
import '../models/order_item.dart';
import '../models/user.dart';
import '../services/orders_service.dart';
import 'notifications_provider.dart';

class OrdersProvider extends ChangeNotifier {
  final OrdersService ordersService;
  
  OrdersProvider(this.ordersService);
  
  List<CollectionOrder> _orders = [];
  CollectionOrder? _currentOrder;
  List<Restaurant> _restaurants = [];
  List<Menu> _menus = [];
  List<MenuItem> _menuItems = [];
  List<User> _users = [];
  List<Map<String, dynamic>> _pendingPayments = [];
  bool _isLoading = false;
  bool _isLoadingMenus = false;
  bool _isLoadingMenuItems = false;
  String? _lastError;

  List<CollectionOrder> get orders => _orders;
  CollectionOrder? get currentOrder => _currentOrder;
  List<Restaurant> get restaurants => _restaurants;
  List<Menu> get menus => _menus;
  List<MenuItem> get menuItems => _menuItems;
  List<User> get users => _users;
  List<Map<String, dynamic>> get pendingPayments => _pendingPayments;
  bool get isLoading => _isLoading;
  bool get isLoadingMenus => _isLoadingMenus;
  bool get isLoadingMenuItems => _isLoadingMenuItems;

  List<CollectionOrder> get activeOrders {
    return _orders.where((o) => o.status != 'CLOSED').toList();
  }

  String? get lastError => _lastError;

  Future<void> fetchOrders({String? status}) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
    _orders = await ordersService.fetchOrders(status: status);
    } catch (e) {
      print('❌ Error fetching orders in provider: $e');
      _orders = []; // Set to empty list on error
      if (e is DioException && e.response != null) {
        final errorData = e.response?.data;
        if (errorData is Map && errorData.containsKey('detail')) {
          _lastError = errorData['detail'];
        } else if (errorData is Map && errorData.containsKey('error')) {
          _lastError = errorData['error'];
        } else {
          _lastError = 'Failed to fetch orders: ${e.message}';
        }
      } else {
        _lastError = 'Failed to fetch orders: ${e.toString()}';
      }
    } finally {
    _isLoading = false;
    notifyListeners();
    }
  }

  Future<bool> fetchOrderByCode(String code) async {
    _isLoading = true;
    notifyListeners();

    _currentOrder = await ordersService.fetchOrderByCode(code);
    
    _isLoading = false;
    notifyListeners();
    return _currentOrder != null;
  }

  Future<bool> createOrder(Map<String, dynamic> orderData) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
    final order = await ordersService.createOrder(orderData);
    
    if (order != null) {
      _currentOrder = order;
        // Refresh orders list to get the latest from server
        await fetchOrders();
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
        _lastError = 'Failed to create order';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      print('❌ Error in createOrder provider: $e');
      if (e is DioException && e.response != null) {
        final errorData = e.response?.data;
        if (errorData is Map && errorData.containsKey('detail')) {
          _lastError = errorData['detail'];
        } else if (errorData is Map && errorData.containsKey('error')) {
          _lastError = errorData['error'];
        } else {
          _lastError = 'Failed to create order: ${e.message}';
        }
      } else {
        _lastError = 'Failed to create order: ${e.toString()}';
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> lockOrder(int orderId) async {
    final success = await ordersService.lockOrder(orderId);
    if (success) {
      await fetchOrderByCode(_currentOrder?.code ?? '');
      await fetchOrders();
    }
    return success;
  }

  Future<bool> unlockOrder(int orderId) async {
    final success = await ordersService.unlockOrder(orderId);
    if (success) {
      await fetchOrderByCode(_currentOrder?.code ?? '');
      await fetchOrders();
    }
    return success;
  }

  Future<bool> markOrdered(int orderId) async {
    final success = await ordersService.markOrdered(orderId);
    if (success) {
      await fetchOrderByCode(_currentOrder?.code ?? '');
      await fetchOrders();
    }
    return success;
  }

  Future<bool> closeOrder(int orderId) async {
    final success = await ordersService.closeOrder(orderId);
    if (success) {
      await fetchOrderByCode(_currentOrder?.code ?? '');
      await fetchOrders();
    }
    return success;
  }

  Future<bool> deleteOrder(int orderId) async {
    final success = await ordersService.deleteOrder(orderId);
    if (success) {
      _orders.removeWhere((o) => o.id == orderId);
      if (_currentOrder?.id == orderId) {
        _currentOrder = null;
      }
      notifyListeners();
    }
    return success;
  }

  Future<void> fetchRestaurants() async {
    _restaurants = await ordersService.fetchRestaurants();
    notifyListeners();
  }

  Future<bool> createRestaurant(Map<String, dynamic> data) async {
    final restaurant = await ordersService.createRestaurant(data);
    if (restaurant != null) {
      _restaurants.add(restaurant);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> fetchMenus({int? restaurantId}) async {
    _isLoadingMenus = true;
    notifyListeners();
    try {
      _menus = await ordersService.fetchMenus(restaurantId: restaurantId);
    } catch (e) {
      print('❌ Error fetching menus: $e');
      _menus = [];
    } finally {
      _isLoadingMenus = false;
      notifyListeners();
    }
  }

  Future<void> fetchMenuItems({int? menuId, int? restaurantId}) async {
    _isLoadingMenuItems = true;
    notifyListeners();
    try {
      _menuItems = await ordersService.fetchMenuItems(menuId: menuId, restaurantId: restaurantId);
    } catch (e) {
      print('❌ Error fetching menu items: $e');
      _menuItems = [];
    } finally {
      _isLoadingMenuItems = false;
      notifyListeners();
    }
  }

  Future<void> fetchUsers() async {
    try {
      _users = await ordersService.fetchUsers();
      notifyListeners();
    } catch (e) {
      print('❌ Error fetching users: $e');
      _users = [];
      notifyListeners();
    }
  }

  Future<bool> addOrderItem(Map<String, dynamic> data) async {
    final item = await ordersService.addOrderItem(data);
    if (item != null) {
      await fetchOrderByCode(_currentOrder?.code ?? '');
      return true;
    }
    return false;
  }

  Future<bool> removeOrderItem(int itemId) async {
    final success = await ordersService.removeOrderItem(itemId);
    if (success) {
      await fetchOrderByCode(_currentOrder?.code ?? '');
    }
    return success;
  }

  Future<void> fetchPendingPayments() async {
    _pendingPayments = await ordersService.fetchPendingPayments();
    notifyListeners();
  }

  Future<bool> markPaymentAsPaid(int paymentId) async {
    final success = await ordersService.markPaymentAsPaid(paymentId);
    if (success) {
      await fetchPendingPayments();
      await fetchOrders();
    }
    return success;
  }

  void setCurrentOrder(CollectionOrder? order) {
    _currentOrder = order;
    notifyListeners();
  }
}


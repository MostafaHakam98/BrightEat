import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class ApiService {
  late Dio _dio;
  final SharedPreferences _prefs;
  static String get baseUrl => AppConfig.apiBaseUrl;

  ApiService(this._prefs) {
    // Debug: Print the base URL being used
    print('🔗 API Base URL: $baseUrl');
    
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // Add request interceptor to include auth token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _prefs.getString('access_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // Debug-only logging. NEVER log request bodies/headers in release —
        // they contain passwords and bearer tokens.
        if (kDebugMode) {
          print('📤 ${options.method} ${options.baseUrl}${options.path}');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          print('📥 ${response.statusCode} ${response.requestOptions.path}');
        }
        return handler.next(response);
      },
      onError: (error, handler) async {
        if (kDebugMode) {
          final status = error.response?.statusCode;
          print('❌ ${error.type} ${error.requestOptions.path}'
              '${status != null ? ' → $status' : ''}');
        }

        // Handle 401 errors (token refresh)
        // Don't try to refresh if the failed request IS the refresh endpoint itself
        if (error.response?.statusCode == 401 && 
            !error.requestOptions.path.contains('/auth/refresh/') &&
            !error.requestOptions.path.contains('/auth/login/')) {
          // Try to refresh token
          final refreshToken = _prefs.getString('refresh_token');
          if (refreshToken != null && refreshToken.isNotEmpty) {
            try {
              // Create a new Dio instance without interceptors to avoid infinite loop
              final refreshDio = Dio(BaseOptions(
                baseUrl: baseUrl,
                headers: {'Content-Type': 'application/json'},
              ));
              
              final response = await refreshDio.post(
                '/auth/refresh/',
                data: {'refresh': refreshToken},
              );
              final newAccessToken = response.data['access'];
              await _prefs.setString('access_token', newAccessToken);
              
              // Retry original request with new token
              error.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              final opts = Options(
                method: error.requestOptions.method,
                headers: error.requestOptions.headers,
              );
              final cloneReq = await _dio.request(
                error.requestOptions.path,
                options: opts,
                data: error.requestOptions.data,
                queryParameters: error.requestOptions.queryParameters,
              );
              return handler.resolve(cloneReq);
            } catch (e) {
              // Refresh failed, clear tokens and don't retry
              print('🔄 Token refresh failed, clearing tokens and logging out');
              await _prefs.remove('access_token');
              await _prefs.remove('refresh_token');
              return handler.next(error);
            }
          } else {
            // No refresh token available, clear access token
            await _prefs.remove('access_token');
          }
        }
        return handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;

  // Test connectivity - simple GET request to see if server is reachable
  Future<Map<String, dynamic>> testConnection() async {
    try {
      print('🧪 Testing connection to: $baseUrl');
      print('🧪 Attempting GET request to: $baseUrl/orders/');
      
      final response = await _dio.get(
        '/orders/',
        options: Options(
          validateStatus: (status) => true, // Accept any status code
        ),
      );
      
      print('✅ Connection test successful!');
      print('✅ Status Code: ${response.statusCode}');
      print('✅ Server is reachable');
      
      return {
        'success': true,
        'statusCode': response.statusCode,
        'message': 'Server is reachable',
      };
    } on DioException catch (e) {
      print('❌ Connection test failed!');
      print('❌ Error Type: ${e.type}');
      print('❌ Error Message: ${e.message}');
      print('❌ Error: ${e.error}');
      
      return {
        'success': false,
        'errorType': e.type.toString(),
        'errorMessage': e.message ?? 'Unknown error',
        'error': e.error?.toString(),
      };
    } catch (e) {
      print('❌ Unexpected error during connection test: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Auth endpoints
  Future<Response> login(String usernameOrEmail, String password) async {
    final isEmail = usernameOrEmail.contains('@');
    final data = isEmail
        ? {'email': usernameOrEmail, 'password': password}
        : {'username': usernameOrEmail, 'password': password};
    return _dio.post('/auth/login/', data: data);
  }

  Future<Response> register(Map<String, dynamic> userData) async {
    return _dio.post('/auth/register/', data: userData);
  }

  Future<Response> refreshToken(String refreshToken) async {
    return _dio.post('/auth/refresh/', data: {'refresh': refreshToken});
  }

  // User endpoints
  Future<Response> getCurrentUser() async {
    return _dio.get('/users/me/');
  }

  Future<Response> updateUser(int userId, Map<String, dynamic> data, {FormData? formData}) async {
    if (formData != null) {
      return _dio.patch('/users/$userId/', data: formData);
    }
    return _dio.patch('/users/$userId/', data: data);
  }

  Future<Response> changePassword(Map<String, dynamic> data) async {
    return _dio.post('/users/change_password/', data: data);
  }

  Future<Response> getUsers() async {
    return _dio.get('/users/');
  }

  // Order endpoints
  Future<Response> getOrders({String? status}) async {
    final params = status != null ? <String, dynamic>{'status': status} : <String, dynamic>{};
    return _dio.get('/orders/', queryParameters: params);
  }

  Future<Response> getOrderByCode(String code) async {
    return _dio.get('/orders/by_code/', queryParameters: {'code': code});
  }

  Future<Response> createOrder(Map<String, dynamic> data) async {
    return _dio.post('/orders/', data: data);
  }

  Future<Response> updateOrder(int orderId, Map<String, dynamic> data) async {
    return _dio.patch('/orders/$orderId/', data: data);
  }

  Future<Response> lockOrder(int orderId, {Map<String, dynamic>? customAmounts}) async {
    final data = customAmounts != null ? {'custom_amounts': customAmounts} : null;
    return _dio.post('/orders/$orderId/lock/', data: data);
  }

  Future<Response> transferCollector(int orderId, int newCollectorId) async {
    return _dio.post('/orders/$orderId/transfer_collector/',
        data: {'new_collector_id': newCollectorId});
  }

  Future<Response> getTalabatSheet(int orderId) async {
    return _dio.get('/orders/$orderId/talabat_sheet/');
  }

  Future<Response> unlockOrder(int orderId) async {
    return _dio.post('/orders/$orderId/unlock/');
  }

  Future<Response> markOrdered(int orderId) async {
    return _dio.post('/orders/$orderId/mark_ordered/');
  }

  Future<Response> closeOrder(int orderId) async {
    return _dio.post('/orders/$orderId/close/');
  }

  Future<Response> deleteOrder(int orderId) async {
    return _dio.delete('/orders/$orderId/');
  }

  Future<Response> joinOrder(int orderId) async {
    return _dio.post('/orders/$orderId/join/');
  }

  Future<Response> getPendingPayments() async {
    return _dio.get('/orders/pending_payments/');
  }

  Future<Response> getPendingPaymentsToMe() async {
    return _dio.get('/orders/pending_payments_to_me/');
  }

  Future<Response> getMonthlyReport({int? userId}) async {
    final params = userId != null ? <String, dynamic>{'user_id': userId} : <String, dynamic>{};
    return _dio.get('/orders/monthly_report/', queryParameters: params);
  }

  // Restaurant endpoints
  Future<Response> getRestaurants() async {
    return _dio.get('/restaurants/');
  }

  Future<Response> createRestaurant(Map<String, dynamic> data) async {
    return _dio.post('/restaurants/', data: data);
  }

  Future<Response> updateRestaurant(int restaurantId, Map<String, dynamic> data) async {
    return _dio.patch('/restaurants/$restaurantId/', data: data);
  }

  Future<Response> deleteRestaurant(int restaurantId) async {
    return _dio.delete('/restaurants/$restaurantId/');
  }

  // Menu endpoints
  Future<Response> getMenus({int? restaurantId}) async {
    final params = restaurantId != null ? <String, dynamic>{'restaurant': restaurantId} : <String, dynamic>{};
    return _dio.get('/menus/', queryParameters: params);
  }

  Future<Response> createMenu(Map<String, dynamic> data) async {
    return _dio.post('/menus/', data: data);
  }

  Future<Response> updateMenu(int menuId, Map<String, dynamic> data) async {
    return _dio.patch('/menus/$menuId/', data: data);
  }

  Future<Response> deleteMenu(int menuId) async {
    return _dio.delete('/menus/$menuId/');
  }

  // Menu Item endpoints
  Future<Response> getMenuItems({int? menuId, int? restaurantId}) async {
    final params = <String, dynamic>{};
    if (menuId != null) params['menu'] = menuId;
    if (restaurantId != null) params['restaurant'] = restaurantId;
    return _dio.get('/menu-items/', queryParameters: params);
  }

  Future<Response> createMenuItem(Map<String, dynamic> data) async {
    return _dio.post('/menu-items/', data: data);
  }

  Future<Response> updateMenuItem(int itemId, Map<String, dynamic> data) async {
    return _dio.patch('/menu-items/$itemId/', data: data);
  }

  Future<Response> deleteMenuItem(int itemId) async {
    return _dio.delete('/menu-items/$itemId/');
  }

  // Order Item endpoints
  Future<Response> getOrderItems({int? orderId, int? userId}) async {
    final params = <String, dynamic>{};
    if (orderId != null) params['order'] = orderId;
    if (userId != null) params['user'] = userId;
    return _dio.get('/order-items/', queryParameters: params);
  }

  Future<Response> createOrderItem(Map<String, dynamic> data) async {
    return _dio.post('/order-items/', data: data);
  }

  Future<Response> updateOrderItem(int itemId, Map<String, dynamic> data) async {
    return _dio.patch('/order-items/$itemId/', data: data);
  }

  Future<Response> deleteOrderItem(int itemId) async {
    return _dio.delete('/order-items/$itemId/');
  }

  Future<Response> addItemToMenu(int itemId, {int? menuId}) async {
    final data = menuId != null ? {'menu_id': menuId} : {};
    return _dio.post('/order-items/$itemId/add_to_menu/', data: data);
  }

  Future<Response> updateMenuItemPrice(int itemId, double price) async {
    return _dio.post('/order-items/$itemId/update_menu_item_price/', data: {'price': price});
  }

  // Payment endpoints
  Future<Response> getPayments({int? orderId, int? userId}) async {
    final params = <String, dynamic>{};
    if (orderId != null) params['order'] = orderId;
    if (userId != null) params['user'] = userId;
    return _dio.get('/payments/', queryParameters: params);
  }

  Future<Response> markPaymentAsPaid(int paymentId) async {
    return _dio.post('/payments/$paymentId/mark_paid/');
  }

  // Fee Preset endpoints
  Future<Response> getFeePresets() async {
    return _dio.get('/fee-presets/');
  }

  // Recommendation endpoints
  Future<Response> getRecommendations() async {
    return _dio.get('/recommendations/');
  }

  Future<Response> createRecommendation(Map<String, dynamic> data) async {
    return _dio.post('/recommendations/', data: data);
  }

  Future<Response> deleteRecommendation(int recommendationId) async {
    return _dio.delete('/recommendations/$recommendationId/');
  }

  // Talabat scraping (manager/all users) — async: returns a task id to poll
  Future<Response> addRestaurantFromTalabat(String talabatUrl, {bool syncNow = false}) async {
    return _dio.post('/restaurants/add_from_talabat/',
        data: {'talabat_url': talabatUrl, 'sync_now': syncNow});
  }

  Future<Response> syncRestaurantMenu(int restaurantId) async {
    return _dio.post('/restaurants/$restaurantId/sync_menu/');
  }

  Future<Response> getTaskStatus(String taskId) async {
    return _dio.get('/task-status/$taskId/');
  }

  // One-tap reorder: the user's items from their last order at a restaurant
  Future<Response> getMyUsual(int restaurantId) async {
    return _dio.get('/restaurants/$restaurantId/my_usual/');
  }

  // Payment proof (Instapay screenshot) flow
  Future<Response> uploadPaymentProof(int paymentId, String filePath) async {
    final form = FormData.fromMap({
      'proof': await MultipartFile.fromFile(filePath),
    });
    return _dio.post('/payments/$paymentId/upload_proof/', data: form);
  }

  Future<Response> confirmPaymentProof(int paymentId) async {
    return _dio.post('/payments/$paymentId/confirm_proof/');
  }

  Future<Response> rejectPaymentProof(int paymentId) async {
    return _dio.post('/payments/$paymentId/reject_proof/');
  }

  // Recurring / scheduled orders
  Future<Response> getRecurringOrders() async {
    return _dio.get('/recurring-orders/');
  }

  Future<Response> createRecurringOrder(Map<String, dynamic> data) async {
    return _dio.post('/recurring-orders/', data: data);
  }

  Future<Response> updateRecurringOrder(int id, Map<String, dynamic> data) async {
    return _dio.patch('/recurring-orders/$id/', data: data);
  }

  Future<Response> deleteRecurringOrder(int id) async {
    return _dio.delete('/recurring-orders/$id/');
  }
}


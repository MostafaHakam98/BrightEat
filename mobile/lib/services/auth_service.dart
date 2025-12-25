import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  final ApiService apiService;
  final SharedPreferences prefs;

  AuthService(this.apiService, this.prefs);

  Future<Map<String, dynamic>> login(String usernameOrEmail, String password) async {
    try {
      final response = await apiService.login(usernameOrEmail, password);
      final accessToken = response.data['access'];
      final refreshToken = response.data['refresh'];

      await prefs.setString('access_token', accessToken);
      await prefs.setString('refresh_token', refreshToken);

      return {'success': true};
    } on DioException catch (e) {
      // Handle Dio errors (network, HTTP errors)
      String errorMessage = 'Login failed';
      if (e.response != null) {
        // Server responded with error
        final data = e.response?.data;
        if (data is Map && data.containsKey('detail')) {
          errorMessage = data['detail'].toString();
        } else if (data is Map && data.containsKey('non_field_errors')) {
          errorMessage = data['non_field_errors'][0].toString();
        } else if (data is Map && data.containsKey('username')) {
          errorMessage = data['username'][0].toString();
        } else if (data is Map && data.containsKey('email')) {
          errorMessage = data['email'][0].toString();
        } else {
          errorMessage = 'Invalid credentials';
        }
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Connection timeout. Please check your internet connection.';
      } else if (e.type == DioExceptionType.connectionError) {
        final baseUrl = ApiService.baseUrl;
        errorMessage = 'Cannot connect to server. Please check:\n'
            '1. Server is running at $baseUrl\n'
            '2. Device/emulator can reach the server\n'
            '3. For Android emulator, use 10.0.2.2 instead of IP\n'
            '4. Check firewall settings';
      }
      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      await apiService.register(userData);
      return {'success': true};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      final response = await apiService.getCurrentUser();
      return User.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> updateProfile(int userId, Map<String, dynamic> data) async {
    try {
      final response = await apiService.updateUser(userId, data);
      return {'success': true, 'data': User.fromJson(response.data)};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> changePassword(
    String oldPassword,
    String newPassword,
    String newPasswordConfirm,
  ) async {
    try {
      await apiService.changePassword({
        'old_password': oldPassword,
        'new_password': newPassword,
        'new_password_confirm': newPasswordConfirm,
      });
      return {'success': true};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<void> logout() async {
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  bool get isAuthenticated {
    final token = prefs.getString('access_token');
    return token != null && token.isNotEmpty;
  }
}


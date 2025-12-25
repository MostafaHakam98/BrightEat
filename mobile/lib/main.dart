import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/orders_service.dart';
import 'providers/auth_provider.dart';
import 'providers/orders_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/register_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/join_order_screen.dart';
import 'screens/create_order_screen.dart';
import 'screens/restaurants_screen.dart';
import 'screens/menu_management_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/pending_payments_screen.dart';
import 'screens/recommendations_screen.dart';
import 'screens/restaurant_wheel_screen.dart';
import 'screens/notifications_screen.dart';
import 'providers/notifications_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize shared preferences
  final prefs = await SharedPreferences.getInstance();
  
  // Initialize notification service
  await NotificationService().initialize();
  
  // Initialize API service
  final apiService = ApiService(prefs);
  
  // Initialize services
  final authService = AuthService(apiService, prefs);
  final ordersService = OrdersService(apiService);
  
  // Check if user is already logged in
  final token = prefs.getString('access_token');
  final isAuthenticated = token != null && token.isNotEmpty;
  
  runApp(MyApp(
    authService: authService,
    ordersService: ordersService,
    isAuthenticated: isAuthenticated,
  ));
}

class MyApp extends StatefulWidget {
  final AuthService authService;
  final OrdersService ordersService;
  final bool isAuthenticated;

  const MyApp({
    Key? key,
    required this.authService,
    required this.ordersService,
    required this.isAuthenticated,
  }) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

// Global variable to track previous route for transition direction
String? _previousRoute;

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _createRouter(widget.isAuthenticated);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(widget.authService)..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => OrdersProvider(widget.ordersService),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationsProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'OrderQ',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              brightness: Brightness.dark,
            ),
            themeMode: themeProvider.themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }

  // Helper function to determine transition direction
  int _getRouteIndex(String path) {
    const routeOrder = ['/', '/orders', '/wheel', '/profile'];
    return routeOrder.indexOf(path);
  }

  // Custom page class with direction-aware slide transition
  Page<T> _buildSlideTransition<T extends Object?>(
    Widget child,
    GoRouterState state,
    bool isForward,
  ) {
    return _DirectionalTransitionPage<T>(
      key: state.pageKey,
      child: child,
      isForward: isForward,
    );
  }

  GoRouter _createRouter(bool isAuthenticated) {
    // Capture instance methods for use in closures
    final getRouteIndex = _getRouteIndex;
    final buildSlideTransition = _buildSlideTransition;
    
    return GoRouter(
      initialLocation: isAuthenticated ? '/' : '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/',
          pageBuilder: (context, state) {
            final currentRoute = state.uri.path;
            final previousRoute = _previousRoute;
            _previousRoute = currentRoute;
            
            final previousIndex = previousRoute != null ? getRouteIndex(previousRoute) : -1;
            final currentIndex = getRouteIndex('/');
            final isForward = previousIndex != -1 && previousIndex < currentIndex;
            
            return buildSlideTransition(
              const HomeScreen(),
              state,
              isForward,
            );
          },
        ),
        GoRoute(
          path: '/orders',
          pageBuilder: (context, state) {
            final currentRoute = state.uri.path;
            final previousRoute = _previousRoute;
            _previousRoute = currentRoute;
            
            final previousIndex = previousRoute != null ? getRouteIndex(previousRoute) : -1;
            final currentIndex = getRouteIndex('/orders');
            final isForward = previousIndex != -1 && previousIndex < currentIndex;
            
            return buildSlideTransition(
              const OrdersScreen(),
              state,
              isForward,
            );
          },
        ),
        GoRoute(
          path: '/orders/create',
          builder: (context, state) {
            // Extract restaurant ID from query parameters if present
            final restaurantId = state.uri.queryParameters['restaurant'];
            return CreateOrderScreen(initialRestaurantId: restaurantId != null ? int.tryParse(restaurantId) : null);
          },
        ),
        GoRoute(
          path: '/orders/:code',
          builder: (context, state) {
            final code = state.pathParameters['code'] ?? '';
            return OrderDetailScreen(orderCode: code.toUpperCase());
          },
        ),
        GoRoute(
          path: '/join/:code',
          builder: (context, state) {
            final code = state.pathParameters['code'] ?? '';
            return JoinOrderScreen(orderCode: code.toUpperCase());
          },
        ),
        GoRoute(
          path: '/restaurants',
          builder: (context, state) => const RestaurantsScreen(),
        ),
        GoRoute(
          path: '/wheel',
          pageBuilder: (context, state) {
            final currentRoute = state.uri.path;
            final previousRoute = _previousRoute;
            _previousRoute = currentRoute;
            
            final previousIndex = previousRoute != null ? getRouteIndex(previousRoute) : -1;
            final currentIndex = getRouteIndex('/wheel');
            final isForward = previousIndex != -1 && previousIndex < currentIndex;
            
            return buildSlideTransition(
              const RestaurantWheelScreen(),
              state,
              isForward,
            );
          },
        ),
        GoRoute(
          path: '/restaurants/:restaurantId/menus',
          builder: (context, state) {
            final restaurantId = int.parse(state.pathParameters['restaurantId'] ?? '0');
            return MenuManagementScreen(restaurantId: restaurantId);
          },
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) {
            final currentRoute = state.uri.path;
            final previousRoute = _previousRoute;
            _previousRoute = currentRoute;
            
            final previousIndex = previousRoute != null ? getRouteIndex(previousRoute) : -1;
            final currentIndex = getRouteIndex('/profile');
            final isForward = previousIndex != -1 && previousIndex < currentIndex;
            
            return buildSlideTransition(
              const ProfileScreen(),
              state,
              isForward,
            );
          },
        ),
        GoRoute(
          path: '/pending-payments',
          builder: (context, state) => const PendingPaymentsScreen(),
        ),
        GoRoute(
          path: '/recommendations',
          builder: (context, state) => const RecommendationsScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
      ],
      redirect: (context, state) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final isAuth = authProvider.isAuthenticated;
        final isManager = authProvider.isManager;
        final isLoginRoute = state.uri.path == '/login';
        final isRegisterRoute = state.uri.path == '/register';
        final requiresAuth = !isLoginRoute && !isRegisterRoute;
        final requiresManager = state.uri.path.startsWith('/restaurants') ||
            state.uri.path.startsWith('/register');

        if (requiresAuth && !isAuth) {
          return '/login';
        }
        if (isAuth && (isLoginRoute || isRegisterRoute)) {
          return '/';
        }
        if (requiresManager && !isManager) {
          return '/';
        }
        return null;
      },
    );
  }
}

// Custom page class with direction-aware transitions
class _DirectionalTransitionPage<T> extends Page<T> {
  final Widget child;
  final bool isForward;

  const _DirectionalTransitionPage({
    required LocalKey key,
    required this.child,
    required this.isForward,
  }) : super(key: key);

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(
      settings: this,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: const Duration(milliseconds: 400), // Slower transition
      reverseTransitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOutCubic;
        
        // Determine slide direction based on isForward
        Offset begin;
        if (isForward) {
          // Moving forward (swipe left): slide from right to left
          begin = const Offset(1.0, 0.0);
        } else {
          // Moving backward (swipe right): slide from left to right
          begin = const Offset(-1.0, 0.0);
        }
        
        const end = Offset.zero;
        
        final slideAnimation = Tween<Offset>(
          begin: begin,
          end: end,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));
        
        // Fade animation for smoother transition
        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));
        
        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
    );
  }
}


import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'restaurant_wheel_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  
  const MainNavigationScreen({
    Key? key,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'OrderQ';
      case 1:
        return 'Orders';
      case 2:
        return 'Wheel';
      case 3:
        return 'Profile';
      default:
        return 'OrderQ';
    }
  }

  Widget _buildAppBar(int index) {
    final title = _getAppBarTitle(index);
    
    return AppBar(
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (index == 0) ...[
            Image.asset(
              'assets/images/logo.png',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: index == 0
          ? [
              IconButton(
                icon: const Icon(Icons.person),
                onPressed: () => context.push('/profile'),
                tooltip: 'Profile',
              ),
            ]
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: [
          // Home Screen
          Scaffold(
            appBar: _buildAppBar(0),
            body: const HomeScreenContent(),
          ),
          // Orders Screen
          Scaffold(
            appBar: _buildAppBar(1),
            body: const OrdersScreenContent(),
          ),
          // Wheel Screen
          Scaffold(
            appBar: _buildAppBar(2),
            body: const RestaurantWheelScreenContent(),
          ),
          // Profile Screen
          Scaffold(
            appBar: _buildAppBar(3),
            body: const ProfileScreenContent(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue[700],
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.casino),
            label: 'Wheel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onTap: _onTabTapped,
      ),
    );
  }
}

// Content widgets that extract just the body from each screen
class HomeScreenContent extends StatelessWidget {
  const HomeScreenContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}

class OrdersScreenContent extends StatelessWidget {
  const OrdersScreenContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const OrdersScreen();
  }
}

class RestaurantWheelScreenContent extends StatelessWidget {
  const RestaurantWheelScreenContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const RestaurantWheelScreen();
  }
}

class ProfileScreenContent extends StatelessWidget {
  const ProfileScreenContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen();
  }
}


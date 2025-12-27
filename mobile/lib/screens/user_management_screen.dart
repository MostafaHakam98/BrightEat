import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../models/user.dart';
import '../services/orders_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
      await ordersProvider.fetchUsers();
    } catch (e) {
      setState(() {
        _error = 'Failed to load users: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserRole(User user, String newRole) async {
    if (user.id == Provider.of<AuthProvider>(context, listen: false).user?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot change your own role'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
      final response = await ordersProvider.ordersService.apiService.updateUser(
        user.id,
        {'role': newRole},
      );

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User role updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadUsers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update role'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'manager':
        return 'Menu Manager';
      case 'user':
        return 'Normal User';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final ordersProvider = Provider.of<OrdersProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUsers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : ordersProvider.users.isEmpty
                  ? const Center(child: Text('No users found'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Manage user roles and permissions. Administrators can grant manager or admin permissions to users.',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...ordersProvider.users.map((user) {
                          final isCurrentUser = user.id == authProvider.user?.id;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user.username,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (isCurrentUser)
                                    Chip(
                                      label: const Text('You'),
                                      backgroundColor: Colors.blue.withOpacity(0.2),
                                      labelStyle: const TextStyle(fontSize: 10),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (user.email.isNotEmpty) Text(user.email),
                                  if (user.firstName != null || user.lastName != null)
                                    Text(
                                      '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim(),
                                    ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value: user.role,
                                    decoration: const InputDecoration(
                                      labelText: 'Role',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'user',
                                        child: Text('Normal User'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'manager',
                                        child: Text('Menu Manager'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'admin',
                                        child: Text('Administrator'),
                                      ),
                                    ],
                                    onChanged: isCurrentUser
                                        ? null
                                        : (value) {
                                            if (value != null && value != user.role) {
                                              _updateUserRole(user, value);
                                            }
                                          },
                                  ),
                                ],
                              ),
                              trailing: isCurrentUser
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.info_outline),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text(user.username),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Email: ${user.email}'),
                                                if (user.firstName != null || user.lastName != null)
                                                  Text('Name: ${user.firstName ?? ''} ${user.lastName ?? ''}'.trim()),
                                                Text('Role: ${_getRoleDisplayName(user.role)}'),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Close'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                              isThreeLine: true,
                            ),
                          );
                        }),
                      ],
                    ),
    );
  }
}


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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateMenuDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Menu'),
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
                  const SizedBox(height: 8),
                  Text(
                    'Create a menu to start adding items',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateMenuDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Menu'),
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
                      contentPadding: EdgeInsets.zero,
                      leading: item.isAvailable
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.cancel, color: Colors.red),
                      title: Text(item.name),
                      subtitle: Text(item.optionGroups.isEmpty
                          ? '${item.price.toStringAsFixed(2)} EGP'
                          : '${item.price.toStringAsFixed(2)} EGP · ${item.optionGroups.length} option group${item.optionGroups.length > 1 ? 's' : ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.tune, size: 20),
                            tooltip: 'Options',
                            onPressed: () =>
                                _showOptionsManager(context, menu, item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            tooltip: 'Edit',
                            onPressed: () => _showItemFormDialog(
                              context,
                              menu,
                              existing: item,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                size: 20, color: Colors.red),
                            tooltip: 'Delete',
                            onPressed: () => _deleteItem(context, menu, item),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showItemFormDialog(context, menu),
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCreateMenuDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Menu'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Menu name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a menu name'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final ordersProvider =
                  Provider.of<OrdersProvider>(context, listen: false);
              final svc = ordersProvider.ordersService;
              try {
                await svc.apiService.createMenu({
                  'restaurant': widget.restaurantId,
                  'name': name,
                });
                await ordersProvider.fetchMenus(
                    restaurantId: widget.restaurantId);
                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Menu created'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to create menu: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showItemFormDialog(
    BuildContext context,
    Menu menu, {
    MenuItem? existing,
  }) {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final priceController = TextEditingController(
        text: existing != null ? existing.price.toString() : '');
    final descController =
        TextEditingController(text: existing?.description ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEdit ? 'Edit Item' : 'Add Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price (EGP)'),
            ),
            TextField(
              controller: descController,
              decoration:
                  const InputDecoration(labelText: 'Description (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text.trim());
              if (name.isEmpty || price == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a name and a valid price'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final ordersProvider =
                  Provider.of<OrdersProvider>(context, listen: false);
              final svc = ordersProvider.ordersService;
              try {
                if (existing != null) {
                  await svc.apiService.updateMenuItem(existing.id, {
                    'name': name,
                    'price': price,
                    'description': descController.text.trim(),
                  });
                } else {
                  await svc.apiService.createMenuItem({
                    'menu': menu.id,
                    'name': name,
                    'price': price,
                    'description': descController.text.trim(),
                  });
                }
                await ordersProvider.fetchMenuItems(menuId: menu.id);
                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEdit ? 'Item updated' : 'Item added'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to save item: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }

  /// Mirror of the web "Manage Options" modal: option groups (e.g. "Size")
  /// with price-delta options, create/delete only (no in-place edit, same as
  /// web).
  void _showOptionsManager(BuildContext context, Menu menu, MenuItem item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        MenuItem current = item;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> reload() async {
              final ordersProvider =
                  Provider.of<OrdersProvider>(context, listen: false);
              await ordersProvider.fetchMenuItems(menuId: menu.id);
              final refreshed = ordersProvider.menuItems
                  .where((i) => i.id == item.id)
                  .toList();
              if (refreshed.isNotEmpty) {
                setDialogState(() => current = refreshed.first);
              }
            }

            Future<void> run(Future<void> Function() action) async {
              try {
                await action();
                await reload();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            final apiService = Provider.of<OrdersProvider>(context,
                    listen: false)
                .ordersService
                .apiService;

            return AlertDialog(
              title: Text('Options — ${current.name}'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: current.optionGroups.isEmpty
                    ? Center(
                        child: Text(
                          'No option groups yet.\nAdd one like "Size" or "Add-ons".',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView(
                        children: [
                          for (final group in current.optionGroups)
                            Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            group.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Text(
                                          '${group.isRequired ? 'Required' : 'Optional'} · '
                                          '${group.maxSelect == 1 ? 'choose one' : 'up to ${group.maxSelect}'}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600]),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              size: 18, color: Colors.red),
                                          tooltip: 'Delete group',
                                          onPressed: () async {
                                            final ok = await showDialog<bool>(
                                              context: context,
                                              builder: (c) => AlertDialog(
                                                title: const Text(
                                                    'Delete option group'),
                                                content: Text(
                                                    'Delete "${group.name}" and all its options?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            c, false),
                                                    child:
                                                        const Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                            backgroundColor:
                                                                Colors.red),
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            c, true),
                                                    child:
                                                        const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (ok == true) {
                                              await run(() => apiService
                                                  .deleteMenuItemOptionGroup(
                                                      group.id));
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    for (final option in group.options)
                                      Row(
                                        children: [
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              option.isDefault
                                                  ? '${option.name} (default)'
                                                  : option.name,
                                            ),
                                          ),
                                          Text(
                                            option.priceDelta == 0
                                                ? '—'
                                                : '${option.priceDelta > 0 ? '+' : ''}${option.priceDelta.toStringAsFixed(2)} EGP',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600]),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close,
                                                size: 16, color: Colors.red),
                                            tooltip: 'Delete option',
                                            onPressed: () => run(() =>
                                                apiService
                                                    .deleteMenuItemOption(
                                                        option.id)),
                                          ),
                                        ],
                                      ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Add option'),
                                        onPressed: () => _showAddOptionDialog(
                                            context, group.id, run),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () =>
                      _showAddGroupDialog(context, current.id, run),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Group'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddGroupDialog(
    BuildContext context,
    int menuItemId,
    Future<void> Function(Future<void> Function()) run,
  ) {
    final nameController = TextEditingController();
    final maxSelectController = TextEditingController(text: '1');
    bool isRequired = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Option Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Group name (e.g. Size)'),
              ),
              TextField(
                controller: maxSelectController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Max selections (1 = choose one)'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Required'),
                value: isRequired,
                onChanged: (v) => setDialogState(() => isRequired = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final maxSelect =
                    int.tryParse(maxSelectController.text.trim()) ?? 1;
                Navigator.pop(dialogContext);
                final ordersProvider =
                    Provider.of<OrdersProvider>(context, listen: false);
                await run(() => ordersProvider.ordersService.apiService
                    .createMenuItemOptionGroup({
                      'menu_item': menuItemId,
                      'name': name,
                      'is_required': isRequired,
                      'min_select': isRequired ? 1 : 0,
                      'max_select': maxSelect < 1 ? 1 : maxSelect,
                    }));
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOptionDialog(
    BuildContext context,
    int groupId,
    Future<void> Function(Future<void> Function()) run,
  ) {
    final nameController = TextEditingController();
    final deltaController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Option'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration:
                  const InputDecoration(labelText: 'Option name (e.g. Large)'),
            ),
            TextField(
              controller: deltaController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                  labelText: 'Price delta (EGP, e.g. 10 or -5)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final delta =
                  double.tryParse(deltaController.text.trim()) ?? 0.0;
              Navigator.pop(dialogContext);
              final ordersProvider =
                  Provider.of<OrdersProvider>(context, listen: false);
              await run(() => ordersProvider.ordersService.apiService
                  .createMenuItemOption({
                    'group': groupId,
                    'name': name,
                    'price_delta': delta.toStringAsFixed(2),
                  }));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(
      BuildContext context, Menu menu, MenuItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ordersProvider =
        Provider.of<OrdersProvider>(context, listen: false);
    final svc = ordersProvider.ordersService;
    try {
      await svc.apiService.deleteMenuItem(item.id);
      await ordersProvider.fetchMenuItems(menuId: menu.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


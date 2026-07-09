import 'user.dart';
import 'menu_item.dart';

/// Snapshot of one chosen option on an order line (immutable history).
class SelectedOption {
  final String group;
  final String name;
  final double priceDelta;

  SelectedOption({required this.group, required this.name, required this.priceDelta});

  factory SelectedOption.fromJson(Map<String, dynamic> json) {
    return SelectedOption(
      group: json['group'] ?? '',
      name: json['name'] ?? '',
      priceDelta: parseDouble(json['price_delta']) ?? 0.0,
    );
  }
}

class OrderItem {
  final int id;
  final int order;
  final User user;
  final MenuItem? menuItem;
  final String? customName;
  final double? customPrice;
  final double unitPrice;
  // Old unit price kept when a collector corrects an outdated price;
  // rendered struck-through so everyone can see it was updated.
  final double? previousUnitPrice;
  final int quantity;
  final double totalPrice;
  final String? note;
  final List<SelectedOption> selectedOptions;
  final bool? suggestAddToMenu;
  final bool? suggestUpdatePrice;
  final int? existingMenuItemId;

  OrderItem({
    required this.id,
    required this.order,
    required this.user,
    this.menuItem,
    this.customName,
    this.customPrice,
    required this.unitPrice,
    this.previousUnitPrice,
    required this.quantity,
    required this.totalPrice,
    this.note,
    this.selectedOptions = const [],
    this.suggestAddToMenu,
    this.suggestUpdatePrice,
    this.existingMenuItemId,
  });

  // Helper method to parse double from various types (int, double, String)
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    User userObj;
    if (json['user'] is Map<String, dynamic>) {
      userObj = User.fromJson(json['user'] as Map<String, dynamic>);
    } else if (json['user'] is Map) {
      userObj = User.fromJson(Map<String, dynamic>.from(json['user']));
    } else {
      userObj = User(
        id: json['user_id'] ?? (json['user'] is int ? json['user'] as int : 0),
        username: json['user_name'] ?? 'Unknown',
        email: '',
        role: 'user',
      );
    }

    MenuItem? menuItemObj;
    if (json['menu_item'] != null) {
      if (json['menu_item'] is Map<String, dynamic>) {
        menuItemObj = MenuItem.fromJson(json['menu_item'] as Map<String, dynamic>);
      } else if (json['menu_item'] is Map) {
        menuItemObj = MenuItem.fromJson(Map<String, dynamic>.from(json['menu_item']));
      } else if (json['menu_item'] is int) {
        // If menu_item is just an ID, try to get name from menu_item_name field
        // Some APIs return menu_item_name separately when menu_item is just an ID
        if (json['menu_item_name'] != null) {
          // Create a minimal MenuItem with just the name
          menuItemObj = MenuItem(
            id: json['menu_item'] as int,
            name: json['menu_item_name'] as String,
            price: _parseDouble(json['unit_price']) ?? 0.0,
            menu: json['menu_item_menu'] ?? 0,
            isAvailable: true,
          );
        } else {
          print('⚠️ Menu item is just an ID (${json['menu_item']}) without name. Item name may be missing.');
        }
      }
    }

    final rawOptions = (json['selected_options'] as List?) ?? [];

    return OrderItem(
      id: json['id'],
      order: json['order'],
      user: userObj,
      menuItem: menuItemObj,
      customName: json['custom_name'],
      customPrice: _parseDouble(json['custom_price']),
      unitPrice: _parseDouble(json['unit_price']) ?? 0.0,
      previousUnitPrice: _parseDouble(json['previous_unit_price']),
      quantity: json['quantity'],
      totalPrice: _parseDouble(json['total_price']) ?? 0.0,
      note: json['note'],
      selectedOptions: rawOptions
          .map((o) => SelectedOption.fromJson(Map<String, dynamic>.from(o as Map)))
          .toList(),
      suggestAddToMenu: json['suggest_add_to_menu'],
      suggestUpdatePrice: json['suggest_update_price'],
      existingMenuItemId: json['existing_menu_item_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order': order,
      'user': user.toJson(),
      'menu_item': menuItem?.toJson(),
      'custom_name': customName,
      'custom_price': customPrice,
      'unit_price': unitPrice,
      'quantity': quantity,
      'total_price': totalPrice,
    };
  }
}


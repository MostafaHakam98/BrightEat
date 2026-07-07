double? parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

/// A single selectable choice within a group, carrying a price delta.
class MenuItemOption {
  final int id;
  final String name;
  final double priceDelta;
  final bool isDefault;
  final bool isAvailable;

  MenuItemOption({
    required this.id,
    required this.name,
    required this.priceDelta,
    required this.isDefault,
    required this.isAvailable,
  });

  factory MenuItemOption.fromJson(Map<String, dynamic> json) {
    return MenuItemOption(
      id: json['id'],
      name: json['name'] ?? '',
      priceDelta: parseDouble(json['price_delta']) ?? 0.0,
      isDefault: json['is_default'] ?? false,
      isAvailable: json['is_available'] ?? true,
    );
  }
}

/// A group of options (e.g. "Size"). max_select == 1 is single-choice.
class MenuItemOptionGroup {
  final int id;
  final String name;
  final bool isRequired;
  final int minSelect;
  final int maxSelect;
  final List<MenuItemOption> options;

  MenuItemOptionGroup({
    required this.id,
    required this.name,
    required this.isRequired,
    required this.minSelect,
    required this.maxSelect,
    required this.options,
  });

  /// Minimum choices to satisfy the group (a required group needs at least 1).
  int get effectiveMin => isRequired ? (minSelect > 1 ? minSelect : 1) : minSelect;

  factory MenuItemOptionGroup.fromJson(Map<String, dynamic> json) {
    final rawOptions = (json['options'] as List?) ?? [];
    return MenuItemOptionGroup(
      id: json['id'],
      name: json['name'] ?? '',
      isRequired: json['is_required'] ?? false,
      minSelect: json['min_select'] ?? 0,
      maxSelect: json['max_select'] ?? 1,
      options: rawOptions
          .map((o) => MenuItemOption.fromJson(Map<String, dynamic>.from(o as Map)))
          .toList(),
    );
  }
}

class MenuItem {
  final int id;
  final String name;
  final String? description;
  final double price;
  final int menu;
  final bool isAvailable;
  final List<MenuItemOptionGroup> optionGroups;

  MenuItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.menu,
    required this.isAvailable,
    this.optionGroups = const [],
  });

  // Helper method to parse double from various types (int, double, String)
  static double? _parseDouble(dynamic value) => parseDouble(value);

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final rawGroups = (json['option_groups'] as List?) ?? [];
    return MenuItem(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: _parseDouble(json['price']) ?? 0.0,
      menu: json['menu'],
      isAvailable: json['is_available'] ?? true,
      optionGroups: rawGroups
          .map((g) => MenuItemOptionGroup.fromJson(Map<String, dynamic>.from(g as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'menu': menu,
      'is_available': isAvailable,
    };
  }
}


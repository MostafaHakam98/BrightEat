class MenuItem {
  final int id;
  final String name;
  final String? description;
  final double price;
  final int menu;
  final bool isAvailable;

  MenuItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.menu,
    required this.isAvailable,
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

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: _parseDouble(json['price']) ?? 0.0,
      menu: json['menu'],
      isAvailable: json['is_available'] ?? true,
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


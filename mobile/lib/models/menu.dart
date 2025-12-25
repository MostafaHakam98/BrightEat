class Menu {
  final int id;
  final String name;
  final String? description;
  final int restaurant;
  final bool isActive;

  Menu({
    required this.id,
    required this.name,
    this.description,
    required this.restaurant,
    required this.isActive,
  });

  factory Menu.fromJson(Map<String, dynamic> json) {
    return Menu(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      restaurant: json['restaurant'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'restaurant': restaurant,
      'is_active': isActive,
    };
  }
}


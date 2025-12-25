class Restaurant {
  final int id;
  final String name;
  final String? description;
  final int? createdBy;

  Restaurant({
    required this.id,
    required this.name,
    this.description,
    this.createdBy,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      createdBy: json['created_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_by': createdBy,
    };
  }
}


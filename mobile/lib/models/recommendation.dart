import 'user.dart';

class Recommendation {
  final int id;
  final User user;
  final String category;
  final String title;
  final String text;
  final DateTime createdAt;

  Recommendation({
    required this.id,
    required this.user,
    required this.category,
    required this.title,
    required this.text,
    required this.createdAt,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    User userObj;
    if (json['user'] is Map<String, dynamic>) {
      userObj = User.fromJson(json['user'] as Map<String, dynamic>);
    } else if (json['user'] is Map) {
      userObj = User.fromJson(Map<String, dynamic>.from(json['user']));
    } else {
      userObj = User(
        id: json['user_id'] ?? 0,
        username: json['user_name'] ?? 'Unknown',
        email: '',
        role: 'user',
      );
    }

    return Recommendation(
      id: json['id'],
      user: userObj,
      category: json['category'] ?? 'other',
      title: json['title'] ?? '',
      text: json['text'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user.toJson(),
      'category': category,
      'title': title,
      'text': text,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get categoryDisplay {
    switch (category) {
      case 'feature':
        return 'New Feature';
      case 'improvement':
        return 'Improvement';
      case 'bug':
        return 'Bug Report';
      case 'ui':
        return 'UI/UX';
      default:
        return 'Other';
    }
  }
}


import 'user.dart';
import 'restaurant.dart';
import 'menu.dart';
import 'order_item.dart';

class CollectionOrder {
  final int id;
  final String code;
  final Restaurant restaurant;
  final Menu? menu;
  final User collector;
  final String status;
  final DateTime createdAt;
  final DateTime? cutoffTime;
  final DateTime? lockedAt;
  final DateTime? orderedAt;
  final DateTime? closedAt;
  final double deliveryFee;
  final double tip;
  final double serviceFee;
  final String feeSplitRule;
  final bool isPrivate;
  final List<User>? assignedUsers;
  final List<OrderItem>? items;
  final List<Payment>? payments;
  final String? restaurantName;
  final String? collectorName;
  final String? instapayLink;
  final String? collectorInstapayLink;
  final String? collectorInstapayQrCodeUrl;
  final String? shareMessage;

  CollectionOrder({
    required this.id,
    required this.code,
    required this.restaurant,
    this.menu,
    required this.collector,
    required this.status,
    required this.createdAt,
    this.cutoffTime,
    this.lockedAt,
    this.orderedAt,
    this.closedAt,
    required this.deliveryFee,
    required this.tip,
    required this.serviceFee,
    required this.feeSplitRule,
    required this.isPrivate,
    this.assignedUsers,
    this.items,
    this.payments,
    this.restaurantName,
    this.collectorName,
    this.instapayLink,
    this.collectorInstapayLink,
    this.collectorInstapayQrCodeUrl,
    this.shareMessage,
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

  factory CollectionOrder.fromJson(Map<String, dynamic> json) {
    // Handle restaurant - can be Map, int, or null
    Restaurant restaurantObj;
    if (json['restaurant'] is Map<String, dynamic>) {
      restaurantObj = Restaurant.fromJson(json['restaurant'] as Map<String, dynamic>);
    } else if (json['restaurant'] is Map) {
      restaurantObj = Restaurant.fromJson(Map<String, dynamic>.from(json['restaurant']));
    } else if (json['restaurant'] is int) {
      restaurantObj = Restaurant(
        id: json['restaurant'],
        name: json['restaurant_name'] ?? 'Unknown',
      );
    } else {
      restaurantObj = Restaurant(id: 0, name: json['restaurant_name'] ?? 'Unknown');
    }

    // Handle menu - can be Map, int, or null
    Menu? menuObj;
    if (json['menu'] != null) {
      if (json['menu'] is Map<String, dynamic>) {
        menuObj = Menu.fromJson(json['menu'] as Map<String, dynamic>);
      } else if (json['menu'] is Map) {
        menuObj = Menu.fromJson(Map<String, dynamic>.from(json['menu']));
      } else if (json['menu'] is int) {
        menuObj = Menu(
          id: json['menu'],
          name: json['menu_name'] ?? 'Menu',
          restaurant: restaurantObj.id,
          isActive: true,
        );
      }
    }

    // Handle collector - can be Map or int
    User collectorObj;
    if (json['collector'] is Map<String, dynamic>) {
      collectorObj = User.fromJson(json['collector'] as Map<String, dynamic>);
    } else if (json['collector'] is Map) {
      collectorObj = User.fromJson(Map<String, dynamic>.from(json['collector']));
    } else if (json['collector'] is int) {
      collectorObj = User(
        id: json['collector'],
        username: json['collector_name'] ?? 'Unknown',
        email: '',
        role: 'user',
      );
    } else {
      collectorObj = User(
        id: 0,
        username: json['collector_name'] ?? 'Unknown',
        email: '',
        role: 'user',
      );
    }

    return CollectionOrder(
      id: json['id'],
      code: json['code'],
      restaurant: restaurantObj,
      menu: menuObj,
      collector: collectorObj,
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      cutoffTime: json['cutoff_time'] != null
          ? DateTime.parse(json['cutoff_time'])
          : null,
      lockedAt:
          json['locked_at'] != null ? DateTime.parse(json['locked_at']) : null,
      orderedAt: json['ordered_at'] != null
          ? DateTime.parse(json['ordered_at'])
          : null,
      closedAt:
          json['closed_at'] != null ? DateTime.parse(json['closed_at']) : null,
      deliveryFee: _parseDouble(json['delivery_fee']) ?? 0.0,
      tip: _parseDouble(json['tip']) ?? 0.0,
      serviceFee: _parseDouble(json['service_fee']) ?? 0.0,
      feeSplitRule: json['fee_split_rule'] ?? 'collector_pays',
      isPrivate: json['is_private'] ?? false,
      assignedUsers: json['assigned_users_details'] != null && json['assigned_users_details'] is List
          ? (json['assigned_users_details'] as List)
              .map((u) {
                if (u is Map<String, dynamic>) {
                  return User.fromJson(u);
                } else if (u is Map) {
                  return User.fromJson(Map<String, dynamic>.from(u));
                }
                return null;
              })
              .whereType<User>()
              .toList()
          : json['assigned_users'] != null && json['assigned_users'] is List
              ? (json['assigned_users'] as List)
                  .map((u) {
                    if (u is Map<String, dynamic>) {
                      return User.fromJson(u);
                    } else if (u is Map) {
                      return User.fromJson(Map<String, dynamic>.from(u));
                    } else if (u is int) {
                      // If it's just an ID, create a minimal User object
                      return User(
                        id: u,
                        username: 'User $u',
                        email: '',
                        role: 'user',
                      );
                    }
                    return null;
                  })
                  .whereType<User>()
                  .toList()
              : null,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((i) {
                if (i is Map<String, dynamic>) {
                  return OrderItem.fromJson(i);
                } else if (i is Map) {
                  return OrderItem.fromJson(Map<String, dynamic>.from(i));
                }
                // If it's not a Map, skip it (shouldn't happen, but handle gracefully)
                return null;
              })
              .whereType<OrderItem>()
              .toList()
          : null,
      payments: json['payments'] != null
          ? (json['payments'] as List)
              .map((p) {
                if (p is Map<String, dynamic>) {
                  return Payment.fromJson(p);
                } else if (p is Map) {
                  return Payment.fromJson(Map<String, dynamic>.from(p));
                }
                // If it's not a Map, skip it
                return null;
              })
              .whereType<Payment>()
              .toList()
          : null,
      restaurantName: json['restaurant_name'],
      collectorName: json['collector_name'],
      instapayLink: json['instapay_link'],
      collectorInstapayLink: json['collector_instapay_link'],
      collectorInstapayQrCodeUrl: json['collector_instapay_qr_code_url'],
      shareMessage: json['share_message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'restaurant': restaurant.toJson(),
      'menu': menu?.toJson(),
      'collector': collector.toJson(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'cutoff_time': cutoffTime?.toIso8601String(),
      'locked_at': lockedAt?.toIso8601String(),
      'ordered_at': orderedAt?.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'delivery_fee': deliveryFee,
      'tip': tip,
      'service_fee': serviceFee,
      'fee_split_rule': feeSplitRule,
      'is_private': isPrivate,
      'assigned_users': assignedUsers?.map((u) => u.toJson()).toList(),
      'items': items?.map((i) => i.toJson()).toList(),
      'payments': payments?.map((p) => p.toJson()).toList(),
    };
  }
}

class Payment {
  final int id;
  final int order;
  final User user;
  final double amount;
  final bool isPaid;
  final DateTime? paidAt;

  Payment({
    required this.id,
    required this.order,
    required this.user,
    required this.amount,
    required this.isPaid,
    this.paidAt,
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

  factory Payment.fromJson(Map<String, dynamic> json) {
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

    return Payment(
      id: json['id'] ?? 0,
      order: json['order'] ?? 0,
      user: userObj,
      amount: _parseDouble(json['amount']) ?? 0.0,
      isPaid: json['is_paid'] ?? false,
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order': order,
      'user': user.toJson(),
      'amount': amount,
      'is_paid': isPaid,
      'paid_at': paidAt?.toIso8601String(),
    };
  }
}


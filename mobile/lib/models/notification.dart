import 'package:flutter/material.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data; // Additional data like order code, order id, etc.

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => NotificationType.info,
      ),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      isRead: json['is_read'] ?? false,
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'data': data,
    };
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }
}

enum NotificationType {
  orderCreated,
  orderUpdated,
  orderLocked,
  orderOrdered,
  orderClosed,
  itemAdded,
  paymentReceived,
  paymentMarkedPaid,
  cutoffTimeReminder,
  info,
  warning,
  error,
}

extension NotificationTypeExtension on NotificationType {
  String get displayName {
    switch (this) {
      case NotificationType.orderCreated:
        return 'New Order';
      case NotificationType.orderUpdated:
        return 'Order Updated';
      case NotificationType.orderLocked:
        return 'Order Locked';
      case NotificationType.orderOrdered:
        return 'Order Placed';
      case NotificationType.orderClosed:
        return 'Order Closed';
      case NotificationType.itemAdded:
        return 'Item Added';
      case NotificationType.paymentReceived:
        return 'Payment Received';
      case NotificationType.paymentMarkedPaid:
        return 'Payment Marked Paid';
      case NotificationType.cutoffTimeReminder:
        return 'Cutoff Time Reminder';
      case NotificationType.info:
        return 'Info';
      case NotificationType.warning:
        return 'Warning';
      case NotificationType.error:
        return 'Error';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.orderCreated:
        return Icons.add_shopping_cart;
      case NotificationType.orderUpdated:
        return Icons.update;
      case NotificationType.orderLocked:
        return Icons.lock;
      case NotificationType.orderOrdered:
        return Icons.check_circle;
      case NotificationType.orderClosed:
        return Icons.close;
      case NotificationType.itemAdded:
        return Icons.add;
      case NotificationType.paymentReceived:
        return Icons.payment;
      case NotificationType.paymentMarkedPaid:
        return Icons.check_circle_outline;
      case NotificationType.cutoffTimeReminder:
        return Icons.access_time;
      case NotificationType.info:
        return Icons.info;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.error:
        return Icons.error;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.orderCreated:
        return Colors.blue;
      case NotificationType.orderUpdated:
        return Colors.orange;
      case NotificationType.orderLocked:
        return Colors.amber;
      case NotificationType.orderOrdered:
        return Colors.green;
      case NotificationType.orderClosed:
        return Colors.grey;
      case NotificationType.itemAdded:
        return Colors.blue;
      case NotificationType.paymentReceived:
        return Colors.green;
      case NotificationType.paymentMarkedPaid:
        return Colors.green;
      case NotificationType.cutoffTimeReminder:
        return Colors.orange;
      case NotificationType.info:
        return Colors.blue;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.error:
        return Colors.red;
    }
  }
}



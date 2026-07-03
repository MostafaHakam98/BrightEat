"""
Business logic shared between API views and Celery tasks.

Keeping payment math, notification fan-out, and the lock transition here means
the REST endpoint, the cutoff auto-lock task, and the test suite all exercise
the exact same code path.
"""
from decimal import Decimal, ROUND_HALF_UP

from django.utils import timezone

from .models import AuditLog, Notification, Payment
from .websocket_utils import broadcast_order_update, push_user_notifications


class CustomSplitError(ValueError):
    """Raised when a custom fee split is missing or doesn't add up."""


TWO_PLACES = Decimal('0.01')


def notify_users(users, message, order=None, notification_type='order_status', exclude_user=None):
    """Create in-app notifications and push them live over WebSocket."""
    notifications = [
        Notification(
            user=user,
            order=order,
            notification_type=notification_type,
            message=message,
        )
        for user in users
        if not (exclude_user and user == exclude_user)
    ]
    if not notifications:
        return []
    created = Notification.objects.bulk_create(notifications)
    push_user_notifications(created)
    return created


def notify_order_participants(order, message, notification_type='order_status', exclude_user=None):
    """Notify everyone involved in an order: item owners, joined/assigned users, collector."""
    return notify_users(
        order.get_notification_recipients(),
        message,
        order=order,
        notification_type=notification_type,
        exclude_user=exclude_user,
    )


def calculate_payments(order, custom_amounts=None):
    """(Re)create Payment rows for a locked order according to its fee split rule.

    custom_amounts: {user_id: amount} — required when fee_split_rule == 'custom';
    must cover every participant and sum to the order's total cost.
    """
    all_items = list(order.items.all())
    total_items = sum((item.total_price for item in all_items), Decimal('0'))
    total_fees = order.delivery_fee + order.tip + order.service_fee
    participants = list(order.get_participants())

    Payment.objects.filter(order=order).delete()

    def items_total_for(user):
        return sum(
            (item.total_price for item in all_items if item.user_id == user.id),
            Decimal('0'),
        )

    def create_payment(user, amount):
        amount = Decimal(amount).quantize(TWO_PLACES, rounding=ROUND_HALF_UP)
        is_collector = user == order.collector
        return Payment.objects.create(
            order=order,
            user=user,
            amount=amount,
            is_paid=is_collector,
            paid_at=timezone.now() if is_collector else None,
        )

    payments = []
    if order.fee_split_rule == 'custom':
        custom_amounts = {int(k): Decimal(str(v)) for k, v in (custom_amounts or {}).items()}
        participant_ids = {u.id for u in participants}
        missing = participant_ids - set(custom_amounts)
        if missing:
            names = ', '.join(u.username for u in participants if u.id in missing)
            raise CustomSplitError(f'Custom split is missing amounts for: {names}')
        if any(v < 0 for v in custom_amounts.values()):
            raise CustomSplitError('Custom split amounts cannot be negative.')
        total_expected = (total_items + total_fees).quantize(TWO_PLACES)
        total_given = sum(custom_amounts[uid] for uid in participant_ids).quantize(TWO_PLACES)
        if abs(total_given - total_expected) > TWO_PLACES:
            raise CustomSplitError(
                f'Custom split amounts sum to {total_given} but the order total is {total_expected}.'
            )
        for user in participants:
            payments.append(create_payment(user, custom_amounts[user.id]))
    elif order.fee_split_rule == 'collector_pays':
        for user in participants:
            payments.append(create_payment(user, items_total_for(user)))
    elif order.fee_split_rule == 'proportional':
        for user in participants:
            user_items = items_total_for(user)
            fee_share = (user_items / total_items) * total_fees if total_items > 0 else Decimal('0')
            payments.append(create_payment(user, user_items + fee_share))
    else:  # 'equal' (default)
        fee_per_person = total_fees / len(participants) if participants else Decimal('0')
        for user in participants:
            payments.append(create_payment(user, items_total_for(user) + fee_per_person))

    return payments


def lock_order(order, actor=None, custom_amounts=None):
    """Transition an OPEN order to LOCKED: payments, audit log, notifications, broadcast.

    Raises CustomSplitError before any state change if a custom split is invalid.
    The caller is responsible for permission checks and verifying status == OPEN.
    """
    if order.fee_split_rule == 'custom':
        # Validate up front so a bad split never leaves the order locked without payments.
        _validate_custom_amounts_shape(custom_amounts)

    order.status = 'LOCKED'
    order.locked_at = timezone.now()
    order.save(update_fields=['status', 'locked_at'])

    try:
        payments = calculate_payments(order, custom_amounts=custom_amounts)
    except CustomSplitError:
        order.status = 'OPEN'
        order.locked_at = None
        order.save(update_fields=['status', 'locked_at'])
        raise

    AuditLog.objects.create(
        order=order, user=actor, action='locked',
        details={} if actor else {'reason': 'cutoff_auto_lock'},
    )

    notify_order_participants(
        order,
        f'Order {order.code} at {order.restaurant.name} has been locked'
        + ('' if actor else ' automatically (cutoff time reached)') + '.',
        exclude_user=actor,
    )
    for payment in payments:
        if not payment.is_paid:
            notify_users(
                [payment.user],
                f'You owe {payment.amount} EGP to {order.collector.username} '
                f'for order {order.code} at {order.restaurant.name}.',
                order=order,
                notification_type='payment_due',
            )

    broadcast_order_update(order)
    return payments


def _validate_custom_amounts_shape(custom_amounts):
    if not custom_amounts or not isinstance(custom_amounts, dict):
        raise CustomSplitError(
            'This order uses a custom fee split — provide custom_amounts as {user_id: amount}.'
        )
    try:
        {int(k): Decimal(str(v)) for k, v in custom_amounts.items()}
    except (ValueError, TypeError, ArithmeticError):
        raise CustomSplitError('custom_amounts must map user ids to numeric amounts.')

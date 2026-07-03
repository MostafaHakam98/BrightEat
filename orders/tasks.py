"""
Celery tasks: menu syncing, cutoff enforcement, payment reminders.
"""
from datetime import timedelta

from celery import shared_task
from django.core.management import call_command
from django.utils import timezone
from io import StringIO
from contextlib import redirect_stdout
import logging

logger = logging.getLogger(__name__)

CUTOFF_REMINDER_WINDOW = timedelta(minutes=15)


@shared_task(name='enforce_order_cutoffs')
def enforce_order_cutoffs():
    """Runs every minute via beat. Two jobs:
    1. Warn everyone on an order ~15 minutes before its cutoff.
    2. Auto-lock OPEN orders whose cutoff has passed (or tell the collector if
       the order is empty and can't be locked).
    """
    from .models import CollectionOrder
    from .services import lock_order, notify_order_participants, notify_users

    now = timezone.now()
    reminded = locked = 0

    reminder_qs = CollectionOrder.objects.filter(
        status='OPEN',
        cutoff_reminder_sent=False,
        cutoff_time__gt=now,
        cutoff_time__lte=now + CUTOFF_REMINDER_WINDOW,
    ).select_related('restaurant', 'collector')
    for order in reminder_qs:
        minutes_left = max(1, int((order.cutoff_time - now).total_seconds() // 60))
        notify_order_participants(
            order,
            f'Order {order.code} at {order.restaurant.name} locks in about '
            f'{minutes_left} minutes — add your items now!',
        )
        order.cutoff_reminder_sent = True
        order.save(update_fields=['cutoff_reminder_sent'])
        reminded += 1

    lock_qs = CollectionOrder.objects.filter(
        status='OPEN',
        cutoff_processed=False,
        cutoff_time__lte=now,
    ).select_related('restaurant', 'collector')
    for order in lock_qs:
        # Custom splits need collector input, so they can't be auto-locked.
        if order.items.exists() and order.fee_split_rule != 'custom':
            lock_order(order, actor=None)
            locked += 1
        else:
            reason = (
                'it has no items'
                if not order.items.exists()
                else 'it uses a custom fee split (lock it manually with the amounts)'
            )
            notify_users(
                [order.collector],
                f'Order {order.code} at {order.restaurant.name} reached its cutoff '
                f'but was not auto-locked because {reason}.',
                order=order,
            )
        order.cutoff_processed = True
        order.save(update_fields=['cutoff_processed'])

    if reminded or locked:
        logger.info('Cutoff enforcement: %d reminded, %d auto-locked', reminded, locked)
    return {'reminded': reminded, 'auto_locked': locked}


@shared_task(name='send_web_push')
def send_web_push(user_ids, title, body, url='/'):
    """Best-effort Web Push to every subscription of the given users.
    Dead subscriptions (404/410 from the push service) are pruned."""
    from django.conf import settings
    from .models import PushSubscription

    private_key = getattr(settings, 'WEBPUSH_VAPID_PRIVATE_KEY', '')
    if not private_key:
        return {'sent': 0, 'skipped': 'vapid_not_configured'}

    import json as jsonlib
    from pywebpush import webpush, WebPushException

    payload = jsonlib.dumps({'title': title, 'body': body, 'url': url})
    claims_email = getattr(settings, 'WEBPUSH_VAPID_CLAIMS_EMAIL', 'admin@example.com')
    sent = pruned = 0

    for sub in PushSubscription.objects.filter(user_id__in=user_ids):
        try:
            webpush(
                subscription_info={
                    'endpoint': sub.endpoint,
                    'keys': {'p256dh': sub.p256dh, 'auth': sub.auth},
                },
                data=payload,
                vapid_private_key=private_key,
                vapid_claims={'sub': f'mailto:{claims_email}'},
            )
            sent += 1
        except WebPushException as exc:
            status_code = getattr(exc.response, 'status_code', None)
            if status_code in (404, 410):
                sub.delete()
                pruned += 1
            else:
                logger.warning('Web push failed for %s: %s', sub.user_id, exc)
        except Exception as exc:
            logger.warning('Web push error for %s: %s', sub.user_id, exc)

    return {'sent': sent, 'pruned': pruned}


@shared_task(name='purge_old_records')
def purge_old_records():
    """Daily retention sweep: notifications and audit logs grow unbounded otherwise."""
    from django.conf import settings
    from .models import AuditLog, Notification

    now = timezone.now()
    notif_days = getattr(settings, 'NOTIFICATION_RETENTION_DAYS', 90)
    audit_days = getattr(settings, 'AUDIT_LOG_RETENTION_DAYS', 365)

    notif_deleted, _ = Notification.objects.filter(
        created_at__lt=now - timedelta(days=notif_days)).delete()
    audit_deleted, _ = AuditLog.objects.filter(
        created_at__lt=now - timedelta(days=audit_days)).delete()

    if notif_deleted or audit_deleted:
        logger.info('Retention sweep: %d notifications, %d audit logs deleted',
                    notif_deleted, audit_deleted)
    return {'notifications_deleted': notif_deleted, 'audit_logs_deleted': audit_deleted}


@shared_task(name='send_payment_reminders')
def send_payment_reminders():
    """Runs daily via beat. Nags every debtor with an unpaid payment on a
    locked/ordered/closed order (one notification per unpaid payment)."""
    from .models import Payment
    from .services import notify_users

    unpaid = Payment.objects.filter(
        is_paid=False,
        order__status__in=['LOCKED', 'ORDERED', 'CLOSED'],
        created_at__lte=timezone.now() - timedelta(hours=12),
    ).select_related('user', 'order__collector', 'order__restaurant')

    count = 0
    for payment in unpaid:
        order = payment.order
        notify_users(
            [payment.user],
            f'Reminder: you still owe {payment.amount} EGP to {order.collector.username} '
            f'for order {order.code} at {order.restaurant.name}.',
            order=order,
            notification_type='payment_due',
        )
        count += 1

    if count:
        logger.info('Payment reminders sent: %d', count)
    return {'reminders_sent': count}


@shared_task(bind=True, name='sync_talabat_menus')
def sync_talabat_menus_task(self, talabat_url=None, manager_username='manager'):
    """
    Async Celery task to sync a single menu from Talabat by URL.

    The task updates its own state so callers can poll for progress:
      PENDING  → queued
      STARTED  → running
      SUCCESS  → { status, items_count, message }
      FAILURE  → exception message
    """
    logger.info('Starting Talabat sync for %s', talabat_url)
    self.update_state(state='STARTED', meta={'message': 'Fetching menu from Talabat…'})

    try:
        buf = StringIO()
        with redirect_stdout(buf):
            call_command(
                'sync_talabat_menus',
                talabat_url=talabat_url,
                manager=manager_username,
                verbosity=0,
            )

        # Count items for the synced menu
        from orders.models import Menu
        items_count = 0
        if talabat_url:
            menu = Menu.objects.filter(talabat_url=talabat_url).first()
            if menu:
                items_count = menu.items.count()

        result = {
            'status': 'success',
            'items_count': items_count,
            'message': f'Synced {items_count} items successfully.',
            'timestamp': timezone.now().isoformat(),
        }
        logger.info('Talabat sync completed: %s', result)
        return result

    except Exception as exc:
        logger.error('Talabat sync failed for %s: %s', talabat_url, exc, exc_info=True)
        raise


@shared_task(bind=True, name='sync_all_talabat_menus')
def sync_all_talabat_menus_task(self, manager_username='manager'):
    """Sync all menus that have a talabat_url configured."""
    from orders.models import Menu

    menus = list(Menu.objects.filter(talabat_url__isnull=False).exclude(talabat_url=''))
    total = len(menus)
    logger.info('Syncing %d Talabat menus', total)

    results = []
    for idx, menu in enumerate(menus, 1):
        self.update_state(
            state='STARTED',
            meta={'message': f'Syncing {menu.restaurant.name} ({idx}/{total})…'},
        )
        try:
            buf = StringIO()
            with redirect_stdout(buf):
                call_command(
                    'sync_talabat_menus',
                    talabat_url=menu.talabat_url,
                    manager=manager_username,
                    verbosity=0,
                )
            results.append({'restaurant': menu.restaurant.name, 'status': 'ok'})
        except Exception as exc:
            logger.error('Failed to sync %s: %s', menu.restaurant.name, exc)
            results.append({'restaurant': menu.restaurant.name, 'status': 'error', 'error': str(exc)})

    return {'status': 'success', 'synced': total, 'results': results, 'timestamp': timezone.now().isoformat()}

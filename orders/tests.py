import tempfile
from datetime import timedelta
from decimal import Decimal

from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status

from .models import (
    User, Restaurant, Menu, MenuItem,
    CollectionOrder, OrderItem, Payment, Notification, AuditLog, PushSubscription,
)
from .tasks import enforce_order_cutoffs, send_payment_reminders, purge_old_records

# 1×1 transparent GIF — the smallest payload Pillow accepts as an image
TINY_GIF = (b'GIF87a\x01\x00\x01\x00\x80\x01\x00\x00\x00\x00ccc,\x00\x00\x00\x00'
            b'\x01\x00\x01\x00\x00\x02\x02D\x01\x00;')


def make_user(username, role='user', password='testpass123'):
    return User.objects.create_user(username=username, password=password, role=role)


def get_token(client, username, password='testpass123'):
    res = client.post('/api/auth/login/', {'username': username, 'password': password}, format='json')
    return res.data.get('access')


class OrderLifecycleTest(TestCase):
    """Integration tests covering the full order lifecycle."""

    def setUp(self):
        cache.clear()  # reset the login throttle between tests
        self.client = APIClient()
        self.manager = make_user('mgr', role='manager')
        self.collector = make_user('collector')
        self.participant = make_user('participant')
        self.restaurant = Restaurant.objects.create(name='TestBurger', created_by=self.manager)
        self.menu = Menu.objects.create(restaurant=self.restaurant, name='Main Menu')
        self.item = MenuItem.objects.create(
            menu=self.menu, name='Burger', price=Decimal('50.00')
        )

    def _auth(self, user):
        token = get_token(self.client, user.username)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

    # ── 1. Health check ──────────────────────────────────────────────
    def test_health_check(self):
        res = self.client.get('/health/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json()['status'], 'ok')

    # ── 2. Login with bad credentials returns 400 ────────────────────
    def test_login_bad_credentials(self):
        res = self.client.post('/api/auth/login/', {'username': 'nobody', 'password': 'wrong'}, format='json')
        self.assertEqual(res.status_code, 400)

    # ── 3. Create order ──────────────────────────────────────────────
    def test_create_order(self):
        self._auth(self.collector)
        res = self.client.post('/api/orders/', {
            'restaurant': self.restaurant.id,
            'menu': self.menu.id,
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['status'], 'OPEN')
        self.assertEqual(res.data['collector_name'], 'collector')

    # ── 4. Add item to order ─────────────────────────────────────────
    def test_add_item_to_order(self):
        self._auth(self.collector)
        order_res = self.client.post('/api/orders/', {'restaurant': self.restaurant.id}, format='json')
        order_id = order_res.data['id']

        res = self.client.post('/api/order-items/', {
            'order': order_id,
            'menu_item': self.item.id,
            'quantity': 2,
            'unit_price': '50.00',
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['quantity'], 2)

    # ── 5. Cannot lock empty order ───────────────────────────────────
    def test_cannot_lock_empty_order(self):
        self._auth(self.collector)
        order_res = self.client.post('/api/orders/', {'restaurant': self.restaurant.id}, format='json')
        order_id = order_res.data['id']

        res = self.client.post(f'/api/orders/{order_id}/lock/')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    # ── 6. Lock order → payments created ────────────────────────────
    def test_lock_order_creates_payments(self):
        self._auth(self.collector)
        order_res = self.client.post('/api/orders/', {'restaurant': self.restaurant.id}, format='json')
        order_id = order_res.data['id']
        self.client.post('/api/order-items/', {
            'order': order_id, 'menu_item': self.item.id,
            'quantity': 1, 'unit_price': '50.00',
        }, format='json')

        res = self.client.post(f'/api/orders/{order_id}/lock/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['status'], 'LOCKED')
        self.assertTrue(Payment.objects.filter(order_id=order_id).exists())

    # ── 7. Mark as ordered ───────────────────────────────────────────
    def test_mark_as_ordered(self):
        self._auth(self.collector)
        order_res = self.client.post('/api/orders/', {'restaurant': self.restaurant.id}, format='json')
        order_id = order_res.data['id']
        self.client.post('/api/order-items/', {
            'order': order_id, 'menu_item': self.item.id,
            'quantity': 1, 'unit_price': '50.00',
        }, format='json')
        self.client.post(f'/api/orders/{order_id}/lock/')

        res = self.client.post(f'/api/orders/{order_id}/mark_ordered/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['status'], 'ORDERED')

    # ── 8. Close order ───────────────────────────────────────────────
    def test_close_order(self):
        self._auth(self.collector)
        order_res = self.client.post('/api/orders/', {'restaurant': self.restaurant.id}, format='json')
        order_id = order_res.data['id']
        self.client.post('/api/order-items/', {
            'order': order_id, 'menu_item': self.item.id,
            'quantity': 1, 'unit_price': '50.00',
        }, format='json')
        self.client.post(f'/api/orders/{order_id}/lock/')
        self.client.post(f'/api/orders/{order_id}/mark_ordered/')

        res = self.client.post(f'/api/orders/{order_id}/close/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['status'], 'CLOSED')

    # ── 9. Soft-delete: order disappears from list ───────────────────
    def test_soft_delete_order(self):
        self._auth(self.collector)
        order_res = self.client.post('/api/orders/', {'restaurant': self.restaurant.id}, format='json')
        order_id = order_res.data['id']

        del_res = self.client.delete(f'/api/orders/{order_id}/')
        self.assertEqual(del_res.status_code, status.HTTP_204_NO_CONTENT)

        order = CollectionOrder.objects.get(id=order_id)
        self.assertEqual(order.status, 'DELETED')

        list_res = self.client.get('/api/orders/')
        ids = [o['id'] for o in list_res.data['results']]
        self.assertNotIn(order_id, ids)

    # ── 10. Notifications created on lock ────────────────────────────
    def test_notifications_on_lock(self):
        # collector creates order, participant adds item
        self._auth(self.collector)
        order_res = self.client.post('/api/orders/', {'restaurant': self.restaurant.id}, format='json')
        order_id = order_res.data['id']
        self.client.post('/api/order-items/', {
            'order': order_id, 'menu_item': self.item.id,
            'quantity': 1, 'unit_price': '50.00',
        }, format='json')

        self._auth(self.participant)
        self.client.post('/api/order-items/', {
            'order': order_id, 'menu_item': self.item.id,
            'quantity': 1, 'unit_price': '50.00',
        }, format='json')

        self._auth(self.collector)
        self.client.post(f'/api/orders/{order_id}/lock/')

        # participant should now have a notification
        notifs = Notification.objects.filter(user=self.participant)
        self.assertTrue(notifs.exists())
        self.assertTrue(any('locked' in n.message.lower() for n in notifs))


class FeeSplitTest(TestCase):
    """The money math — every split rule, verified to the piaster."""

    def setUp(self):
        cache.clear()  # reset the login throttle between tests
        self.client = APIClient()
        self.collector = make_user('collector')
        self.alice = make_user('alice')
        self.restaurant = Restaurant.objects.create(name='R', created_by=self.collector)
        self.menu = Menu.objects.create(restaurant=self.restaurant, name='M')
        self.cheap = MenuItem.objects.create(menu=self.menu, name='Cheap', price=Decimal('50.00'))
        self.pricey = MenuItem.objects.create(menu=self.menu, name='Pricey', price=Decimal('150.00'))

    def _make_order(self, split_rule, delivery=Decimal('30.00'), tip=Decimal('20.00'), service=Decimal('10.00')):
        order = CollectionOrder.objects.create(
            restaurant=self.restaurant, collector=self.collector,
            fee_split_rule=split_rule,
            delivery_fee=delivery, tip=tip, service_fee=service,
        )
        # collector orders 50, alice orders 150 → items total 200, fees 60
        OrderItem.objects.create(order=order, user=self.collector, menu_item=self.cheap,
                                 quantity=1, unit_price=self.cheap.price)
        OrderItem.objects.create(order=order, user=self.alice, menu_item=self.pricey,
                                 quantity=1, unit_price=self.pricey.price)
        return order

    def _auth(self, user):
        token = get_token(self.client, user.username)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

    def _lock(self, order, payload=None):
        self._auth(self.collector)
        return self.client.post(f'/api/orders/{order.id}/lock/', payload or {}, format='json')

    def _amount(self, order, user):
        return Payment.objects.get(order=order, user=user).amount

    def test_equal_split(self):
        order = self._make_order('equal')
        res = self._lock(order)
        self.assertEqual(res.status_code, 200)
        # fees 60 / 2 = 30 each
        self.assertEqual(self._amount(order, self.collector), Decimal('80.00'))
        self.assertEqual(self._amount(order, self.alice), Decimal('180.00'))

    def test_proportional_split(self):
        order = self._make_order('proportional')
        self._lock(order)
        # collector: 50 + 60*(50/200)=15 → 65 ; alice: 150 + 45 → 195
        self.assertEqual(self._amount(order, self.collector), Decimal('65.00'))
        self.assertEqual(self._amount(order, self.alice), Decimal('195.00'))

    def test_collector_pays_split(self):
        order = self._make_order('collector_pays')
        self._lock(order)
        self.assertEqual(self._amount(order, self.collector), Decimal('50.00'))
        self.assertEqual(self._amount(order, self.alice), Decimal('150.00'))

    def test_collector_payment_auto_marked_paid(self):
        order = self._make_order('equal')
        self._lock(order)
        self.assertTrue(Payment.objects.get(order=order, user=self.collector).is_paid)
        self.assertFalse(Payment.objects.get(order=order, user=self.alice).is_paid)

    def test_custom_split_valid(self):
        order = self._make_order('custom')
        res = self._lock(order, {'custom_amounts': {
            str(self.collector.id): '100.00', str(self.alice.id): '160.00',
        }})
        self.assertEqual(res.status_code, 200)
        self.assertEqual(self._amount(order, self.collector), Decimal('100.00'))
        self.assertEqual(self._amount(order, self.alice), Decimal('160.00'))

    def test_custom_split_missing_amounts_rejected(self):
        order = self._make_order('custom')
        res = self._lock(order)
        self.assertEqual(res.status_code, 400)
        order.refresh_from_db()
        self.assertEqual(order.status, 'OPEN')
        self.assertFalse(Payment.objects.filter(order=order).exists())

    def test_custom_split_wrong_total_rejected(self):
        order = self._make_order('custom')
        res = self._lock(order, {'custom_amounts': {
            str(self.collector.id): '10.00', str(self.alice.id): '10.00',
        }})
        self.assertEqual(res.status_code, 400)
        order.refresh_from_db()
        self.assertEqual(order.status, 'OPEN')
        self.assertFalse(Payment.objects.filter(order=order).exists())


class JoinAndNotificationTest(TestCase):
    """Explicit join flow + the notification taxonomy."""

    def setUp(self):
        cache.clear()  # reset the login throttle between tests
        self.client = APIClient()
        self.collector = make_user('collector')
        self.alice = make_user('alice')
        self.restaurant = Restaurant.objects.create(name='R', created_by=self.collector)
        self.menu = Menu.objects.create(restaurant=self.restaurant, name='M')
        self.item = MenuItem.objects.create(menu=self.menu, name='X', price=Decimal('50.00'))
        self.order = CollectionOrder.objects.create(
            restaurant=self.restaurant, collector=self.collector,
        )

    def _auth(self, user):
        token = get_token(self.client, user.username)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

    def test_join_adds_to_roster_and_notifies_collector(self):
        self._auth(self.alice)
        res = self.client.post(f'/api/orders/{self.order.id}/join/')
        self.assertEqual(res.status_code, 200)
        self.assertTrue(self.order.joined_users.filter(id=self.alice.id).exists())
        notif = Notification.objects.get(user=self.collector, notification_type='order_joined')
        self.assertIn('alice', notif.message)

    def test_join_is_idempotent(self):
        self._auth(self.alice)
        self.client.post(f'/api/orders/{self.order.id}/join/')
        self.client.post(f'/api/orders/{self.order.id}/join/')
        self.assertEqual(
            Notification.objects.filter(user=self.collector, notification_type='order_joined').count(), 1)

    def test_join_rejected_when_not_open(self):
        self.order.status = 'LOCKED'
        self.order.save()
        self._auth(self.alice)
        res = self.client.post(f'/api/orders/{self.order.id}/join/')
        self.assertEqual(res.status_code, 400)

    def test_joined_user_without_items_notified_on_lock(self):
        # alice joins but never orders — she must still hear about the lock
        self._auth(self.alice)
        self.client.post(f'/api/orders/{self.order.id}/join/')
        self._auth(self.collector)
        self.client.post('/api/order-items/', {
            'order': self.order.id, 'menu_item': self.item.id,
            'quantity': 1, 'unit_price': '50.00',
        }, format='json')
        self.client.post(f'/api/orders/{self.order.id}/lock/')
        self.assertTrue(Notification.objects.filter(
            user=self.alice, notification_type='order_status',
            message__icontains='locked').exists())

    def test_payment_due_notification_on_lock(self):
        self._auth(self.alice)
        self.client.post(f'/api/orders/{self.order.id}/join/')
        self.client.post('/api/order-items/', {
            'order': self.order.id, 'menu_item': self.item.id,
            'quantity': 1, 'unit_price': '50.00',
        }, format='json')
        self._auth(self.collector)
        self.client.post(f'/api/orders/{self.order.id}/lock/')
        notif = Notification.objects.get(user=self.alice, notification_type='payment_due')
        self.assertIn('owe', notif.message)

    def test_payment_received_notification_on_mark_paid(self):
        self._auth(self.alice)
        self.client.post('/api/order-items/', {
            'order': self.order.id, 'menu_item': self.item.id,
            'quantity': 1, 'unit_price': '50.00',
        }, format='json')
        self._auth(self.collector)
        self.client.post(f'/api/orders/{self.order.id}/lock/')

        payment = Payment.objects.get(order=self.order, user=self.alice)
        self._auth(self.alice)
        res = self.client.post(f'/api/payments/{payment.id}/mark_paid/')
        self.assertEqual(res.status_code, 200)
        self.assertTrue(Notification.objects.filter(
            user=self.collector, notification_type='payment_received').exists())


class CutoffEnforcementTest(TestCase):
    """The beat tasks: pre-cutoff reminder, auto-lock, and payment nagging."""

    def setUp(self):
        self.collector = make_user('collector')
        self.alice = make_user('alice')
        self.restaurant = Restaurant.objects.create(name='R', created_by=self.collector)
        self.menu = Menu.objects.create(restaurant=self.restaurant, name='M')
        self.item = MenuItem.objects.create(menu=self.menu, name='X', price=Decimal('50.00'))

    def _order(self, cutoff, with_items=True, split='equal'):
        order = CollectionOrder.objects.create(
            restaurant=self.restaurant, collector=self.collector,
            cutoff_time=cutoff, fee_split_rule=split,
        )
        if with_items:
            OrderItem.objects.create(order=order, user=self.alice, menu_item=self.item,
                                     quantity=1, unit_price=self.item.price)
        return order

    def test_reminder_sent_inside_window(self):
        order = self._order(timezone.now() + timedelta(minutes=10))
        result = enforce_order_cutoffs()
        self.assertEqual(result['reminded'], 1)
        order.refresh_from_db()
        self.assertTrue(order.cutoff_reminder_sent)
        self.assertTrue(Notification.objects.filter(
            user=self.alice, message__icontains='locks in').exists())
        # second run must not re-send
        self.assertEqual(enforce_order_cutoffs()['reminded'], 0)

    def test_no_reminder_outside_window(self):
        self._order(timezone.now() + timedelta(hours=2))
        self.assertEqual(enforce_order_cutoffs()['reminded'], 0)

    def test_auto_lock_past_cutoff(self):
        order = self._order(timezone.now() - timedelta(minutes=1))
        result = enforce_order_cutoffs()
        self.assertEqual(result['auto_locked'], 1)
        order.refresh_from_db()
        self.assertEqual(order.status, 'LOCKED')
        self.assertTrue(order.cutoff_processed)
        self.assertTrue(Payment.objects.filter(order=order, user=self.alice).exists())
        self.assertTrue(Notification.objects.filter(
            user=self.alice, notification_type='payment_due').exists())

    def test_empty_order_not_locked_but_collector_told(self):
        order = self._order(timezone.now() - timedelta(minutes=1), with_items=False)
        result = enforce_order_cutoffs()
        self.assertEqual(result['auto_locked'], 0)
        order.refresh_from_db()
        self.assertEqual(order.status, 'OPEN')
        self.assertTrue(order.cutoff_processed)
        self.assertTrue(Notification.objects.filter(
            user=self.collector, message__icontains='no items').exists())

    def test_custom_split_order_not_auto_locked(self):
        order = self._order(timezone.now() - timedelta(minutes=1), split='custom')
        enforce_order_cutoffs()
        order.refresh_from_db()
        self.assertEqual(order.status, 'OPEN')
        self.assertTrue(Notification.objects.filter(
            user=self.collector, message__icontains='custom fee split').exists())

    def test_payment_reminders(self):
        order = self._order(None)
        order.status = 'LOCKED'
        order.save()
        payment = Payment.objects.create(order=order, user=self.alice, amount=Decimal('80.00'))
        # too fresh → no reminder yet
        self.assertEqual(send_payment_reminders()['reminders_sent'], 0)
        Payment.objects.filter(id=payment.id).update(
            created_at=timezone.now() - timedelta(days=1))
        self.assertEqual(send_payment_reminders()['reminders_sent'], 1)
        self.assertTrue(Notification.objects.filter(
            user=self.alice, notification_type='payment_due',
            message__icontains='still owe').exists())
        # paid → nagging stops
        Payment.objects.filter(id=payment.id).update(is_paid=True)
        self.assertEqual(send_payment_reminders()['reminders_sent'], 0)


@override_settings(MEDIA_ROOT=tempfile.mkdtemp())
class PaymentProofTest(TestCase):
    """Proof upload → collector confirm/reject flow."""

    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.collector = make_user('collector')
        self.alice = make_user('alice')
        self.restaurant = Restaurant.objects.create(name='R', created_by=self.collector)
        self.order = CollectionOrder.objects.create(
            restaurant=self.restaurant, collector=self.collector, status='LOCKED')
        self.payment = Payment.objects.create(
            order=self.order, user=self.alice, amount=Decimal('80.00'))

    def _auth(self, user):
        token = get_token(self.client, user.username)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

    def _upload(self):
        self._auth(self.alice)
        return self.client.post(
            f'/api/payments/{self.payment.id}/upload_proof/',
            {'proof': SimpleUploadedFile('proof.gif', TINY_GIF, content_type='image/gif')},
            format='multipart')

    def test_upload_proof_notifies_collector(self):
        res = self._upload()
        self.assertEqual(res.status_code, 200)
        self.payment.refresh_from_db()
        self.assertEqual(self.payment.proof_status, 'claimed')
        self.assertFalse(self.payment.is_paid)
        self.assertTrue(Notification.objects.filter(
            user=self.collector, message__icontains='proof').exists())

    def test_only_payer_can_upload(self):
        self._auth(self.collector)
        res = self.client.post(
            f'/api/payments/{self.payment.id}/upload_proof/',
            {'proof': SimpleUploadedFile('proof.gif', TINY_GIF, content_type='image/gif')},
            format='multipart')
        self.assertEqual(res.status_code, 403)

    def test_confirm_proof_settles_payment(self):
        self._upload()
        self._auth(self.collector)
        res = self.client.post(f'/api/payments/{self.payment.id}/confirm_proof/')
        self.assertEqual(res.status_code, 200)
        self.payment.refresh_from_db()
        self.assertTrue(self.payment.is_paid)
        self.assertEqual(self.payment.proof_status, 'confirmed')
        self.assertTrue(Notification.objects.filter(
            user=self.alice, notification_type='payment_received',
            message__icontains='confirmed').exists())

    def test_reject_proof_notifies_payer(self):
        self._upload()
        self._auth(self.collector)
        res = self.client.post(f'/api/payments/{self.payment.id}/reject_proof/')
        self.assertEqual(res.status_code, 200)
        self.payment.refresh_from_db()
        self.assertFalse(self.payment.is_paid)
        self.assertEqual(self.payment.proof_status, 'rejected')
        self.assertTrue(Notification.objects.filter(
            user=self.alice, notification_type='payment_due',
            message__icontains='rejected').exists())

    def test_payer_cannot_confirm_own_proof(self):
        self._upload()
        res = self.client.post(f'/api/payments/{self.payment.id}/confirm_proof/')
        self.assertEqual(res.status_code, 403)


class MyUsualTest(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.alice = make_user('alice')
        self.restaurant = Restaurant.objects.create(name='R', created_by=self.alice)
        self.menu = Menu.objects.create(restaurant=self.restaurant, name='M')
        self.burger = MenuItem.objects.create(menu=self.menu, name='Burger', price=Decimal('50.00'))
        self.fries = MenuItem.objects.create(menu=self.menu, name='Fries', price=Decimal('20.00'))

    def _auth(self, user):
        token = get_token(self.client, user.username)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

    def test_returns_items_from_last_order(self):
        old = CollectionOrder.objects.create(restaurant=self.restaurant, collector=self.alice, status='CLOSED')
        OrderItem.objects.create(order=old, user=self.alice, menu_item=self.burger,
                                 quantity=2, unit_price=self.burger.price, note='no pickles')
        OrderItem.objects.create(order=old, user=self.alice, menu_item=self.fries,
                                 quantity=1, unit_price=self.fries.price)

        self._auth(self.alice)
        res = self.client.get(f'/api/restaurants/{self.restaurant.id}/my_usual/')
        self.assertEqual(res.status_code, 200)
        names = {i['name']: i for i in res.data['items']}
        self.assertEqual(set(names), {'Burger', 'Fries'})
        self.assertEqual(names['Burger']['quantity'], 2)
        self.assertEqual(names['Burger']['note'], 'no pickles')

    def test_empty_when_no_history(self):
        self._auth(self.alice)
        res = self.client.get(f'/api/restaurants/{self.restaurant.id}/my_usual/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['items'], [])

    def test_unavailable_items_excluded(self):
        old = CollectionOrder.objects.create(restaurant=self.restaurant, collector=self.alice, status='CLOSED')
        OrderItem.objects.create(order=old, user=self.alice, menu_item=self.burger,
                                 quantity=1, unit_price=self.burger.price)
        self.burger.is_available = False
        self.burger.save()
        self._auth(self.alice)
        res = self.client.get(f'/api/restaurants/{self.restaurant.id}/my_usual/')
        self.assertEqual(res.data['items'], [])


class PushSubscriptionTest(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.alice = make_user('alice')
        token = get_token(self.client, 'alice')
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

    def test_subscribe_and_unsubscribe(self):
        sub = {'endpoint': 'https://push.example/abc', 'keys': {'p256dh': 'k1', 'auth': 'a1'}}
        res = self.client.post('/api/push/subscribe/', sub, format='json')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(PushSubscription.objects.filter(user=self.alice).count(), 1)

        # Re-subscribing the same endpoint updates, not duplicates
        self.client.post('/api/push/subscribe/', sub, format='json')
        self.assertEqual(PushSubscription.objects.count(), 1)

        res = self.client.post('/api/push/unsubscribe/',
                               {'endpoint': sub['endpoint']}, format='json')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(PushSubscription.objects.count(), 0)

    def test_public_key_disabled_without_config(self):
        res = self.client.get('/api/push/public_key/')
        self.assertEqual(res.status_code, 200)
        self.assertFalse(res.data['enabled'])


class RetentionTest(TestCase):
    def test_purge_old_records(self):
        alice = make_user('alice')
        restaurant = Restaurant.objects.create(name='R', created_by=alice)
        order = CollectionOrder.objects.create(restaurant=restaurant, collector=alice)

        fresh_n = Notification.objects.create(user=alice, message='fresh')
        old_n = Notification.objects.create(user=alice, message='old')
        Notification.objects.filter(id=old_n.id).update(
            created_at=timezone.now() - timedelta(days=120))

        fresh_a = AuditLog.objects.create(order=order, user=alice, action='created')
        old_a = AuditLog.objects.create(order=order, user=alice, action='created')
        AuditLog.objects.filter(id=old_a.id).update(
            created_at=timezone.now() - timedelta(days=400))

        result = purge_old_records()
        self.assertEqual(result['notifications_deleted'], 1)
        self.assertEqual(result['audit_logs_deleted'], 1)
        self.assertTrue(Notification.objects.filter(id=fresh_n.id).exists())
        self.assertTrue(AuditLog.objects.filter(id=fresh_a.id).exists())


class ShareMessageCutoffTest(TestCase):
    """Regression: cutoff in share_message must render in Egypt time.
    Historically pytz was missing so a hardcoded +2h fallback ran — wrong in
    summer (Egypt DST = UTC+3) and users saw 3:00 PM turn into 1:00/2:00 PM."""

    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.collector = make_user('collector')
        self.restaurant = Restaurant.objects.create(name='R', created_by=self.collector)

    def test_share_message_renders_cairo_time(self):
        token = get_token(self.client, 'collector')
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

        # Naive local datetime exactly as the datetime-local input sends it
        res = self.client.post('/api/orders/', {
            'restaurant': self.restaurant.id,
            'cutoff_time': '2030-07-15T15:00',
        }, format='json')
        self.assertEqual(res.status_code, 201)
        self.assertIn('03:00 PM', res.data['share_message'])

        # Winter date too (no DST): still 3 PM
        res = self.client.post('/api/orders/', {
            'restaurant': self.restaurant.id,
            'cutoff_time': '2030-01-15T15:00',
        }, format='json')
        self.assertEqual(res.status_code, 201)
        self.assertIn('03:00 PM', res.data['share_message'])


class OpenMenuAccessTest(TestCase):
    """All authenticated users (role 'user') can manage restaurants/menus and
    use the Talabat integration — previously manager/admin-only."""

    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.user = make_user('regular')  # plain 'user' role
        token = get_token(self.client, 'regular')
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

    def test_user_can_create_restaurant_menu_and_item(self):
        res = self.client.post('/api/restaurants/', {'name': 'Koshary Corner'}, format='json')
        self.assertEqual(res.status_code, 201)
        restaurant_id = res.data['id']

        res = self.client.post('/api/menus/', {'restaurant': restaurant_id, 'name': 'Main'}, format='json')
        self.assertEqual(res.status_code, 201)
        menu_id = res.data['id']

        res = self.client.post('/api/menu-items/', {
            'menu': menu_id, 'name': 'Koshary', 'price': '45.00',
        }, format='json')
        self.assertEqual(res.status_code, 201)

    def test_user_can_add_from_talabat(self):
        res = self.client.post('/api/restaurants/add_from_talabat/', {
            'talabat_url': 'https://www.talabat.com/egypt/restaurant/123/test',
            'sync_now': False,
        }, format='json')
        self.assertNotEqual(res.status_code, 403)

    def test_user_can_trigger_sync(self):
        restaurant = Restaurant.objects.create(name='NoTalabat', created_by=self.user)
        res = self.client.post(f'/api/restaurants/{restaurant.id}/sync_menu/')
        # 400 (no talabat URL configured) proves the request passed the old
        # manager-only gate — it must not be 403 anymore
        self.assertEqual(res.status_code, 400)

    def test_user_can_create_fee_preset(self):
        res = self.client.post('/api/fee-presets/', {
            'name': 'Standard', 'delivery_fee': '30.00', 'tip': '20.00',
            'service_fee': '0.00', 'fee_split_rule': 'equal',
        }, format='json')
        self.assertEqual(res.status_code, 201)

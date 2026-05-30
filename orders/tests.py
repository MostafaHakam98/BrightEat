from decimal import Decimal
from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient
from rest_framework import status

from .models import (
    User, Restaurant, Menu, MenuItem,
    CollectionOrder, OrderItem, Payment, Notification,
)


def make_user(username, role='user', password='testpass123'):
    return User.objects.create_user(username=username, password=password, role=role)


def get_token(client, username, password='testpass123'):
    res = client.post('/api/auth/login/', {'username': username, 'password': password}, format='json')
    return res.data.get('access')


class OrderLifecycleTest(TestCase):
    """Integration tests covering the full order lifecycle."""

    def setUp(self):
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
        self.assertEqual(res.data['collector']['username'], 'collector')

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
        self.assertIn('locked', notifs.first().message.lower())

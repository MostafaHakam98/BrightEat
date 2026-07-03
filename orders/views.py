from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.exceptions import ValidationError
from rest_framework.throttling import AnonRateThrottle
from django.db.models import Q, Sum, Count
from django.utils import timezone
from django.db import transaction, IntegrityError, connection
from django.http import HttpResponse, JsonResponse
from decimal import Decimal
from datetime import timedelta
import csv
import io
import logging
from .models import (
    User, Restaurant, Menu, MenuItem, CollectionOrder,
    OrderItem, Payment, AuditLog, FeePreset, Recommendation, Notification
)
from .serializers import (
    UserSerializer, UserRegistrationSerializer, LoginSerializer, ChangePasswordSerializer,
    RestaurantSerializer, MenuSerializer, MenuItemSerializer, CollectionOrderSerializer,
    OrderItemSerializer, PaymentSerializer, AuditLogSerializer, FeePresetSerializer,
    RecommendationSerializer, NotificationSerializer
)
from .utils import format_item_name
from .websocket_utils import broadcast_order_update, broadcast_new_order
from .services import (
    CustomSplitError, lock_order, notify_users,
    notify_order_participants as _notify_order_participants,
)
from rest_framework_simplejwt.tokens import RefreshToken

logger = logging.getLogger(__name__)


class HealthCheckView(APIView):
    """Simple health check: verifies the app is up and DB is reachable."""
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        try:
            connection.ensure_connection()
            return JsonResponse({'status': 'ok', 'database': 'ok'})
        except Exception as exc:
            logger.error('Health check DB failure: %s', exc)
            return JsonResponse({'status': 'error', 'database': str(exc)}, status=503)


class IsManagerOrReadOnly(permissions.BasePermission):
    """Permission for managers and admins to edit, others can only read"""
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True
        return request.user.is_authenticated and request.user.role in ['manager', 'admin']


class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None  # Disable pagination for users - needed for assignment feature
    
    def get_queryset(self):
        # All authenticated users can see all users (needed for assignment feature)
        return User.objects.all().order_by('username')  # Order by username for better UX
    
    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
    
    def update(self, request, *args, **kwargs):
        """Override update to check permissions for role changes"""
        instance = self.get_object()

        # Regular users can only update their own profile
        if request.user.role not in ['admin', 'manager'] and instance.id != request.user.id:
            return Response(
                {'error': 'You can only update your own profile'},
                status=status.HTTP_403_FORBIDDEN
            )

        if 'role' in request.data:
            if request.user.role != 'admin':
                return Response(
                    {'error': 'Only administrators can change user roles'},
                    status=status.HTTP_403_FORBIDDEN
                )
            if instance.id == request.user.id and request.data.get('role') != 'admin':
                return Response(
                    {'error': 'You cannot remove your own administrator role'},
                    status=status.HTTP_400_BAD_REQUEST
                )

        return super().update(request, *args, **kwargs)
    
    def partial_update(self, request, *args, **kwargs):
        """Override partial_update to check permissions for role changes"""
        kwargs['partial'] = True
        return self.update(request, *args, **kwargs)
    
    @action(detail=False, methods=['get'])
    def me(self, request):
        serializer = self.get_serializer(request.user)
        return Response(serializer.data)
    
    @action(detail=False, methods=['post'])
    def change_password(self, request):
        """Change user password"""
        serializer = ChangePasswordSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            user = request.user
            user.set_password(serializer.validated_data['new_password'])
            user.save()
            return Response({'message': 'Password changed successfully'}, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['post'], url_path='set_password')
    def set_password(self, request, pk=None):
        """Admin-only: set a password for any user without knowing the current one."""
        if request.user.role != 'admin':
            return Response({'error': 'Only administrators can set passwords for other users'},
                            status=status.HTTP_403_FORBIDDEN)
        new_password = request.data.get('new_password', '')
        if not new_password or len(new_password) < 8:
            return Response({'error': 'Password must be at least 8 characters'},
                            status=status.HTTP_400_BAD_REQUEST)
        user = self.get_object()
        user.set_password(new_password)
        user.save()
        return Response({'message': f'Password set for {user.username}'})


class LoginRateThrottle(AnonRateThrottle):
    scope = 'login'


class LoginView(APIView):
    """Custom login view that accepts username or email"""
    permission_classes = [permissions.AllowAny]
    throttle_classes = [LoginRateThrottle]
    
    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.validated_data['user']
            refresh = RefreshToken.for_user(user)
            return Response({
                'access': str(refresh.access_token),
                'refresh': str(refresh),
            }, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class RegisterView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        # Only admins can create accounts
        if request.user.role != 'admin':
            return Response(
                {'error': 'Only administrators can create user accounts'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        serializer = UserRegistrationSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            return Response({
                'user': UserSerializer(user).data,
                'message': 'User created successfully'
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class RestaurantViewSet(viewsets.ModelViewSet):
    queryset = Restaurant.objects.all()
    serializer_class = RestaurantSerializer
    permission_classes = [IsManagerOrReadOnly]
    
    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)

    @action(detail=False, methods=['post'])
    def add_from_talabat(self, request):
        """
        Add a restaurant from Talabat URL.
        Accepts: { "talabat_url": "...", "sync_now": true/false }
        Returns 201 immediately; if sync_now=true, enqueues an async Celery task
        and returns task_id so the frontend can poll for status.
        """
        if request.user.role not in ['manager', 'admin']:
            return Response(
                {'error': 'Only managers or administrators can add restaurants from Talabat'},
                status=status.HTTP_403_FORBIDDEN
            )

        talabat_url = request.data.get('talabat_url')
        sync_now = request.data.get('sync_now', False)

        if not talabat_url:
            return Response({'error': 'talabat_url is required'}, status=status.HTTP_400_BAD_REQUEST)

        if not talabat_url.startswith('https://www.talabat.com/'):
            return Response(
                {'error': 'Invalid Talabat URL. Must start with https://www.talabat.com/'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Derive restaurant name from URL slug
        import sys
        from django.conf import settings as django_settings
        scripts_dir = django_settings.BASE_DIR / 'scripts'
        if scripts_dir.exists() and str(scripts_dir) not in sys.path:
            sys.path.insert(0, str(scripts_dir))
        try:
            from talabat_scrap import parse_url_parts
            url_info = parse_url_parts(talabat_url)
            restaurant_name = url_info.get('branch_slug', 'restaurant').replace('-', ' ').title()
        except Exception:
            restaurant_name = 'Talabat Restaurant'

        # Prevent duplicates
        existing_menu = Menu.objects.filter(talabat_url=talabat_url).first()
        if existing_menu:
            return Response(
                {
                    'error': 'Restaurant with this Talabat URL already exists',
                    'restaurant': RestaurantSerializer(existing_menu.restaurant).data,
                    'menu': MenuSerializer(existing_menu).data,
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            with transaction.atomic():
                restaurant = Restaurant.objects.create(
                    name=restaurant_name,
                    description='Auto-added from Talabat',
                    created_by=request.user,
                )
                menu = Menu.objects.create(
                    restaurant=restaurant,
                    name='Main Menu',
                    is_active=True,
                    talabat_url=talabat_url,
                )

            task_id = None
            if sync_now:
                from .tasks import sync_talabat_menus_task
                task = sync_talabat_menus_task.delay(
                    talabat_url=talabat_url,
                    manager_username=request.user.username,
                )
                task_id = task.id

            response_data = {
                'restaurant': RestaurantSerializer(restaurant).data,
                'menu': MenuSerializer(menu).data,
                'message': 'Restaurant added successfully.' + (
                    ' Menu sync started in the background.' if sync_now else
                    ' Use the sync endpoint to populate the menu.'
                ),
            }
            if task_id:
                response_data['task_id'] = task_id

            return Response(response_data, status=status.HTTP_201_CREATED)

        except Exception as e:
            return Response(
                {'error': f'Failed to create restaurant: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=True, methods=['post'])
    def sync_menu(self, request, pk=None):
        """
        Enqueue an async Celery task to sync the menu for this restaurant from Talabat.
        Returns 202 Accepted with a task_id; poll GET /api/task-status/{task_id}/ for progress.
        """
        if request.user.role not in ['manager', 'admin']:
            return Response(
                {'error': 'Only managers or administrators can sync menus'},
                status=status.HTTP_403_FORBIDDEN
            )

        restaurant = self.get_object()
        menu = restaurant.menus.filter(talabat_url__isnull=False).exclude(talabat_url='').first()

        if not menu:
            return Response(
                {'error': 'No Talabat URL found for this restaurant'},
                status=status.HTTP_400_BAD_REQUEST
            )

        from .tasks import sync_talabat_menus_task
        task = sync_talabat_menus_task.delay(
            talabat_url=menu.talabat_url,
            manager_username=request.user.username,
        )

        return Response(
            {
                'task_id': task.id,
                'message': 'Menu sync started. Poll /api/task-status/{task_id}/ for progress.',
            },
            status=status.HTTP_202_ACCEPTED
        )


class MenuViewSet(viewsets.ModelViewSet):
    queryset = Menu.objects.all()
    serializer_class = MenuSerializer
    permission_classes = [IsManagerOrReadOnly]
    
    def get_queryset(self):
        restaurant_id = self.request.query_params.get('restaurant')
        if restaurant_id:
            return Menu.objects.filter(restaurant_id=restaurant_id)
        return Menu.objects.all()
    
    def perform_create(self, serializer):
        serializer.save()


class MenuItemViewSet(viewsets.ModelViewSet):
    queryset = MenuItem.objects.all()
    serializer_class = MenuItemSerializer
    permission_classes = [IsManagerOrReadOnly]
    pagination_class = None  # Disable pagination for menu items - show all items
    
    def get_queryset(self):
        menu_id = self.request.query_params.get('menu')
        restaurant_id = self.request.query_params.get('restaurant')
        queryset = MenuItem.objects.all()
        
        if menu_id:
            queryset = queryset.filter(menu_id=menu_id)
        elif restaurant_id:
            queryset = queryset.filter(menu__restaurant_id=restaurant_id)
        
        return queryset.order_by('section_name', 'name')  # Order by section and name for better UX
    
    def perform_create(self, serializer):
        serializer.save()


class CollectionOrderViewSet(viewsets.ModelViewSet):
    queryset = CollectionOrder.objects.all()
    serializer_class = CollectionOrderSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        status_filter = self.request.query_params.get('status')
        queryset = CollectionOrder.objects.exclude(status='DELETED').select_related(
            'restaurant', 'menu', 'collector'
        ).prefetch_related(
            'items__user', 'items__menu_item',
            'payments__user',
            'assigned_users', 'joined_users',
        )

        if status_filter:
            queryset = queryset.filter(status=status_filter)

        if user.role not in ['manager', 'admin']:
            queryset = queryset.filter(
                Q(is_private=False) |
                Q(collector=user) |
                Q(items__user=user) |
                Q(assigned_users=user)
            ).distinct()

        return queryset
    
    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
    
    def perform_create(self, serializer):
        assigned_users = serializer.validated_data.pop('assigned_users', [])
        order = serializer.save(collector=self.request.user)
        
        # If assigned_users is provided, set them and make order private
        if assigned_users:
            order.assigned_users.set(assigned_users)
            order.is_private = True
            order.save()
        
        # Note: Order can be created without items initially, but items should be added before locking
        # This allows for flexibility in order creation workflow
        
        AuditLog.objects.create(
            order=order,
            user=self.request.user,
            action='created',
            details={'restaurant': order.restaurant.name, 'assigned_users': [u.username for u in assigned_users] if assigned_users else None}
        )
        
        # Broadcast new order event to all connected clients
        broadcast_new_order(order)
    
    def update(self, request, *args, **kwargs):
        """Allow updating fees and assigned_users for open orders"""
        instance = self.get_object()
        
        # Handle assigned_users separately - many-to-many fields need special handling
        assigned_users_data = request.data.get('assigned_users')
        assignment_items = request.data.get('assignment_items')
        assignment_total_cost = request.data.get('assignment_total_cost')
        
        # Only check status for assigned_users updates, not for fee updates
        if assigned_users_data is not None and instance.status != 'OPEN':
            return Response(
                {'error': 'Can only update assigned users for open orders'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Check if this is a fee update - fees can only be updated when order is OPEN
        has_fee_update = any(key in request.data for key in ['delivery_fee', 'tip', 'service_fee', 'fee_split_rule'])
        if has_fee_update and instance.status != 'OPEN':
            return Response(
                {'error': 'Fees can only be updated when order is open'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Call parent update first (this handles other fields including fees)
        response = super().update(request, *args, **kwargs)
        
        # Now handle assigned_users if provided
        if assigned_users_data is not None:
            instance.refresh_from_db()
            if assigned_users_data:
                instance.assigned_users.set(assigned_users_data)
                instance.is_private = True
                
                # If assignment_items and assignment_total_cost are provided, create items for each assigned user
                if assignment_items and assignment_total_cost:
                    from decimal import Decimal
                    from .models import OrderItem
                    
                    num_users = len(assigned_users_data)
                    if num_users > 0:
                        cost_per_user = Decimal(str(assignment_total_cost)) / Decimal(str(num_users))
                        unit_price = cost_per_user / Decimal(str(assignment_items))
                        
                        # Delete existing items for assigned users (to avoid duplicates)
                        OrderItem.objects.filter(
                            order=instance,
                            user__in=assigned_users_data
                        ).delete()
                        
                        # Create items for each assigned user
                        for user_id in assigned_users_data:
                            user = User.objects.get(id=user_id)
                            for i in range(assignment_items):
                                OrderItem.objects.create(
                                    order=instance,
                                    user=user,
                                    custom_name=f"Shared Item {i+1}",
                                    custom_price=unit_price,
                                    quantity=1,
                                    unit_price=unit_price,
                                    total_price=unit_price
                                )
                        
                        AuditLog.objects.create(
                            order=instance,
                            user=request.user,
                            action='items_auto_created',
                            details={
                                'assigned_users': [u.username for u in User.objects.filter(id__in=assigned_users_data)],
                                'items_per_user': assignment_items,
                                'total_cost': float(assignment_total_cost),
                                'cost_per_user': float(cost_per_user)
                            }
                        )
            else:
                instance.assigned_users.clear()
            instance.save()
            # Return updated data with assigned_users
            serializer = self.get_serializer(instance, context={'request': request})
            # Broadcast order update via WebSocket
            broadcast_order_update(instance)
            return Response(serializer.data)
        
        # Broadcast order update via WebSocket (for fee updates, etc.)
        instance.refresh_from_db()
        broadcast_order_update(instance)
        
        return response
    
    def destroy(self, request, *args, **kwargs):
        order = self.get_object()
        if order.collector != request.user and request.user.role not in ['manager', 'admin']:
            return Response(
                {'error': 'Only collector, manager, or administrator can delete order'},
                status=status.HTTP_403_FORBIDDEN
            )

        if order.status != 'OPEN' and request.user.role not in ['manager', 'admin']:
            return Response(
                {'error': 'Can only delete open orders'},
                status=status.HTTP_400_BAD_REQUEST
            )

        AuditLog.objects.create(
            order=order,
            user=request.user,
            action='deleted',
            details={'restaurant': order.restaurant.name, 'code': order.code, 'status': order.status}
        )

        order.status = 'DELETED'
        order.save(update_fields=['status'])
        return Response(status=status.HTTP_204_NO_CONTENT)
    
    @action(detail=True, methods=['post'])
    def lock(self, request, pk=None):
        order = self.get_object()
        if order.status != 'OPEN':
            return Response(
                {'error': 'Order is not open'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if order.collector != request.user and request.user.role not in ['manager', 'admin']:
            return Response(
                {'error': 'Only collector, manager, or administrator can lock order'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Check if order has items before locking
        if not order.items.exists():
            return Response(
                {'error': 'Cannot lock an order without items. Please add items first.'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            lock_order(order, actor=request.user, custom_amounts=request.data.get('custom_amounts'))
        except CustomSplitError as exc:
            return Response({'error': str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(CollectionOrderSerializer(order).data)
    
    @action(detail=True, methods=['post'])
    def unlock(self, request, pk=None):
        order = self.get_object()
        if order.status != 'LOCKED':
            return Response(
                {'error': 'Order is not locked'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Collector, manager, or admin can unlock
        if order.collector != request.user and request.user.role not in ['manager', 'admin']:
            return Response(
                {'error': 'Only collector, manager, or administrator can unlock order'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        order.status = 'OPEN'
        order.locked_at = None
        order.save()
        
        # Delete payments when unlocking (they'll be recalculated on next lock)
        Payment.objects.filter(order=order).delete()
        
        AuditLog.objects.create(
            order=order,
            user=request.user,
            action='unlocked',
            details={}
        )
        
        # Broadcast order update via WebSocket
        broadcast_order_update(order)
        
        return Response(CollectionOrderSerializer(order).data)
    
    @action(detail=True, methods=['post'])
    def mark_ordered(self, request, pk=None):
        order = self.get_object()
        if order.status != 'LOCKED':
            return Response(
                {'error': 'Order must be locked first'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if order.collector != request.user:
            return Response(
                {'error': 'Only collector can mark as ordered'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        order.status = 'ORDERED'
        order.ordered_at = timezone.now()
        order.save()

        AuditLog.objects.create(order=order, user=request.user, action='ordered', details={})
        _notify_order_participants(
            order,
            f'Order {order.code} at {order.restaurant.name} has been placed!',
            exclude_user=request.user,
        )
        broadcast_order_update(order)
        return Response(CollectionOrderSerializer(order).data)
    
    @action(detail=True, methods=['post'])
    def close(self, request, pk=None):
        order = self.get_object()
        if order.status not in ['ORDERED', 'LOCKED']:
            return Response(
                {'error': 'Order must be ordered or locked first'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if order.collector != request.user and request.user.role not in ['manager', 'admin']:
            return Response(
                {'error': 'Only collector, manager, or administrator can close order'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        order.status = 'CLOSED'
        order.closed_at = timezone.now()
        order.save()

        AuditLog.objects.create(order=order, user=request.user, action='closed', details={})
        _notify_order_participants(
            order,
            f'Order {order.code} at {order.restaurant.name} is now closed.',
            exclude_user=request.user,
        )
        broadcast_order_update(order)
        return Response(CollectionOrderSerializer(order).data)
    
    @action(detail=True, methods=['post'])
    def join(self, request, pk=None):
        """Explicitly join an order (before adding any items). Adds the user to
        the roster, tells the collector, and broadcasts the updated order."""
        order = self.get_object()

        if order.status != 'OPEN':
            return Response(
                {'error': 'This order is no longer open'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Assigned (private) orders can only be joined by their assignees
        if order.assigned_users.exists():
            if (request.user not in order.assigned_users.all()
                    and order.collector != request.user
                    and request.user.role not in ['manager', 'admin']):
                return Response(
                    {'error': 'You are not assigned to this order'},
                    status=status.HTTP_403_FORBIDDEN
                )

        already_joined = order.joined_users.filter(id=request.user.id).exists()
        if not already_joined:
            order.joined_users.add(request.user)
            AuditLog.objects.create(
                order=order, user=request.user, action='user_joined',
                details={'username': request.user.username}
            )
            if order.collector != request.user:
                notify_users(
                    [order.collector],
                    f'{request.user.username} joined your order {order.code} at {order.restaurant.name}.',
                    order=order,
                    notification_type='order_joined',
                )
            broadcast_order_update(order)

        return Response(CollectionOrderSerializer(order, context={'request': request}).data)

    @action(detail=False, methods=['get'])
    def by_code(self, request):
        code = request.query_params.get('code')
        if not code:
            return Response(
                {'error': 'Code parameter required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            order = CollectionOrder.objects.get(code=code.upper())
            
            # Check if order has assigned users - if so, only they can access it
            if order.assigned_users.exists():
                if request.user not in order.assigned_users.all() and request.user.role not in ['manager', 'admin'] and order.collector != request.user:
                    return Response(
                        {'error': 'You are not assigned to this order'}, 
                        status=status.HTTP_403_FORBIDDEN
                    )
            
            serializer = self.get_serializer(order, context={'request': request})
            return Response(serializer.data)
        except CollectionOrder.DoesNotExist:
            return Response(
                {'error': 'Order not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
    
    @action(detail=True, methods=['post'])
    def transfer_collector(self, request, pk=None):
        """Transfer collector role to another participant"""
        order = self.get_object()
        new_collector_id = request.data.get('new_collector_id')
        
        if not new_collector_id:
            return Response(
                {'error': 'new_collector_id is required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Only current collector, manager, or admin can transfer
        if order.collector != request.user and request.user.role not in ['manager', 'admin']:
            return Response(
                {'error': 'Only collector, manager, or administrator can transfer collector role'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Only allow transfer if order is OPEN
        if order.status != 'OPEN':
            return Response(
                {'error': 'Can only transfer collector for open orders'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            new_collector = User.objects.get(id=new_collector_id)
        except User.DoesNotExist:
            return Response(
                {'error': 'User not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Check if new collector is a participant
        if not order.items.filter(user=new_collector).exists() and new_collector != order.collector:
            return Response(
                {'error': 'New collector must be a participant in the order'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        old_collector = order.collector
        order.collector = new_collector
        order.save()
        
        AuditLog.objects.create(
            order=order,
            user=request.user,
            action='fee_updated',
            details={'action': 'collector_transferred', 'old_collector': old_collector.username, 'new_collector': new_collector.username}
        )
        
        return Response(CollectionOrderSerializer(order, context={'request': request}).data)
    
    @action(detail=False, methods=['get'])
    def pending_payments(self, request):
        """Get all orders where the user has pending payments (payments user owes)"""
        payments = Payment.objects.filter(
            user=request.user,
            is_paid=False,
            order__status__in=['LOCKED', 'ORDERED', 'CLOSED']
        ).select_related('order', 'order__restaurant', 'order__collector')
        
        result = []
        for payment in payments:
            # Skip collector's payment if they are the collector (should be auto-paid)
            if payment.user == payment.order.collector:
                continue
            collector = payment.order.collector
            qr_url = None
            if collector.instapay_qr_code:
                qr_url = request.build_absolute_uri(collector.instapay_qr_code.url)
            result.append({
                'order_id': payment.order.id,
                'order_code': payment.order.code,
                'restaurant_name': payment.order.restaurant.name,
                'collector_name': collector.username,
                'amount': float(payment.amount),
                'payment_id': payment.id,
                'order_status': payment.order.status,
                'payment_type': 'owed_by_me',
                'collector_instapay_link': collector.instapay_link or '',
                'collector_instapay_qr_code_url': qr_url,
            })
        
        return Response(result)
    
    @action(detail=False, methods=['get'])
    def pending_payments_to_me(self, request):
        """Get all orders where others owe money to the user (when user is collector)"""
        payments = Payment.objects.filter(
            order__collector=request.user,
            is_paid=False,
            order__status__in=['LOCKED', 'ORDERED', 'CLOSED']
        ).exclude(user=request.user).select_related('order', 'order__restaurant', 'user')
        
        result = []
        for payment in payments:
            result.append({
                'order_id': payment.order.id,
                'order_code': payment.order.code,
                'restaurant_name': payment.order.restaurant.name,
                'payer_name': payment.user.username,
                'amount': float(payment.amount),
                'payment_id': payment.id,
                'order_status': payment.order.status,
                'payment_type': 'owed_to_me',  # Others owe this to user
            })
        
        return Response(result)
    
    @action(detail=False, methods=['get'])
    def monthly_report(self, request):
        """Monthly report: comprehensive dashboard with multiple metrics"""
        user_id = request.query_params.get('user_id', request.user.id)
        if request.user.role not in ['manager', 'admin'] and str(request.user.id) != str(user_id):
            return Response(
                {'error': 'Permission denied'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        user = User.objects.get(id=user_id)
        now = timezone.now()
        start_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        
        # Total spend (as participant)
        total_spend = Payment.objects.filter(
            user=user,
            order__created_at__gte=start_of_month
        ).aggregate(total=Sum('amount'))['total'] or 0
        
        # Number of times as collector
        collector_count = CollectionOrder.objects.filter(
            collector=user,
            created_at__gte=start_of_month
        ).count()
        
        # Unpaid incidents
        unpaid_count = Payment.objects.filter(
            user=user,
            is_paid=False,
            order__status__in=['LOCKED', 'ORDERED', 'CLOSED'],
            order__created_at__gte=start_of_month
        ).count()
        
        # Total amount collected (when user was collector)
        orders_collected = CollectionOrder.objects.filter(
            collector=user,
            created_at__gte=start_of_month
        )
        total_collected = Payment.objects.filter(
            order__in=orders_collected,
            order__created_at__gte=start_of_month
        ).exclude(user=user).aggregate(total=Sum('amount'))['total'] or 0
        
        # Total orders participated in (as participant, not necessarily collector)
        orders_participated = CollectionOrder.objects.filter(
            items__user=user,
            created_at__gte=start_of_month
        ).distinct()
        total_orders_participated = orders_participated.count()
        
        # Average order value — aggregate in DB, no Python loops
        from django.db.models import F
        order_totals = orders_participated.annotate(
            items_total=Sum('items__total_price'),
        ).aggregate(
            grand_total=Sum(F('items_total') + F('delivery_fee') + F('tip') + F('service_fee'))
        )
        avg_order_value = (
            float(order_totals['grand_total'] or 0) / total_orders_participated
            if total_orders_participated > 0 else 0
        )

        # Fees paid = total payments minus user's own item costs (single queries)
        total_fees_paid = Payment.objects.filter(
            user=user,
            order__created_at__gte=start_of_month
        ).aggregate(total=Sum('amount'))['total'] or 0
        total_item_costs = OrderItem.objects.filter(
            order__in=orders_participated, user=user
        ).aggregate(total=Sum('total_price'))['total'] or 0
        total_fees_only = float(total_fees_paid) - float(total_item_costs)

        # Payment completion rate — single aggregated query
        payment_stats = Payment.objects.filter(
            user=user,
            order__status__in=['LOCKED', 'ORDERED', 'CLOSED'],
            order__created_at__gte=start_of_month
        ).aggregate(
            total=Count('id'),
            paid=Count('id', filter=Q(is_paid=True)),
        )
        total_payments = payment_stats['total']
        payment_completion_rate = (
            payment_stats['paid'] / total_payments * 100 if total_payments > 0 else 100
        )
        
        # Most ordered restaurant
        restaurant_counts = CollectionOrder.objects.filter(
            items__user=user,
            created_at__gte=start_of_month
        ).values('restaurant__name').annotate(
            order_count=Count('id', distinct=True)
        ).order_by('-order_count')
        most_ordered_restaurant = restaurant_counts[0]['restaurant__name'] if restaurant_counts else None
        most_ordered_restaurant_count = restaurant_counts[0]['order_count'] if restaurant_counts else 0
        
        # Total pending amount (unpaid)
        total_pending = Payment.objects.filter(
            user=user,
            is_paid=False,
            order__status__in=['LOCKED', 'ORDERED', 'CLOSED'],
            order__created_at__gte=start_of_month
        ).aggregate(total=Sum('amount'))['total'] or 0
        
        # Total amount owed to user (when user is collector and others haven't paid)
        total_owed_to_user = Payment.objects.filter(
            order__collector=user,
            is_paid=False,
            order__status__in=['LOCKED', 'ORDERED', 'CLOSED'],
            order__created_at__gte=start_of_month
        ).exclude(user=user).aggregate(total=Sum('amount'))['total'] or 0
        
        return Response({
            'user': UserSerializer(user).data,
            'month': start_of_month.strftime('%B %Y'),
            'total_spend': float(total_spend),
            'collector_count': collector_count,
            'unpaid_count': unpaid_count,
            'total_collected': float(total_collected),
            'total_orders_participated': total_orders_participated,
            'avg_order_value': float(avg_order_value),
            'total_fees_paid': float(total_fees_only),
            'payment_completion_rate': float(payment_completion_rate),
            'most_ordered_restaurant': most_ordered_restaurant,
            'most_ordered_restaurant_count': most_ordered_restaurant_count,
            'total_pending': float(total_pending),
            'total_owed_to_user': float(total_owed_to_user),
        })

    @action(detail=True, methods=['get'])
    def export_csv(self, request, pk=None):
        """Export order summary as CSV (collector or admin/manager only)"""
        order = self.get_object()
        if request.user != order.collector and request.user.role not in ['admin', 'manager']:
            return Response({'error': 'Only the collector or an admin can export this order.'}, status=status.HTTP_403_FORBIDDEN)

        buf = io.StringIO()
        writer = csv.writer(buf)

        writer.writerow(['Order Code', 'Restaurant', 'Status', 'Collector', 'Created At'])
        writer.writerow([order.code, order.restaurant.name, order.status, order.collector.username, order.created_at.strftime('%Y-%m-%d %H:%M')])
        writer.writerow([])

        writer.writerow(['--- Items ---'])
        writer.writerow(['User', 'Item', 'Quantity', 'Unit Price', 'Total Price', 'Note'])
        for item in order.items.select_related('user', 'menu_item').all():
            name = item.menu_item.name if item.menu_item else item.custom_name
            writer.writerow([item.user.username, name, item.quantity, item.unit_price, item.total_price, item.note])
        writer.writerow([])

        writer.writerow(['--- Fees ---'])
        writer.writerow(['Delivery Fee', 'Tip', 'Service Fee', 'Fee Split Rule'])
        writer.writerow([order.delivery_fee, order.tip, order.service_fee, order.fee_split_rule])
        writer.writerow([])

        writer.writerow(['--- Payments ---'])
        writer.writerow(['User', 'Amount', 'Paid', 'Paid At'])
        for payment in order.payments.select_related('user').all():
            writer.writerow([payment.user.username, payment.amount, 'Yes' if payment.is_paid else 'No', payment.paid_at.strftime('%Y-%m-%d %H:%M') if payment.paid_at else ''])
        writer.writerow([])

        writer.writerow(['Total Items Cost', order.get_total_items_cost()])
        writer.writerow(['Total Cost', order.get_total_cost()])

        response = HttpResponse(buf.getvalue(), content_type='text/csv')
        response['Content-Disposition'] = f'attachment; filename="order-{order.code}.csv"'
        return response

    @action(detail=False, methods=['get'])
    def report(self, request):
        """Dynamic report: period=daily|weekly|monthly|all_time"""
        period = request.query_params.get('period', 'monthly')
        user_id = request.query_params.get('user_id', request.user.id)

        if request.user.role not in ['manager', 'admin'] and str(request.user.id) != str(user_id):
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)

        now = timezone.now()

        if period == 'daily':
            start_date = now.replace(hour=0, minute=0, second=0, microsecond=0)
            period_label = now.strftime('%A, %b %d %Y')
        elif period == 'weekly':
            start_date = (now - timedelta(days=now.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
            period_label = f"Week of {start_date.strftime('%b %d, %Y')}"
        elif period == 'monthly':
            start_date = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            period_label = now.strftime('%B %Y')
        elif period == 'all_time':
            start_date = None
            period_label = 'All Time'
        else:
            return Response(
                {'error': 'Invalid period. Use daily, weekly, monthly, or all_time'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Build reusable date filters
        order_date_q = {'order__created_at__gte': start_date} if start_date else {}
        direct_date_q = {'created_at__gte': start_date} if start_date else {}

        # Total spend (payments where user is payer)
        total_spend = Payment.objects.filter(user=user, **order_date_q).aggregate(
            total=Sum('amount')
        )['total'] or 0

        # Times as collector
        collector_count = CollectionOrder.objects.filter(collector=user, **direct_date_q).count()

        # Unpaid incidents
        unpaid_count = Payment.objects.filter(
            user=user, is_paid=False,
            order__status__in=['LOCKED', 'ORDERED', 'CLOSED'],
            **order_date_q
        ).count()

        # Orders collected
        orders_collected = CollectionOrder.objects.filter(collector=user, **direct_date_q)
        total_collected = Payment.objects.filter(
            order__in=orders_collected
        ).exclude(user=user).aggregate(total=Sum('amount'))['total'] or 0

        # Orders participated in
        orders_participated = CollectionOrder.objects.filter(
            items__user=user, **direct_date_q
        ).distinct()
        total_orders_participated = orders_participated.count()

        # Average order value — aggregate fees+items in one pass using annotate
        from django.db.models import F
        order_totals = orders_participated.annotate(
            items_total=Sum('items__total_price'),
        ).aggregate(
            grand_total=Sum(F('items_total') + F('delivery_fee') + F('tip') + F('service_fee'))
        )
        avg_order_value = (
            float(order_totals['grand_total'] or 0) / total_orders_participated
            if total_orders_participated > 0 else 0
        )

        # User's own item costs in one query
        total_item_costs = OrderItem.objects.filter(
            order__in=orders_participated, user=user
        ).aggregate(total=Sum('total_price'))['total'] or 0
        total_fees_only = float(total_spend) - float(total_item_costs)

        # Payment completion rate
        payment_stats = Payment.objects.filter(
            user=user,
            order__status__in=['LOCKED', 'ORDERED', 'CLOSED'],
            **order_date_q
        ).aggregate(
            total=Count('id'),
            paid=Count('id', filter=Q(is_paid=True)),
        )
        total_payments = payment_stats['total']
        payment_completion_rate = (
            payment_stats['paid'] / total_payments * 100 if total_payments > 0 else 100
        )

        # Most ordered restaurant
        restaurant_counts = CollectionOrder.objects.filter(
            items__user=user, **direct_date_q
        ).values('restaurant__name').annotate(
            order_count=Count('id', distinct=True)
        ).order_by('-order_count')
        most_ordered_restaurant = restaurant_counts[0]['restaurant__name'] if restaurant_counts else None
        most_ordered_restaurant_count = restaurant_counts[0]['order_count'] if restaurant_counts else 0

        # Total pending (owed by user)
        total_pending = Payment.objects.filter(
            user=user, is_paid=False,
            order__status__in=['LOCKED', 'ORDERED', 'CLOSED'],
            **order_date_q
        ).aggregate(total=Sum('amount'))['total'] or 0

        # Total owed to user (as collector, others unpaid)
        total_owed_to_user = Payment.objects.filter(
            order__collector=user, is_paid=False,
            order__status__in=['LOCKED', 'ORDERED', 'CLOSED'],
            **order_date_q
        ).exclude(user=user).aggregate(total=Sum('amount'))['total'] or 0

        return Response({
            'user': UserSerializer(user).data,
            'period': period,
            'period_label': period_label,
            'total_spend': float(total_spend),
            'collector_count': collector_count,
            'unpaid_count': unpaid_count,
            'total_collected': float(total_collected),
            'total_orders_participated': total_orders_participated,
            'avg_order_value': float(avg_order_value),
            'total_fees_paid': float(total_fees_only),
            'payment_completion_rate': float(payment_completion_rate),
            'most_ordered_restaurant': most_ordered_restaurant,
            'most_ordered_restaurant_count': most_ordered_restaurant_count,
            'total_pending': float(total_pending),
            'total_owed_to_user': float(total_owed_to_user),
        })

class OrderItemViewSet(viewsets.ModelViewSet):
    queryset = OrderItem.objects.all()
    serializer_class = OrderItemSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        order_id = self.request.query_params.get('order')
        user_id = self.request.query_params.get('user')
        queryset = OrderItem.objects.all()
        
        if order_id:
            queryset = queryset.filter(order_id=order_id)
        if user_id:
            queryset = queryset.filter(user_id=user_id)
        
        # Users can only see their own items unless they're the collector, manager, or admin
        if self.request.user.role not in ['manager', 'admin']:
            order_ids = CollectionOrder.objects.filter(
                Q(collector=self.request.user) | Q(items__user=self.request.user)
            ).values_list('id', flat=True)
            queryset = queryset.filter(order_id__in=order_ids)
        
        return queryset
    
    def create(self, request, *args, **kwargs):
        """Override create to add prompts for menu addition and price updates"""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        order = serializer.validated_data['order']
        
        # Check if order is open
        if order.status != 'OPEN':
            raise ValidationError("Cannot add items to a locked/closed order")
        
        # Check if order has assigned users - if so, only they can add items
        if order.assigned_users.exists():
            if request.user not in order.assigned_users.all() and request.user.role not in ['manager', 'admin'] and order.collector != request.user:
                raise ValidationError("You are not assigned to this order")
        
        # Set unit price
        if serializer.validated_data.get('menu_item'):
            serializer.validated_data['unit_price'] = serializer.validated_data['menu_item'].price
        elif serializer.validated_data.get('custom_price'):
            serializer.validated_data['unit_price'] = serializer.validated_data['custom_price']
        
        # Determine which user to assign the item to
        # If user is provided, only allow if requester is collector, manager, or admin
        assigned_user = serializer.validated_data.get('user')
        if assigned_user:
            if order.collector != request.user and request.user.role not in ['manager', 'admin']:
                raise ValidationError("Only the collector or manager can assign items to other users")
            user_to_assign = assigned_user
        else:
            user_to_assign = request.user
        
        # Check for existing menu items if this is a custom item
        suggest_add_to_menu = False
        suggest_update_price = False
        existing_menu_item_id = None
        
        if serializer.validated_data.get('custom_name'):
            custom_name = serializer.validated_data['custom_name']
            custom_price = serializer.validated_data.get('custom_price')
            
            # Check if a menu item with the same name exists in any menu for this restaurant
            existing_menu_item = MenuItem.objects.filter(
                menu__restaurant=order.restaurant,
                name__iexact=custom_name
            ).first()
            
            if existing_menu_item:
                # Item exists, suggest price update if price is different
                existing_menu_item_id = existing_menu_item.id
                if custom_price and existing_menu_item.price != custom_price:
                    suggest_update_price = True
            else:
                # Item doesn't exist, suggest adding to menu
                suggest_add_to_menu = True
        
        try:
            item = serializer.save(user=user_to_assign)
        except IntegrityError as e:
            # Handle unique_together constraint violation
            if 'unique' in str(e).lower() or 'duplicate' in str(e).lower():
                item_name = serializer.validated_data.get('menu_item')
                if item_name:
                    item_name = item_name.name
                else:
                    item_name = serializer.validated_data.get('custom_name', 'item')
                raise ValidationError(f"This item ({item_name}) already exists for this user in this order. Please update the quantity instead.")
            raise
        
        AuditLog.objects.create(
            order=order,
            user=request.user,
            action='item_added',
            details={
                'item_name': item.menu_item.name if item.menu_item else item.custom_name,
                'quantity': item.quantity,
                'price': float(item.total_price)
            }
        )

        # Adding an item makes you part of the roster (idempotent)
        order.joined_users.add(user_to_assign)

        # Broadcast order update via WebSocket
        order.refresh_from_db()
        broadcast_order_update(order)
        
        # Prepare response with prompts
        response_serializer = self.get_serializer(item)
        response_data = response_serializer.data
        response_data['suggest_add_to_menu'] = suggest_add_to_menu
        response_data['suggest_update_price'] = suggest_update_price
        response_data['existing_menu_item_id'] = existing_menu_item_id
        
        headers = self.get_success_headers(response_data)
        return Response(response_data, status=status.HTTP_201_CREATED, headers=headers)
    
    def perform_create(self, serializer):
        # This method is no longer used, but kept for compatibility
        # The create method above handles everything
        pass
    
    def update(self, request, *args, **kwargs):
        """Override update to handle price changes and prompts"""
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        
        order = instance.order
        
        # Check if order is open
        if order.status != 'OPEN':
            raise ValidationError("Cannot update items in a locked/closed order")
        
        # Check for price updates if this is a menu item
        suggest_update_price = False
        existing_menu_item_id = None
        
        if instance.menu_item and 'custom_price' in serializer.validated_data:
            # User is changing price of a menu item
            new_price = serializer.validated_data.get('custom_price')
            if new_price and instance.menu_item.price != new_price:
                suggest_update_price = True
                existing_menu_item_id = instance.menu_item.id
        
        # Format custom_name if it's being updated
        if 'custom_name' in serializer.validated_data and serializer.validated_data.get('custom_name'):
            serializer.validated_data['custom_name'] = format_item_name(serializer.validated_data['custom_name'])
        
        # Update unit price if custom_price is provided
        if serializer.validated_data.get('custom_price'):
            serializer.validated_data['unit_price'] = serializer.validated_data['custom_price']
        elif serializer.validated_data.get('menu_item'):
            serializer.validated_data['unit_price'] = serializer.validated_data['menu_item'].price
        
        self.perform_update(serializer)
        
        # Refresh instance from database to get updated values
        instance.refresh_from_db()
        
        # Broadcast order update via WebSocket
        order.refresh_from_db()
        broadcast_order_update(order)
        
        # Prepare response with prompts
        response_serializer = self.get_serializer(instance)
        response_data = response_serializer.data
        response_data['suggest_update_price'] = suggest_update_price
        response_data['existing_menu_item_id'] = existing_menu_item_id
        response_data['suggest_add_to_menu'] = False
        
        return Response(response_data)
    
    def perform_update(self, serializer):
        serializer.save()
    
    def perform_destroy(self, instance):
        order = instance.order
        if order.status != 'OPEN':
            raise ValidationError("Cannot remove items from a locked/closed order")
        
        if instance.user != self.request.user and order.collector != self.request.user and self.request.user.role not in ['manager', 'admin']:
            raise ValidationError("Permission denied")
        
        AuditLog.objects.create(
            order=order,
            user=self.request.user,
            action='item_removed',
            details={
                'item_name': instance.menu_item.name if instance.menu_item else instance.custom_name
            }
        )
        
        instance.delete()
        
        # Broadcast order update via WebSocket
        order.refresh_from_db()
        broadcast_order_update(order)
    
    @action(detail=True, methods=['post'])
    def add_to_menu(self, request, pk=None):
        """Add a custom item to the menu permanently"""
        item = self.get_object()
        
        if not item.custom_name:
            return Response(
                {'error': 'This item is already a menu item'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        order = item.order
        menu_id = request.data.get('menu_id')
        
        # If menu_id is provided, use it; otherwise use order's menu or first active menu
        if menu_id:
            try:
                menu = Menu.objects.get(id=menu_id, restaurant=order.restaurant)
            except Menu.DoesNotExist:
                return Response(
                    {'error': 'Menu not found'}, 
                    status=status.HTTP_404_NOT_FOUND
                )
        elif order.menu:
            menu = order.menu
        else:
            # Get first active menu for the restaurant
            menu = Menu.objects.filter(restaurant=order.restaurant, is_active=True).first()
            if not menu:
                return Response(
                    {'error': 'No active menu found for this restaurant'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
        
        # Check if item already exists in menu
        existing_item = MenuItem.objects.filter(
            menu=menu,
            name__iexact=item.custom_name
        ).first()
        
        if existing_item:
            # Update existing item price
            existing_item.price = item.custom_price
            existing_item.save()
            menu_item = existing_item
        else:
            # Create new menu item
            menu_item = MenuItem.objects.create(
                menu=menu,
                name=item.custom_name,
                price=item.custom_price,
                description='',
                is_available=True
            )
        
        # Update the order item to use the menu item
        item.menu_item = menu_item
        item.custom_name = ''
        item.custom_price = None
        item.unit_price = menu_item.price
        item.save()
        
        AuditLog.objects.create(
            order=order,
            user=request.user,
            action='item_added',
            details={
                'action': 'added_to_menu',
                'item_name': menu_item.name,
                'menu_id': menu.id,
                'menu_name': menu.name
            }
        )
        
        serializer = self.get_serializer(item)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'])
    def update_menu_item_price(self, request, pk=None):
        """Update the price of a menu item"""
        item = self.get_object()
        
        if not item.menu_item:
            return Response(
                {'error': 'This item is not a menu item'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        new_price = request.data.get('price')
        if not new_price:
            return Response(
                {'error': 'Price is required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            new_price = Decimal(str(new_price))
        except (ValueError, TypeError):
            return Response(
                {'error': 'Invalid price format'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Update menu item price
        menu_item = item.menu_item
        old_price = menu_item.price
        menu_item.price = new_price
        menu_item.save()
        
        # Update order item unit price
        item.unit_price = new_price
        item.save()
        
        AuditLog.objects.create(
            order=item.order,
            user=request.user,
            action='fee_updated',
            details={
                'action': 'menu_item_price_updated',
                'item_name': menu_item.name,
                'old_price': float(old_price),
                'new_price': float(new_price)
            }
        )
        
        serializer = self.get_serializer(item)
        return Response(serializer.data)


class PaymentViewSet(viewsets.ModelViewSet):
    queryset = Payment.objects.all()
    serializer_class = PaymentSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        order_id = self.request.query_params.get('order')
        user_id = self.request.query_params.get('user')
        queryset = Payment.objects.all()
        
        if order_id:
            queryset = queryset.filter(order_id=order_id)
        if user_id:
            queryset = queryset.filter(user_id=user_id)
        
        # Users can only see their own payments or payments for orders they collected
        if self.request.user.role not in ['manager', 'admin']:
            order_ids = CollectionOrder.objects.filter(
                Q(collector=self.request.user) | Q(payments__user=self.request.user)
            ).values_list('id', flat=True)
            queryset = queryset.filter(order_id__in=order_ids)
        
        return queryset
    
    @action(detail=True, methods=['post'])
    def mark_paid(self, request, pk=None):
        payment = self.get_object()
        
        # Allow user to mark their own payment as paid, or collector/manager/admin to mark any payment
        if payment.user != request.user and payment.order.collector != request.user and request.user.role not in ['manager', 'admin']:
            return Response(
                {'error': 'Only the payer, collector, or manager can mark as paid'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        payment.is_paid = True
        payment.paid_at = timezone.now()
        payment.save()

        order = payment.order
        if request.user == payment.user and order.collector != payment.user:
            notify_users(
                [order.collector],
                f'{payment.user.username} marked their payment of {payment.amount} EGP '
                f'as paid for order {order.code}.',
                order=order,
                notification_type='payment_received',
            )
        elif request.user != payment.user:
            notify_users(
                [payment.user],
                f'Your payment of {payment.amount} EGP for order {order.code} '
                f'was confirmed by {request.user.username}.',
                order=order,
                notification_type='payment_received',
            )

        # Broadcast order update via WebSocket
        broadcast_order_update(order)

        return Response(PaymentSerializer(payment).data)


class AuditLogViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = AuditLog.objects.all()
    serializer_class = AuditLogSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        order_id = self.request.query_params.get('order')

        # Admins/managers can see all logs; regular users only see logs for orders
        # they collected or participated in.
        if user.role in ['admin', 'manager']:
            queryset = AuditLog.objects.all()
        else:
            authorized_order_ids = CollectionOrder.objects.filter(
                Q(collector=user) | Q(items__user=user)
            ).values_list('id', flat=True).distinct()
            queryset = AuditLog.objects.filter(order_id__in=authorized_order_ids)

        if order_id:
            queryset = queryset.filter(order_id=order_id)

        return queryset.select_related('user', 'order')


class FeePresetViewSet(viewsets.ModelViewSet):
    queryset = FeePreset.objects.all()
    serializer_class = FeePresetSerializer
    permission_classes = [IsManagerOrReadOnly]


class RecommendationViewSet(viewsets.ModelViewSet):
    queryset = Recommendation.objects.all()
    serializer_class = RecommendationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Recommendation.objects.all().select_related('user')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


# ── Hive SSO (proxy through Hive's Microsoft login) ──────────────────────────

class MicrosoftSSOStatusView(APIView):
    """Return whether Hive SSO is configured (HIVE_URL is set)."""
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        from django.conf import settings as django_settings
        hive_url = getattr(django_settings, 'HIVE_URL', '').rstrip('/')
        enabled = bool(hive_url)
        login_url = f"{hive_url}/api/users/auth/microsoft/login/" if enabled else None
        return Response({'enabled': enabled, 'login_url': login_url})


class MicrosoftLoginView(APIView):
    """Redirect the browser to Hive's Microsoft login. Hive's callback will
    redirect back to OrderQ's frontend (via the Referer header)."""
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        from django.conf import settings as django_settings
        from django.http import HttpResponseRedirect
        hive_url = getattr(django_settings, 'HIVE_URL', '').rstrip('/')
        if not hive_url:
            return Response({'error': 'Hive SSO is not configured'},
                            status=status.HTTP_503_SERVICE_UNAVAILABLE)
        return HttpResponseRedirect(f"{hive_url}/api/users/auth/microsoft/login/")


class MicrosoftCallbackView(APIView):
    """Unused in the Hive-proxy flow — kept so the URL pattern doesn't 404."""
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        from django.conf import settings as django_settings
        from django.http import HttpResponseRedirect
        frontend_url = getattr(django_settings, 'FRONTEND_URL', 'https://localhost')
        return HttpResponseRedirect(f"{frontend_url}/login?sso_error=not_configured")


class HiveSSOView(APIView):
    """Accept the email returned by the browser's credentialed CORS check
    against Hive's session, then issue an OrderQ JWT."""
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        from django.conf import settings as django_settings
        email = (request.data.get('email') or '').lower().strip()
        if not email:
            return Response({'error': 'email is required'}, status=status.HTTP_400_BAD_REQUEST)
        # Only accept email addresses from the configured domains
        allowed_domains = getattr(django_settings, 'SSO_ALLOWED_EMAIL_DOMAINS', [])
        if allowed_domains and not any(email.endswith(f'@{d}') for d in allowed_domains):
            domains = ', '.join(f'@{d}' for d in allowed_domains)
            return Response({'error': f'Only {domains} accounts are allowed'},
                            status=status.HTTP_403_FORBIDDEN)
        try:
            user = User.objects.get(email__iexact=email)
        except User.DoesNotExist:
            return Response({'error': 'No OrderQ account found for this email. Contact your administrator.'},
                            status=status.HTTP_404_NOT_FOUND)
        if not user.is_active:
            return Response({'error': 'Account is inactive'}, status=status.HTTP_403_FORBIDDEN)
        refresh = RefreshToken.for_user(user)
        return Response({'access': str(refresh.access_token), 'refresh': str(refresh)})


class TaskStatusView(APIView):
    """
    Poll the status of a Celery task by its task ID.
    GET /api/task-status/<task_id>/
    Returns: { state, result, error }
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, task_id):
        from celery.result import AsyncResult
        result = AsyncResult(task_id)
        state = result.state

        if state == 'PENDING':
            data = {'state': 'PENDING', 'message': 'Task is queued or unknown.'}
        elif state == 'STARTED':
            meta = result.info or {}
            data = {'state': 'STARTED', 'message': meta.get('message', 'Running…')}
        elif state == 'SUCCESS':
            data = {'state': 'SUCCESS', 'result': result.result}
        elif state == 'FAILURE':
            data = {'state': 'FAILURE', 'error': str(result.result)}
        else:
            data = {'state': state, 'message': str(result.info)}

        return Response(data)


class NotificationViewSet(viewsets.ReadOnlyModelViewSet):
    """In-app notifications for the authenticated user."""
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        queryset = Notification.objects.filter(user=self.request.user)
        if self.action == 'list':
            # Response stays a plain array (both frontends parse it as one), but
            # capped so a long-lived account doesn't pull its whole history.
            queryset = queryset[:100]
        return queryset

    @action(detail=True, methods=['post'], url_path='mark_read')
    def mark_read(self, request, pk=None):
        notif = self.get_object()
        notif.is_read = True
        notif.save(update_fields=['is_read'])
        return Response({'status': 'ok'})

    @action(detail=False, methods=['post'], url_path='mark_all_read')
    def mark_all_read(self, request):
        Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
        return Response({'status': 'ok'})

    @action(detail=False, methods=['get'], url_path='unread_count')
    def unread_count(self, request):
        count = Notification.objects.filter(user=request.user, is_read=False).count()
        return Response({'unread_count': count})

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    UserViewSet, LoginView, RegisterView, RestaurantViewSet, MenuViewSet,
    MenuItemViewSet, CollectionOrderViewSet, OrderItemViewSet,
    PaymentViewSet, AuditLogViewSet, FeePresetViewSet, RecommendationViewSet,
    MicrosoftSSOStatusView, MicrosoftLoginView, MicrosoftCallbackView, HiveSSOView,
    TaskStatusView, NotificationViewSet, QuickJoinView, RecurringOrderViewSet,
    PushPublicKeyView, PushSubscribeView, PushUnsubscribeView,
)

router = DefaultRouter()
router.register(r'users', UserViewSet, basename='user')
router.register(r'restaurants', RestaurantViewSet, basename='restaurant')
router.register(r'menus', MenuViewSet, basename='menu')
router.register(r'menu-items', MenuItemViewSet, basename='menuitem')
router.register(r'orders', CollectionOrderViewSet, basename='order')
router.register(r'order-items', OrderItemViewSet, basename='orderitem')
router.register(r'payments', PaymentViewSet, basename='payment')
router.register(r'audit-logs', AuditLogViewSet, basename='auditlog')
router.register(r'fee-presets', FeePresetViewSet, basename='feepreset')
router.register(r'recommendations', RecommendationViewSet, basename='recommendation')
router.register(r'notifications', NotificationViewSet, basename='notification')
router.register(r'recurring-orders', RecurringOrderViewSet, basename='recurringorder')

urlpatterns = [
    path('', include(router.urls)),
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/login/', LoginView.as_view(), name='token_obtain_pair'),
    path('auth/quick-join/', QuickJoinView.as_view(), name='quick-join'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/microsoft/status/', MicrosoftSSOStatusView.as_view(), name='ms-sso-status'),
    path('auth/microsoft/login/', MicrosoftLoginView.as_view(), name='ms-login'),
    path('auth/microsoft/callback/', MicrosoftCallbackView.as_view(), name='ms-callback'),
    path('auth/hive-sso/', HiveSSOView.as_view(), name='hive-sso'),
    path('task-status/<str:task_id>/', TaskStatusView.as_view(), name='task-status'),
    path('push/public_key/', PushPublicKeyView.as_view(), name='push-public-key'),
    path('push/subscribe/', PushSubscribeView.as_view(), name='push-subscribe'),
    path('push/unsubscribe/', PushUnsubscribeView.as_view(), name='push-unsubscribe'),
]


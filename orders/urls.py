from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from .views import (
    UserViewSet, RegisterView, RestaurantViewSet, MenuViewSet,
    MenuItemViewSet, CollectionOrderViewSet, OrderItemViewSet,
    PaymentViewSet, AuditLogViewSet, FeePresetViewSet, RecommendationViewSet
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

urlpatterns = [
    path('', include(router.urls)),
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/login/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
]


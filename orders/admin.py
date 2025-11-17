from django.contrib import admin
from .models import (
    User, Restaurant, Menu, MenuItem, CollectionOrder,
    OrderItem, Payment, AuditLog, FeePreset
)


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ['username', 'email', 'role', 'phone', 'is_active']
    list_filter = ['role', 'is_active']
    search_fields = ['username', 'email']


@admin.register(Restaurant)
class RestaurantAdmin(admin.ModelAdmin):
    list_display = ['name', 'created_by', 'created_at']
    search_fields = ['name']


@admin.register(Menu)
class MenuAdmin(admin.ModelAdmin):
    list_display = ['name', 'restaurant', 'is_active', 'created_at']
    list_filter = ['is_active', 'restaurant']
    search_fields = ['name', 'restaurant__name']


@admin.register(MenuItem)
class MenuItemAdmin(admin.ModelAdmin):
    list_display = ['name', 'menu', 'price', 'is_available']
    list_filter = ['is_available', 'menu__restaurant']
    search_fields = ['name']


@admin.register(CollectionOrder)
class CollectionOrderAdmin(admin.ModelAdmin):
    list_display = ['code', 'restaurant', 'collector', 'status', 'created_at']
    list_filter = ['status', 'restaurant']
    search_fields = ['code', 'restaurant__name', 'collector__username']


@admin.register(OrderItem)
class OrderItemAdmin(admin.ModelAdmin):
    list_display = ['order', 'user', 'get_item_name', 'quantity', 'total_price']
    list_filter = ['order__status', 'order__restaurant']
    search_fields = ['order__code', 'user__username', 'menu_item__name', 'custom_name']
    
    def get_item_name(self, obj):
        return obj.menu_item.name if obj.menu_item else obj.custom_name
    get_item_name.short_description = 'Item Name'


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ['order', 'user', 'amount', 'is_paid', 'paid_at']
    list_filter = ['is_paid', 'order__status']
    search_fields = ['order__code', 'user__username']


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ['order', 'user', 'action', 'created_at']
    list_filter = ['action', 'created_at']
    search_fields = ['order__code', 'user__username']


@admin.register(FeePreset)
class FeePresetAdmin(admin.ModelAdmin):
    list_display = ['name', 'delivery_fee', 'tip', 'service_fee']
    search_fields = ['name']

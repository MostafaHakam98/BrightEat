from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from django.conf import settings
from .models import (
    User, Restaurant, Menu, MenuItem, CollectionOrder, 
    OrderItem, Payment, AuditLog, FeePreset, Recommendation
)


class UserSerializer(serializers.ModelSerializer):
    instapay_qr_code_url = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'role', 'phone', 'instapay_link', 'instapay_qr_code', 'instapay_qr_code_url']
        read_only_fields = ['id', 'role', 'instapay_qr_code_url']
    
    def get_instapay_qr_code_url(self, obj):
        if obj.instapay_qr_code:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.instapay_qr_code.url)
            return obj.instapay_qr_code.url
        return None


class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])
    password_confirm = serializers.CharField(write_only=True)
    
    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'password_confirm', 'first_name', 'last_name', 'role', 'phone']
    
    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError({"password": "Passwords don't match"})
        return attrs
    
    def create(self, validated_data):
        validated_data.pop('password_confirm')
        user = User.objects.create_user(**validated_data)
        return user


class RestaurantSerializer(serializers.ModelSerializer):
    created_by_name = serializers.CharField(source='created_by.username', read_only=True)
    
    class Meta:
        model = Restaurant
        fields = ['id', 'name', 'description', 'created_at', 'created_by', 'created_by_name']
        read_only_fields = ['id', 'created_at', 'created_by']


class MenuSerializer(serializers.ModelSerializer):
    restaurant_name = serializers.CharField(source='restaurant.name', read_only=True)
    restaurant = serializers.PrimaryKeyRelatedField(queryset=Restaurant.objects.all(), required=True)
    
    class Meta:
        model = Menu
        fields = ['id', 'restaurant', 'restaurant_name', 'name', 'is_active', 'created_at']
        read_only_fields = ['id', 'created_at']


class MenuItemSerializer(serializers.ModelSerializer):
    menu_name = serializers.CharField(source='menu.name', read_only=True)
    restaurant_name = serializers.CharField(source='menu.restaurant.name', read_only=True)
    menu = serializers.PrimaryKeyRelatedField(queryset=Menu.objects.all(), required=True)
    
    class Meta:
        model = MenuItem
        fields = ['id', 'menu', 'menu_name', 'restaurant_name', 'name', 'description', 
                  'price', 'is_available', 'created_at']
        read_only_fields = ['id', 'created_at']


class FeePresetSerializer(serializers.ModelSerializer):
    class Meta:
        model = FeePreset
        fields = ['id', 'name', 'delivery_fee', 'tip', 'service_fee', 'created_at']
        read_only_fields = ['id', 'created_at']


class OrderItemSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    item_name = serializers.SerializerMethodField()
    menu_item = serializers.PrimaryKeyRelatedField(queryset=MenuItem.objects.all(), required=False, allow_null=True)
    custom_name = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    custom_price = serializers.DecimalField(max_digits=10, decimal_places=2, required=False, allow_null=True)
    
    class Meta:
        model = OrderItem
        fields = ['id', 'order', 'user', 'user_name', 'menu_item', 'custom_name', 
                  'custom_price', 'quantity', 'unit_price', 'total_price', 'item_name', 'created_at']
        read_only_fields = ['id', 'user', 'unit_price', 'total_price', 'created_at']
    
    def get_item_name(self, obj):
        return obj.menu_item.name if obj.menu_item else obj.custom_name
    
    def validate(self, attrs):
        # Either menu_item OR custom_name must be provided, but not both
        has_menu_item = attrs.get('menu_item') is not None
        has_custom = bool(attrs.get('custom_name'))
        
        if not has_menu_item and not has_custom:
            raise serializers.ValidationError("Either menu_item or custom_name must be provided")
        if has_menu_item and has_custom:
            raise serializers.ValidationError("Cannot specify both menu_item and custom_name")
        if has_custom and not attrs.get('custom_price'):
            raise serializers.ValidationError("custom_price is required when using custom_name")
        return attrs


class CollectionOrderSerializer(serializers.ModelSerializer):
    restaurant_name = serializers.CharField(source='restaurant.name', read_only=True)
    collector_name = serializers.CharField(source='collector.username', read_only=True)
    collector_instapay_link = serializers.CharField(source='collector.instapay_link', read_only=True)
    collector_instapay_qr_code_url = serializers.SerializerMethodField()
    items = OrderItemSerializer(many=True, read_only=True)
    participants = serializers.SerializerMethodField()
    assigned_users = serializers.PrimaryKeyRelatedField(many=True, queryset=User.objects.all(), required=False)
    assigned_users_details = serializers.SerializerMethodField()
    payments = serializers.SerializerMethodField()
    total_items_cost = serializers.SerializerMethodField()
    total_cost = serializers.SerializerMethodField()
    share_message = serializers.SerializerMethodField()
    join_url = serializers.SerializerMethodField()
    restaurant = serializers.PrimaryKeyRelatedField(queryset=Restaurant.objects.all(), required=True)
    cutoff_time = serializers.DateTimeField(required=False, allow_null=True, input_formats=['%Y-%m-%dT%H:%M', '%Y-%m-%d %H:%M:%S', 'iso-8601'])
    
    class Meta:
        model = CollectionOrder
        fields = ['id', 'code', 'restaurant', 'restaurant_name', 'collector', 'collector_name', 'collector_instapay_link', 'collector_instapay_qr_code_url',
                  'status', 'cutoff_time', 'instapay_link', 'is_private', 'assigned_users', 'assigned_users_details',
                  'delivery_fee', 'tip', 'service_fee', 'fee_split_rule', 'created_at', 'locked_at', 'ordered_at', 'closed_at',
                  'items', 'participants', 'payments', 'total_items_cost', 'total_cost', 
                  'share_message', 'join_url']
        read_only_fields = ['id', 'code', 'collector', 'created_at', 'locked_at', 'ordered_at', 'closed_at', 'assigned_users_details']
    
    def get_assigned_users_details(self, obj):
        return [{'id': u.id, 'username': u.username, 'email': u.email} for u in obj.assigned_users.all()]
    
    def get_collector_instapay_qr_code_url(self, obj):
        if obj.collector.instapay_qr_code:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.collector.instapay_qr_code.url)
            return obj.collector.instapay_qr_code.url
        return None
    
    def get_participants(self, obj):
        return [{'id': u.id, 'username': u.username} for u in obj.get_participants()]
    
    def get_payments(self, obj):
        payments = Payment.objects.filter(order=obj)
        return PaymentSerializer(payments, many=True).data
    
    def get_total_items_cost(self, obj):
        return float(obj.get_total_items_cost())
    
    def get_total_cost(self, obj):
        return float(obj.get_total_cost())
    
    def get_join_url(self, obj):
        request = self.context.get('request')
        # Use frontend URL if available, otherwise construct from request
        frontend_url = getattr(settings, 'FRONTEND_URL', None)
        if frontend_url:
            return f"{frontend_url}/join/{obj.code}"
        elif request:
            # Try to construct from request (for development)
            scheme = request.scheme
            host = request.get_host()
            # Replace backend port with frontend port if needed
            if ':8000' in host:
                host = host.replace(':8000', ':3000')
            return f"{scheme}://{host}/join/{obj.code}"
        return f'/join/{obj.code}'
    
    def get_share_message(self, obj):
        request = self.context.get('request')
        cutoff_str = obj.cutoff_time.strftime('%I:%M %p') if obj.cutoff_time else 'N/A'
        join_url = self.get_join_url(obj)
        message = (f"🍽️ BrightEat: Order from {obj.restaurant.name}\n"
                  f"📋 Join code: {obj.code}\n"
                  f"⏰ Cutoff: {cutoff_str}\n"
                  f"🔗 Add your items here: {join_url}\n"
                  f"👤 Collector: {obj.collector.username}")
        
        # Add assigned users info if any
        if obj.assigned_users.exists():
            assigned_names = ', '.join([u.username for u in obj.assigned_users.all()])
            message += f"\n👥 Assigned to: {assigned_names}"
        
        return message


class PaymentSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    order_code = serializers.CharField(source='order.code', read_only=True)
    
    class Meta:
        model = Payment
        fields = ['id', 'order', 'order_code', 'user', 'user_name', 'amount', 
                  'is_paid', 'paid_at', 'created_at']
        read_only_fields = ['id', 'created_at']


class AuditLogSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    order_code = serializers.CharField(source='order.code', read_only=True)
    
    class Meta:
        model = AuditLog
        fields = ['id', 'order', 'order_code', 'user', 'user_name', 'action', 
                  'details', 'created_at']
        read_only_fields = ['id', 'created_at']


class RecommendationSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    restaurant_name = serializers.CharField(source='restaurant.name', read_only=True, allow_null=True)
    
    class Meta:
        model = Recommendation
        fields = ['id', 'user', 'user_name', 'restaurant', 'restaurant_name', 'text', 'created_at']
        read_only_fields = ['id', 'user', 'created_at']


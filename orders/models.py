from django.db import models
from django.contrib.auth.models import AbstractUser
from django.core.validators import MinValueValidator
from django.utils import timezone
import secrets
import string


class User(AbstractUser):
    """Extended user model with role"""
    ROLE_CHOICES = [
        ('admin', 'Administrator'),
        ('manager', 'Menu Manager'),
        ('user', 'Normal User'),
    ]
    
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='user')
    phone = models.CharField(max_length=20, blank=True)
    instapay_link = models.URLField(max_length=500, blank=True, help_text="Instapay payment link for this user")
    instapay_qr_code = models.ImageField(upload_to='qr_codes/', blank=True, null=True, help_text="QR code image for Instapay")
    
    def __str__(self):
        return f"{self.username} ({self.get_role_display()})"


class Restaurant(models.Model):
    """Restaurant model"""
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='created_restaurants')
    
    class Meta:
        ordering = ['-created_at']
    
    def __str__(self):
        return self.name


class Menu(models.Model):
    """Menu model for a restaurant"""
    restaurant = models.ForeignKey(Restaurant, on_delete=models.CASCADE, related_name='menus')
    name = models.CharField(max_length=200)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    # Sync metadata for Talabat scraping
    talabat_url = models.URLField(max_length=500, blank=True, null=True, help_text="Talabat URL for this menu")
    menu_hash = models.CharField(max_length=64, blank=True, null=True, help_text="SHA256 hash of menu items for change detection")
    last_synced_at = models.DateTimeField(null=True, blank=True, help_text="Last time menu was synced from Talabat")
    
    class Meta:
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.restaurant.name} - {self.name}"


class MenuItem(models.Model):
    """Menu item model"""
    menu = models.ForeignKey(Menu, on_delete=models.CASCADE, related_name='items')
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    is_available = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    # Sync metadata for Talabat scraping
    talabat_id = models.BigIntegerField(null=True, blank=True, help_text="Original Talabat item ID")
    item_hash = models.CharField(max_length=64, blank=True, null=True, db_index=True, help_text="SHA256 hash for change detection")
    section_name = models.CharField(max_length=200, blank=True, help_text="Section/category name from Talabat")
    image_url = models.URLField(max_length=1000, blank=True, help_text="Item image URL from Talabat CDN")
    
    class Meta:
        ordering = ['name']
        indexes = [
            models.Index(fields=['item_hash']),
        ]
    
    def __str__(self):
        return f"{self.menu.restaurant.name} - {self.name}"


class FeePreset(models.Model):
    """Fee preset for quick setup"""
    FEE_SPLIT_CHOICES = [
        ('equal', 'Equal'),
        ('proportional', 'Proportional'),
        ('collector_pays', 'Collector Pays'),
    ]

    name = models.CharField(max_length=100)  # e.g., "Talabat"
    delivery_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    tip = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    service_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    fee_split_rule = models.CharField(max_length=20, choices=FEE_SPLIT_CHOICES, default='equal')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name


class CollectionOrder(models.Model):
    """Collection order model"""
    STATUS_CHOICES = [
        ('OPEN', 'Open'),
        ('LOCKED', 'Locked'),
        ('ORDERED', 'Ordered'),
        ('CLOSED', 'Closed'),
        ('DELETED', 'Deleted'),
    ]
    
    FEE_SPLIT_CHOICES = [
        ('equal', 'Equal'),
        ('proportional', 'Proportional'),
        ('collector_pays', 'Collector Pays'),
        ('custom', 'Custom'),
    ]
    
    code = models.CharField(max_length=10, unique=True, db_index=True)
    restaurant = models.ForeignKey(Restaurant, on_delete=models.CASCADE, related_name='orders')
    menu = models.ForeignKey(Menu, on_delete=models.SET_NULL, null=True, blank=True, related_name='orders', help_text="Optional menu for this order")
    collector = models.ForeignKey(User, on_delete=models.CASCADE, related_name='collected_orders')
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='OPEN', db_index=True)
    cutoff_time = models.DateTimeField(null=True, blank=True)
    cutoff_reminder_sent = models.BooleanField(default=False, help_text="Whether the pre-cutoff reminder was sent")
    cutoff_processed = models.BooleanField(default=False, help_text="Whether the cutoff auto-lock has been handled")
    instapay_link = models.URLField(blank=True)
    is_private = models.BooleanField(default=False, help_text="If True, only participants can see this order")
    
    # Fees
    delivery_fee = models.DecimalField(max_digits=10, decimal_places=2, default=30)
    tip = models.DecimalField(max_digits=10, decimal_places=2, default=30)
    service_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    fee_split_rule = models.CharField(max_length=20, choices=FEE_SPLIT_CHOICES, default='equal')
    
    # Assigned users - if set, only these users can join the order
    assigned_users = models.ManyToManyField(User, related_name='assigned_orders', blank=True, help_text="Users assigned to this order (e.g., for birthday cake)")

    # Users who explicitly joined (may not have added items yet).
    # Unlike assigned_users this never restricts access — it's a roster.
    joined_users = models.ManyToManyField(User, related_name='joined_orders', blank=True, help_text="Users who explicitly joined this order")
    
    created_at = models.DateTimeField(auto_now_add=True)
    locked_at = models.DateTimeField(null=True, blank=True)
    ordered_at = models.DateTimeField(null=True, blank=True)
    closed_at = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        ordering = ['-created_at']
    
    def __str__(self):
        return f"Order {self.code} - {self.restaurant.name} ({self.status})"
    
    def generate_code(self):
        """Generate unique order code"""
        while True:
            code = ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(6))
            if not CollectionOrder.objects.filter(code=code).exists():
                return code
    
    def save(self, *args, **kwargs):
        if not self.code:
            self.code = self.generate_code()
        super().save(*args, **kwargs)
    
    def get_total_items_cost(self):
        """Calculate total cost of all items"""
        return sum(item.total_price for item in self.items.all())
    
    def get_total_cost(self):
        """Calculate total cost including fees"""
        return self.get_total_items_cost() + self.delivery_fee + self.tip + self.service_fee
    
    def get_participants(self):
        """Get all users who have items in this order"""
        return User.objects.filter(order_items__order=self).distinct()

    def get_notification_recipients(self):
        """Everyone who should hear about this order: item owners, joined users,
        assigned users, and the collector. Broader than get_participants(), which
        only covers users who owe money (i.e. have items)."""
        return User.objects.filter(
            models.Q(order_items__order=self) |
            models.Q(joined_orders=self) |
            models.Q(assigned_orders=self) |
            models.Q(collected_orders=self)
        ).distinct()


class OrderItem(models.Model):
    """Order item model - links user to items in an order"""
    order = models.ForeignKey(CollectionOrder, on_delete=models.CASCADE, related_name='items')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='order_items')
    menu_item = models.ForeignKey(MenuItem, on_delete=models.SET_NULL, null=True, blank=True, related_name='order_items')
    
    # For custom ad-hoc items
    custom_name = models.CharField(max_length=200, blank=True)
    custom_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    
    quantity = models.PositiveIntegerField(default=1)
    unit_price = models.DecimalField(max_digits=10, decimal_places=2)
    total_price = models.DecimalField(max_digits=10, decimal_places=2)
    note = models.TextField(blank=True, help_text="Special instructions or modifications for this item")
    
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-created_at']
        unique_together = [['order', 'user', 'menu_item', 'custom_name']]
    
    def __str__(self):
        item_name = self.menu_item.name if self.menu_item else self.custom_name
        return f"{self.user.username} - {item_name} x{self.quantity}"
    
    def save(self, *args, **kwargs):
        self.total_price = self.unit_price * self.quantity
        super().save(*args, **kwargs)


class Payment(models.Model):
    """Payment tracking model"""
    PROOF_STATUS_CHOICES = [
        ('none', 'No Proof'),
        ('claimed', 'Proof Uploaded'),
        ('confirmed', 'Confirmed by Collector'),
        ('rejected', 'Rejected by Collector'),
    ]

    order = models.ForeignKey(CollectionOrder, on_delete=models.CASCADE, related_name='payments')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='payments')
    amount = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(0)])
    is_paid = models.BooleanField(default=False)
    paid_at = models.DateTimeField(null=True, blank=True)
    # Instapay has no API, so "did the money move" is a screenshot the payer
    # uploads and the collector confirms — better than the pure honor system.
    proof_image = models.ImageField(upload_to='payment_proofs/', blank=True, null=True)
    proof_status = models.CharField(max_length=10, choices=PROOF_STATUS_CHOICES, default='none')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['is_paid', 'user']),
            models.Index(fields=['order', 'is_paid']),
        ]

    def __str__(self):
        status = "Paid" if self.is_paid else "Pending"
        return f"{self.user.username} - {self.amount} EGP ({status})"


class AuditLog(models.Model):
    """Audit log for order changes"""
    ACTION_CHOICES = [
        ('created', 'Created'),
        ('locked', 'Locked'),
        ('unlocked', 'Unlocked'),
        ('ordered', 'Ordered'),
        ('closed', 'Closed'),
        ('deleted', 'Deleted'),
        ('item_added', 'Item Added'),
        ('item_removed', 'Item Removed'),
        ('fee_updated', 'Fee Updated'),
        ('user_joined', 'User Joined'),
        ('items_auto_created', 'Items Auto-Created'),
    ]
    
    order = models.ForeignKey(CollectionOrder, on_delete=models.CASCADE, related_name='audit_logs')
    user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='audit_actions')
    action = models.CharField(max_length=20, choices=ACTION_CHOICES)
    details = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.order.code} - {self.get_action_display()} by {self.user.username if self.user else 'System'}"


class Recommendation(models.Model):
    """Recommendation model for website enhancements and feedback"""
    CATEGORY_CHOICES = [
        ('feature', 'New Feature'),
        ('improvement', 'Improvement'),
        ('bug', 'Bug Report'),
        ('ui', 'UI/UX'),
        ('other', 'Other'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='recommendations')
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES, default='other', help_text="Type of recommendation")
    title = models.CharField(max_length=200, help_text="Brief title for the recommendation")
    text = models.TextField(help_text="Detailed recommendation or feedback")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} - {self.title} ({self.get_category_display()}) - {self.created_at.strftime('%Y-%m-%d')}"


class PushSubscription(models.Model):
    """A browser's Web Push subscription for a user (one row per device/browser)."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='push_subscriptions')
    endpoint = models.TextField(unique=True)
    p256dh = models.CharField(max_length=255)
    auth = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} — {self.endpoint[:40]}…"


class Notification(models.Model):
    """In-app notification for a user"""
    TYPE_CHOICES = [
        ('order_status', 'Order Status Change'),
        ('payment_due', 'Payment Due'),
        ('payment_received', 'Payment Received'),
        ('order_joined', 'Someone Joined Order'),
        ('system', 'System'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    order = models.ForeignKey(
        'CollectionOrder', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='notifications'
    )
    notification_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default='system')
    message = models.TextField()
    is_read = models.BooleanField(default=False, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'is_read']),
        ]

    def __str__(self):
        return f"{self.user.username} — {self.message[:60]}"

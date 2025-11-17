from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from orders.models import Restaurant, Menu, MenuItem, FeePreset

User = get_user_model()


class Command(BaseCommand):
    help = 'Seed database with initial data'

    def handle(self, *args, **options):
        self.stdout.write('Seeding database...')
        
        # Create users
        manager, created = User.objects.get_or_create(
            username='manager',
            defaults={
                'email': 'manager@brighteat.com',
                'first_name': 'Menu',
                'last_name': 'Manager',
                'role': 'manager',
                'is_staff': True,
            }
        )
        if created:
            manager.set_password('manager123')
            manager.save()
            self.stdout.write(self.style.SUCCESS(f'Created manager user: {manager.username}'))
        else:
            self.stdout.write(f'Manager user already exists: {manager.username}')
        
        member, created = User.objects.get_or_create(
            username='mostafa',
            defaults={
                'email': 'mostafa@brighteat.com',
                'first_name': 'Mostafa',
                'last_name': 'Hakam',
                'role': 'user',
            }
        )
        if created:
            member.set_password('mostafa123')
            member.save()
            self.stdout.write(self.style.SUCCESS(f'Created member user: {member.username}'))
        else:
            self.stdout.write(f'Member user already exists: {member.username}')
        
        # Create restaurant
        restaurant, created = Restaurant.objects.get_or_create(
            name='Balbaa',
            defaults={
                'description': 'Delicious Middle Eastern cuisine',
                'created_by': manager,
            }
        )
        if created:
            self.stdout.write(self.style.SUCCESS(f'Created restaurant: {restaurant.name}'))
        else:
            self.stdout.write(f'Restaurant already exists: {restaurant.name}')
        
        # Create menu
        menu, created = Menu.objects.get_or_create(
            restaurant=restaurant,
            name='Main Menu',
            defaults={'is_active': True}
        )
        if created:
            self.stdout.write(self.style.SUCCESS(f'Created menu: {menu.name}'))
        else:
            self.stdout.write(f'Menu already exists: {menu.name}')
        
        # Create menu items
        menu_items_data = [
            {'name': 'Shawarma Sandwich', 'price': 45.00, 'description': 'Chicken shawarma with tahini'},
            {'name': 'Falafel Sandwich', 'price': 25.00, 'description': 'Crispy falafel with vegetables'},
            {'name': 'Mixed Grill', 'price': 120.00, 'description': 'Chicken and beef kebab with rice'},
            {'name': 'Hummus Plate', 'price': 35.00, 'description': 'Creamy hummus with pita bread'},
            {'name': 'Fattoush Salad', 'price': 40.00, 'description': 'Fresh mixed salad with pomegranate'},
            {'name': 'Mansaf', 'price': 95.00, 'description': 'Traditional lamb with yogurt sauce'},
            {'name': 'Kunafa', 'price': 30.00, 'description': 'Sweet cheese pastry'},
            {'name': 'Fresh Juice', 'price': 20.00, 'description': 'Orange or mango juice'},
        ]
        
        for item_data in menu_items_data:
            item, created = MenuItem.objects.get_or_create(
                menu=menu,
                name=item_data['name'],
                defaults={
                    'description': item_data['description'],
                    'price': item_data['price'],
                    'is_available': True,
                }
            )
            if created:
                self.stdout.write(self.style.SUCCESS(f'Created menu item: {item.name}'))
            else:
                self.stdout.write(f'Menu item already exists: {item.name}')
        
        # Create fee presets
        fee_presets_data = [
            {'name': 'Talabat', 'delivery_fee': 30.00, 'tip': 10.00, 'service_fee': 0.00},
            {'name': 'Otlob', 'delivery_fee': 25.00, 'tip': 5.00, 'service_fee': 0.00},
            {'name': 'Direct Order', 'delivery_fee': 20.00, 'tip': 15.00, 'service_fee': 0.00},
        ]
        
        for preset_data in fee_presets_data:
            preset, created = FeePreset.objects.get_or_create(
                name=preset_data['name'],
                defaults=preset_data
            )
            if created:
                self.stdout.write(self.style.SUCCESS(f'Created fee preset: {preset.name}'))
            else:
                self.stdout.write(f'Fee preset already exists: {preset.name}')
        
        self.stdout.write(self.style.SUCCESS('\nDatabase seeding completed!'))
        self.stdout.write('\nTest users:')
        self.stdout.write('  Manager: username=manager, password=manager123')
        self.stdout.write('  Member: username=mostafa, password=mostafa123')


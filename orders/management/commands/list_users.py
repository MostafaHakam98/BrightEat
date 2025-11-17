from django.core.management.base import BaseCommand
from orders.models import User
import secrets
import string


class Command(BaseCommand):
    help = 'List all users with their information and optionally generate/reset passwords'

    def add_arguments(self, parser):
        parser.add_argument(
            '--generate-passwords',
            action='store_true',
            help='Generate new random passwords for all users',
        )
        parser.add_argument(
            '--output-file',
            type=str,
            help='Output file to save user credentials (CSV format)',
        )

    def handle(self, *args, **options):
        users = User.objects.all().order_by('username')
        
        if options['generate_passwords']:
            self.stdout.write(self.style.WARNING('Generating new passwords for all users...'))
            credentials = []
            
            for user in users:
                # Generate a random password
                password = ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(12))
                user.set_password(password)
                user.save()
                credentials.append({
                    'username': user.username,
                    'email': user.email or 'N/A',
                    'password': password,
                    'role': user.get_role_display(),
                })
                self.stdout.write(
                    self.style.SUCCESS(f'✓ {user.username} ({user.email or "N/A"}) - Password: {password}')
                )
            
            # Save to file if specified
            if options['output_file']:
                import csv
                with open(options['output_file'], 'w', newline='') as csvfile:
                    fieldnames = ['username', 'email', 'password', 'role']
                    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                    writer.writeheader()
                    writer.writerows(credentials)
                self.stdout.write(self.style.SUCCESS(f'\nCredentials saved to {options["output_file"]}'))
            else:
                self.stdout.write(self.style.WARNING('\n⚠️  Passwords generated but not saved. Use --output-file to save them.'))
        else:
            # Just list users
            self.stdout.write(self.style.SUCCESS(f'\nFound {users.count()} user(s):\n'))
            self.stdout.write(f'{"Username":<20} {"Email":<30} {"Role":<15} {"Date Joined":<20}')
            self.stdout.write('-' * 85)
            
            for user in users:
                self.stdout.write(
                    f'{user.username:<20} {user.email or "N/A":<30} {user.get_role_display():<15} {user.date_joined.strftime("%Y-%m-%d %H:%M"):<20}'
                )
            
            self.stdout.write('\n' + self.style.WARNING('Note: Passwords are hashed and cannot be retrieved.'))
            self.stdout.write(self.style.WARNING('Use --generate-passwords to reset all passwords and generate new ones.'))


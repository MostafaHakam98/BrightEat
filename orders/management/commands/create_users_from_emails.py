from django.core.management.base import BaseCommand
from orders.models import User
import secrets
import string
import csv
import os


class Command(BaseCommand):
    help = 'Create users from a list of emails. Reads from a file (one email per line) or CSV file.'

    def add_arguments(self, parser):
        parser.add_argument(
            'file',
            type=str,
            help='Path to file containing emails (one per line) or CSV file with email column',
        )
        parser.add_argument(
            '--csv',
            action='store_true',
            help='Treat input file as CSV with "email" column',
        )
        parser.add_argument(
            '--role',
            type=str,
            default='user',
            choices=['user', 'manager'],
            help='Role to assign to new users (default: user)',
        )
        parser.add_argument(
            '--output-file',
            type=str,
            help='Output file to save created user credentials (CSV format)',
        )
        parser.add_argument(
            '--password-length',
            type=int,
            default=12,
            help='Length of generated passwords (default: 12)',
        )

    def handle(self, *args, **options):
        file_path = options['file']
        
        if not os.path.exists(file_path):
            self.stdout.write(self.style.ERROR(f'File not found: {file_path}'))
            return
        
        emails = []
        
        if options['csv']:
            # Read from CSV
            try:
                with open(file_path, 'r', encoding='utf-8') as csvfile:
                    reader = csv.DictReader(csvfile)
                    if 'email' not in reader.fieldnames:
                        self.stdout.write(self.style.ERROR('CSV file must have an "email" column'))
                        return
                    emails = [row['email'].strip() for row in reader if row.get('email', '').strip()]
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'Error reading CSV file: {e}'))
                return
        else:
            # Read from text file (one email per line)
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    emails = [line.strip() for line in f if line.strip() and '@' in line]
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'Error reading file: {e}'))
                return
        
        if not emails:
            self.stdout.write(self.style.ERROR('No valid emails found in file'))
            return
        
        self.stdout.write(self.style.SUCCESS(f'Found {len(emails)} email(s) to process\n'))
        
        created_users = []
        skipped_users = []
        
        for email in emails:
            email = email.strip().lower()
            
            # Check if user already exists
            if User.objects.filter(email=email).exists():
                self.stdout.write(self.style.WARNING(f'⚠️  User with email {email} already exists. Skipping.'))
                skipped_users.append(email)
                continue
            
            # Generate username from email (part before @)
            username = email.split('@')[0]
            # Make username unique if needed
            base_username = username
            counter = 1
            while User.objects.filter(username=username).exists():
                username = f"{base_username}{counter}"
                counter += 1
            
            # Generate random password
            password = ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(options['password_length']))
            
            # Create user
            try:
                user = User.objects.create_user(
                    username=username,
                    email=email,
                    password=password,
                    role=options['role']
                )
                created_users.append({
                    'username': user.username,
                    'email': user.email,
                    'password': password,
                    'role': user.get_role_display(),
                })
                self.stdout.write(
                    self.style.SUCCESS(f'✓ Created: {user.username} ({user.email}) - Password: {password}')
                )
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'✗ Failed to create user for {email}: {e}'))
        
        # Summary
        self.stdout.write('\n' + '=' * 60)
        self.stdout.write(self.style.SUCCESS(f'Created: {len(created_users)} user(s)'))
        if skipped_users:
            self.stdout.write(self.style.WARNING(f'Skipped: {len(skipped_users)} user(s) (already exist)'))
        
        # Save to output file if specified
        if options['output_file'] and created_users:
            try:
                with open(options['output_file'], 'w', newline='') as csvfile:
                    fieldnames = ['username', 'email', 'password', 'role']
                    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                    writer.writeheader()
                    writer.writerows(created_users)
                self.stdout.write(self.style.SUCCESS(f'\nCredentials saved to {options["output_file"]}'))
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'\nFailed to save output file: {e}'))
        elif created_users:
            self.stdout.write(self.style.WARNING('\n⚠️  Credentials not saved. Use --output-file to save them.'))


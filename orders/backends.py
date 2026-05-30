import logging

import requests
from django.conf import settings

from .models import User

logger = logging.getLogger(__name__)


class HiveAuthBackend:
    """Authenticate using Hive (BSACAIPortal) credentials.

    Called as a fallback when local Django auth fails or the user doesn't
    exist locally yet. On successful Hive auth the local OrderQ user is
    auto-provisioned (or synced if it already exists).
    """

    def _hive_base(self):
        return getattr(settings, 'HIVE_API_URL', 'http://orchestrator-backend:8000')

    def authenticate(self, request, username=None, password=None, **kwargs):
        if not username or not password:
            return None

        base = self._hive_base()
        session = requests.Session()

        try:
            # Step 1: obtain a CSRF token and session cookie from Hive
            csrf_resp = session.get(f'{base}/api/users/auth/csrf/', timeout=5)
            if csrf_resp.status_code != 200:
                logger.debug('Hive CSRF endpoint returned %s', csrf_resp.status_code)
                return None
            csrf_token = csrf_resp.json().get('csrfToken', '')

            # Step 2: authenticate against Hive
            login_resp = session.post(
                f'{base}/api/users/auth/login/',
                json={'username': username, 'password': password},
                headers={'X-CSRFToken': csrf_token},
                timeout=5,
            )
        except requests.RequestException as exc:
            logger.warning('Hive auth request failed: %s', exc)
            return None

        if login_resp.status_code != 200:
            return None

        hive_user = login_resp.json().get('user', {})
        hive_username = hive_user.get('username') or username
        email = hive_user.get('email', '')
        first_name = hive_user.get('first_name', '')
        last_name = hive_user.get('last_name', '')

        # Prefer linking by email so an existing OrderQ account with the
        # same email is reused rather than creating a parallel account.
        user = None
        if email:
            try:
                user = User.objects.get(email=email)
            except User.DoesNotExist:
                pass

        if user is None:
            user, _ = User.objects.get_or_create(
                username=hive_username,
                defaults={
                    'email': email,
                    'first_name': first_name,
                    'last_name': last_name,
                    'role': 'user',
                },
            )

        # Sync name fields on every login
        updates = {}
        for field, value in [('first_name', first_name), ('last_name', last_name)]:
            if value and getattr(user, field) != value:
                setattr(user, field, value)
                updates[field] = value
        if updates:
            user.save(update_fields=list(updates.keys()))

        return user

    def get_user(self, user_id):
        try:
            return User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return None
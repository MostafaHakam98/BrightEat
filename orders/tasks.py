"""
Celery tasks for menu syncing.
"""
from celery import shared_task
from django.core.management import call_command
from django.utils import timezone
from io import StringIO
from contextlib import redirect_stdout
import logging

logger = logging.getLogger(__name__)


@shared_task(bind=True, name='sync_talabat_menus')
def sync_talabat_menus_task(self, talabat_url=None, manager_username='manager'):
    """
    Async Celery task to sync a single menu from Talabat by URL.

    The task updates its own state so callers can poll for progress:
      PENDING  → queued
      STARTED  → running
      SUCCESS  → { status, items_count, message }
      FAILURE  → exception message
    """
    logger.info('Starting Talabat sync for %s', talabat_url)
    self.update_state(state='STARTED', meta={'message': 'Fetching menu from Talabat…'})

    try:
        buf = StringIO()
        with redirect_stdout(buf):
            call_command(
                'sync_talabat_menus',
                talabat_url=talabat_url,
                manager=manager_username,
                verbosity=0,
            )

        # Count items for the synced menu
        from orders.models import Menu
        items_count = 0
        if talabat_url:
            menu = Menu.objects.filter(talabat_url=talabat_url).first()
            if menu:
                items_count = menu.items.count()

        result = {
            'status': 'success',
            'items_count': items_count,
            'message': f'Synced {items_count} items successfully.',
            'timestamp': timezone.now().isoformat(),
        }
        logger.info('Talabat sync completed: %s', result)
        return result

    except Exception as exc:
        logger.error('Talabat sync failed for %s: %s', talabat_url, exc, exc_info=True)
        raise


@shared_task(bind=True, name='sync_all_talabat_menus')
def sync_all_talabat_menus_task(self, manager_username='manager'):
    """Sync all menus that have a talabat_url configured."""
    from orders.models import Menu

    menus = list(Menu.objects.filter(talabat_url__isnull=False).exclude(talabat_url=''))
    total = len(menus)
    logger.info('Syncing %d Talabat menus', total)

    results = []
    for idx, menu in enumerate(menus, 1):
        self.update_state(
            state='STARTED',
            meta={'message': f'Syncing {menu.restaurant.name} ({idx}/{total})…'},
        )
        try:
            buf = StringIO()
            with redirect_stdout(buf):
                call_command(
                    'sync_talabat_menus',
                    talabat_url=menu.talabat_url,
                    manager=manager_username,
                    verbosity=0,
                )
            results.append({'restaurant': menu.restaurant.name, 'status': 'ok'})
        except Exception as exc:
            logger.error('Failed to sync %s: %s', menu.restaurant.name, exc)
            results.append({'restaurant': menu.restaurant.name, 'status': 'error', 'error': str(exc)})

    return {'status': 'success', 'synced': total, 'results': results, 'timestamp': timezone.now().isoformat()}

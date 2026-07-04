#!/bin/bash
# End-to-end test harness: boots the Django backend against the given
# Postgres/Redis, seeds e2e fixtures, then runs Playwright (which builds and
# serves the frontend on :4173 with /api and /ws proxied to the backend).
#
# Local usage (Postgres on 55432 + Redis on 56379, e.g. throwaway containers):
#   DB_PORT=55432 REDIS_PORT=56379 PYTHON=path/to/venv/bin/python ./scripts/run-e2e.sh
# CI provides services on default ports and sets PYTHON=python.
set -euo pipefail

cd "$(dirname "$0")/.."

export DB_HOST="${DB_HOST:-127.0.0.1}"
export DB_PORT="${DB_PORT:-5432}"
export DB_NAME="${DB_NAME:-orderq_e2e}"
export DB_PASSWORD="${DB_PASSWORD:-postgres}"
export REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
export REDIS_PORT="${REDIS_PORT:-6379}"
export USE_HTTPS=False
PYTHON="${PYTHON:-python}"
BACKEND_PORT="${BACKEND_PORT:-8000}"

echo "── Preparing e2e database (${DB_NAME}) ──"
if command -v psql >/dev/null; then
  PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres \
    -tc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" | grep -q 1 || \
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres \
    -c "CREATE DATABASE ${DB_NAME}"
else
  echo "psql not found — assuming database ${DB_NAME} already exists"
fi

$PYTHON manage.py migrate --noinput

echo "── Seeding e2e fixtures ──"
$PYTHON manage.py shell <<'PYEOF'
from decimal import Decimal
from orders.models import User, Restaurant, Menu, MenuItem

user, created = User.objects.get_or_create(username='e2e_collector', defaults={'role': 'user'})
if created:
    user.set_password('testpass123')
    user.save()

restaurant, _ = Restaurant.objects.get_or_create(name='E2E Diner', defaults={'created_by': user})
menu, _ = Menu.objects.get_or_create(restaurant=restaurant, name='E2E Menu')
MenuItem.objects.get_or_create(menu=menu, name='E2E Burger', defaults={'price': Decimal('50.00')})
print('e2e fixtures ready')
PYEOF

echo "── Starting backend on :8000 ──"
$PYTHON -m uvicorn OrderQ.asgi:application --host 127.0.0.1 --port "$BACKEND_PORT" &
BACKEND_PID=$!
trap 'kill $BACKEND_PID 2>/dev/null || true' EXIT

for i in $(seq 1 30); do
  curl -sf http://127.0.0.1:$BACKEND_PORT/health/ >/dev/null && break
  sleep 1
done
curl -sf http://127.0.0.1:$BACKEND_PORT/health/ >/dev/null || { echo "backend failed to start"; exit 1; }

echo "── Running Playwright ──"
cd frontend
VITE_PROXY_TARGET=http://127.0.0.1:$BACKEND_PORT npx playwright test "$@"

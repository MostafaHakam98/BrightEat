#!/bin/bash
set -e

# Wait for database to be ready
echo "Waiting for database to be ready..."
until PGPASSWORD=${DB_PASSWORD:-postgres} psql -h "${DB_HOST:-db}" -p "${DB_PORT:-5432}" -U "${DB_USER:-postgres}" -d postgres -c '\q' 2>/dev/null; do
  echo "Database is unavailable - sleeping"
  sleep 1
done

# Create database if it doesn't exist
echo "Ensuring database exists..."
DB_NAME=${DB_NAME:-orderq}
PGPASSWORD=${DB_PASSWORD:-postgres} psql -h "${DB_HOST:-db}" -p "${DB_PORT:-5432}" -U "${DB_USER:-postgres}" -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" | grep -q 1 || \
PGPASSWORD=${DB_PASSWORD:-postgres} psql -h "${DB_HOST:-db}" -p "${DB_PORT:-5432}" -U "${DB_USER:-postgres}" -d postgres -c "CREATE DATABASE ${DB_NAME}"

# Migrations must be authored in dev and shipped in the image — generating
# them at runtime in production is unsafe (and replicas would race).
if [ "${RUN_MAKEMIGRATIONS:-false}" = "true" ]; then
  echo "Creating migrations (dev mode)..."
  python manage.py makemigrations || true
fi

echo "Applying migrations..."
python manage.py migrate --noinput

if [ "${SEED_ON_START:-false}" = "true" ]; then
  echo "Seeding data (dev mode)..."
  python manage.py seed_data || echo "Seed data already exists or failed"
fi

echo "Starting server with WebSocket support..."
uvicorn OrderQ.asgi:application --host 0.0.0.0 --port 8000

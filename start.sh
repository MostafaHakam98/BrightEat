#!/bin/bash
set -e

echo "Creating migrations..."
python manage.py makemigrations || true

echo "Applying migrations..."
python manage.py migrate --noinput

echo "Seeding data..."
python manage.py seed_data || echo "Seed data already exists or failed"

echo "Starting server..."
python manage.py runserver 0.0.0.0:8000


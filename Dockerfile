FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    postgresql-client \
    gcc \
    python3-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy project
COPY . .

# Collect static files (skip if STATIC_ROOT not configured)
RUN python manage.py collectstatic --noinput 2>/dev/null || echo "Skipping collectstatic"

# Expose port
EXPOSE 8000

# Copy startup script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Run migrations and start server
CMD ["/app/start.sh"]


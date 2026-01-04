#!/bin/bash

# Script to set up SSL certificates using Let's Encrypt for BrightEat
# This script should be run on the EC2 instance
# Usage: ./scripts/setup-ssl.sh your-domain.com your-email@example.com

set -e

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <domain-name> <email>"
    echo "Example: $0 brighteat.example.com admin@example.com"
    exit 1
fi

DOMAIN=$1
EMAIL=$2
PROJECT_ROOT="/home/ubuntu/BrightEat"
SSL_DIR="$PROJECT_ROOT/ssl"
CERTBOT_DIR="$PROJECT_ROOT/certbot"

echo "🔒 Setting up SSL certificates for domain: $DOMAIN"

# Create necessary directories
mkdir -p "$SSL_DIR"
mkdir -p "$CERTBOT_DIR/www"
mkdir -p "$CERTBOT_DIR/conf"

# Check if certbot is installed
if ! command -v certbot &> /dev/null; then
    echo "📦 Installing certbot..."
    sudo apt-get update
    sudo apt-get install -y certbot
fi

# Stop nginx-router container temporarily to free port 80
echo "🛑 Stopping nginx-router container..."
cd "$PROJECT_ROOT"
docker compose -f docker-compose.prod.yml stop nginx-router || true

# Generate temporary self-signed certificate for initial nginx startup
if [ ! -f "$SSL_DIR/cert.pem" ] || [ ! -f "$SSL_DIR/key.pem" ]; then
    echo "📝 Generating temporary self-signed certificate..."
    openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
        -keyout "$SSL_DIR/key.pem" \
        -out "$SSL_DIR/cert.pem" \
        -subj "/CN=$DOMAIN"
    chmod 600 "$SSL_DIR/key.pem"
    chmod 644 "$SSL_DIR/cert.pem"
fi

# Start nginx-router with temporary certificate
echo "🚀 Starting nginx-router with temporary certificate..."
docker compose -f docker-compose.prod.yml up -d nginx-router

# Wait for nginx to be ready
echo "⏳ Waiting for nginx to be ready..."
sleep 5

# Obtain Let's Encrypt certificate
echo "🔐 Obtaining Let's Encrypt certificate..."
sudo certbot certonly \
    --webroot \
    --webroot-path="$CERTBOT_DIR/www" \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --domains "$DOMAIN" \
    --non-interactive

# Copy certificates to SSL directory
echo "📋 Copying certificates..."
sudo cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$SSL_DIR/cert.pem"
sudo cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$SSL_DIR/key.pem"
sudo chmod 644 "$SSL_DIR/cert.pem"
sudo chmod 600 "$SSL_DIR/key.pem"
sudo chown $USER:$USER "$SSL_DIR/cert.pem" "$SSL_DIR/key.pem"

# Restart nginx-router to use new certificates
echo "🔄 Restarting nginx-router with Let's Encrypt certificates..."
docker compose -f docker-compose.prod.yml restart nginx-router

# Set up auto-renewal
echo "⏰ Setting up certificate auto-renewal..."
(crontab -l 2>/dev/null | grep -v "certbot renew" || true; echo "0 3 * * * certbot renew --quiet --deploy-hook 'cd $PROJECT_ROOT && docker compose -f docker-compose.prod.yml restart nginx-router'") | crontab -

echo "✅ SSL setup complete!"
echo ""
echo "📝 Next steps:"
echo "1. Update your domain's DNS to point to this EC2 instance's IP"
echo "2. Update docker-compose.prod.yml with your domain in FRONTEND_URL"
echo "3. Update CSRF_TRUSTED_ORIGINS and CORS_ALLOWED_ORIGINS in environment variables"
echo "4. Restart all services: docker compose -f docker-compose.prod.yml up -d"


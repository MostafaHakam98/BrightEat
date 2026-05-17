#!/bin/bash

# Script to generate self-signed SSL certificates for testing/development
# Works with both domain names and IP addresses
# Usage: ./scripts/setup-ssl-self-signed.sh 51.20.151.57

set -e

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <domain-or-ip>"
    echo "Example: $0 51.20.151.57"
    echo "Example: $0 brighteat.example.com"
    exit 1
fi

DOMAIN_OR_IP=$1
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSL_DIR="$PROJECT_ROOT/ssl"

echo "🔒 Generating self-signed SSL certificate for: $DOMAIN_OR_IP"
echo "⚠️  WARNING: Self-signed certificates will show security warnings in browsers!"
echo "   Users will need to click 'Advanced' and 'Proceed to site' to accept it."

# Create SSL directory
mkdir -p "$SSL_DIR"

# Create OpenSSL config file for SAN (Subject Alternative Name)
CONFIG_FILE="$SSL_DIR/openssl.conf"
cat > "$CONFIG_FILE" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $DOMAIN_OR_IP

[v3_req]
keyUsage = digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
basicConstraints = CA:FALSE

[alt_names]
EOF

# Add IP or DNS to SAN
if [[ $DOMAIN_OR_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "IP.1 = $DOMAIN_OR_IP" >> "$CONFIG_FILE"
else
    echo "DNS.1 = $DOMAIN_OR_IP" >> "$CONFIG_FILE"
    # For localhost, also add 127.0.0.1
    if [[ "$DOMAIN_OR_IP" == "localhost" ]]; then
        echo "IP.1 = 127.0.0.1" >> "$CONFIG_FILE"
    fi
fi

# Generate self-signed certificate with SAN (valid for 365 days)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$SSL_DIR/key.pem" \
    -out "$SSL_DIR/cert.pem" \
    -config "$CONFIG_FILE" \
    -extensions v3_req

# Set proper permissions
chmod 600 "$SSL_DIR/key.pem"
chmod 644 "$SSL_DIR/cert.pem"
rm -f "$CONFIG_FILE"

echo "✅ Self-signed certificate generated!"
echo "   Certificate: $SSL_DIR/cert.pem"
echo "   Private key: $SSL_DIR/key.pem"
echo ""
echo "🔄 Next steps:"
echo "   1. Restart nginx-router: docker compose -f docker-compose.prod.yml restart nginx-router"
echo "   2. Access your site at: https://$DOMAIN_OR_IP:19991"


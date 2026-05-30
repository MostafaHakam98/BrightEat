# HTTPS Setup Guide for OrderQ

This guide explains how to set up HTTPS for your OrderQ deployment on EC2.

## Prerequisites

1. An EC2 instance running OrderQ
2. A domain name pointing to your EC2 instance's public IP (optional - can use IP address)
3. Ports 80 and 19991 open in your EC2 security group (HTTPS runs on port 19991)

## Option 1: Let's Encrypt (Recommended for Production)

### Step 1: Update DNS
Ensure your domain's A record points to your EC2 instance's public IP address.

### Step 2: Run SSL Setup Script
SSH into your EC2 instance and run:

```bash
cd /home/ubuntu/OrderQ
./scripts/setup-ssl.sh your-domain.com your-email@example.com
```

This script will:
- Install certbot if needed
- Generate temporary self-signed certificates
- Obtain Let's Encrypt certificates
- Set up automatic renewal
- Configure nginx to use HTTPS

### Step 3: Update Environment Variables
Update your `docker-compose.prod.yml` or environment variables:

```yaml
environment:
  - FRONTEND_URL=https://your-domain.com:19991
  - USE_HTTPS=True
  - CSRF_TRUSTED_ORIGINS=https://your-domain.com:19991
  - CORS_ALLOWED_ORIGINS=https://your-domain.com:19991
```

### Step 4: Restart Services
```bash
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d
```

## Option 2: Self-Signed Certificate (For IP Address or Testing)

If you don't have a domain name (e.g., using IP address like `51.20.151.57`):

```bash
cd /home/ubuntu/OrderQ
./scripts/setup-ssl-self-signed.sh 51.20.151.57
```

**Note:** Self-signed certificates will show security warnings in browsers. Users will need to click "Advanced" and "Proceed to site" to accept the certificate.

The script automatically detects if you're using an IP address or domain name and configures the certificate accordingly.

## Configuration Changes Made

### 1. nginx-router.conf
- Added HTTPS server block listening on port 19991
- Added HTTP to HTTPS redirect (port 80 redirects to HTTPS on 19991)
- Configured SSL certificates and security headers
- Updated proxy headers to use `https` protocol with port 19991

### 2. docker-compose.prod.yml
- Port mapping: `80:80` (HTTP redirect) and `19991:19991` (HTTPS)
- Added SSL certificate volume mounts
- Updated `FRONTEND_URL` to use HTTPS with port 19991
- Added `CSRF_TRUSTED_ORIGINS` and `CORS_ALLOWED_ORIGINS` environment variables

### 3. Django settings.py
- Added HTTPS security settings (CSRF_COOKIE_SECURE, SESSION_COOKIE_SECURE)
- Configured SECURE_PROXY_SSL_HEADER for nginx proxy
- Updated default CORS and CSRF origins to use HTTPS
- Made settings configurable via environment variables

## Security Features Enabled

- **HSTS (HTTP Strict Transport Security)**: Forces browsers to use HTTPS
- **Secure Cookies**: Cookies only sent over HTTPS
- **Security Headers**: X-Frame-Options, X-Content-Type-Options, X-XSS-Protection
- **TLS 1.2/1.3**: Modern encryption protocols only

## Troubleshooting

### Certificate Issues
- Ensure port 80 is accessible for Let's Encrypt validation
- Check that your domain DNS is properly configured
- Verify certificates are in `/home/ubuntu/OrderQ/ssl/`

### Connection Issues
- Check EC2 security group allows inbound traffic on ports 80 and 19991
- Verify nginx-router container is running: `docker compose ps`
- Check nginx logs: `docker compose logs nginx-router`

### Mixed Content Warnings
- Ensure all API calls use relative URLs (already configured)
- Check that WebSocket connections use WSS (already configured)
- Verify no hardcoded HTTP URLs in frontend code

## Certificate Renewal

Let's Encrypt certificates expire every 90 days. The setup script automatically configures renewal via cron job. To manually renew:

```bash
sudo certbot renew
cd /home/ubuntu/OrderQ
docker compose -f docker-compose.prod.yml restart nginx-router
```

## Testing HTTPS

1. Visit `https://your-domain.com:19991` or `https://51.20.151.57:19991` in a browser
2. Check that HTTP (port 80) redirects to HTTPS on port 19991
3. Verify no mixed content warnings in browser console
4. Test WebSocket connections (should use WSS)
5. Test API endpoints

## Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `USE_HTTPS` | Enable HTTPS security settings | `True` |
| `FRONTEND_URL` | Frontend URL for share links | `https://51.20.151.57:19991` |
| `CSRF_TRUSTED_ORIGINS` | Comma-separated trusted origins | `https://51.20.151.57:19991` |
| `CORS_ALLOWED_ORIGINS` | Comma-separated CORS origins | `https://51.20.151.57:19991` |


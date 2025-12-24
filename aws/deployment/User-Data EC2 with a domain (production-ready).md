#!/bin/bash
set -e

LOG_FILE="/var/log/user-data.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting EC2 bootstrap at $(date)"

# ---------------------------
# System update
# ---------------------------
apt-get update -y
apt-get upgrade -y

# ---------------------------
# Install core utilities
# ---------------------------
apt-get install -y curl unzip software-properties-common ca-certificates gnupg lsb-release build-essential npm

# ---------------------------
# Install Node.js LTS via NodeSource
# ---------------------------
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

echo "Node version: $(node -v)"
echo "NPM version: $(npm -v)"

# ---------------------------
# Install 'n' for Node version management
# ---------------------------
npm install -g n
n lts
hash -r

echo "Node version after n: $(node -v)"

# ---------------------------
# Install PM2 globally
# ---------------------------
npm install -g pm2
pm2 startup systemd -u ubuntu --hp /home/ubuntu

# ---------------------------
# Create deployment directory
# ---------------------------
APP_DIR="/var/www/app-name"
mkdir -p "$APP_DIR"
chown -R ubuntu:ubuntu "$APP_DIR"
chmod -R 755 "$APP_DIR"

# ---------------------------
# Maintenance page fallback
# ---------------------------
MAINT_DIR="/var/www/html"
mkdir -p "$MAINT_DIR"
echo "<h1>Site under maintenance</h1>" > "$MAINT_DIR/index.html"

# ---------------------------
# Install and configure Nginx
# ---------------------------
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx

NGINX_CONF="/etc/nginx/sites-available/app-name"
cat <<EOF > "$NGINX_CONF"
server {
    listen 80;
    server_name example.com www.example.com;

    root $MAINT_DIR;
    index index.html;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        error_page 502 = /index.html;
    }
}
EOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/app-name
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl reload nginx

# ---------------------------
# Optional SSL tooling (CI/CD friendly)
# ---------------------------
apt-get install -y certbot python3-certbot-nginx
echo "SSL will be handled by Certbot or CI/CD workflow"

# ---------------------------
# Ensure PM2 runs on boot
# ---------------------------
pm2 save

# ---------------------------
# Final log
# ---------------------------
echo "EC2 bootstrap completed successfully at $(date)"
echo "Deployment directory: $APP_DIR"
echo "PM2 ready for CI/CD deployments"

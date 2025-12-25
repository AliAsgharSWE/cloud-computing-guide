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
apt-get install -y curl unzip software-properties-common ca-certificates

# ---------------------------
# Install Node.js (LTS)
# ---------------------------
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

node -v
npm -v

# ---------------------------
# Install PM2 globally
# ---------------------------
npm install -g pm2

# Enable PM2 for ubuntu user
pm2 startup systemd -u ubuntu --hp /home/ubuntu

# ---------------------------
# Create application directories
# ---------------------------
APP_DIR="/var/www/app-name"
MAINT_DIR="/var/www/html"

mkdir -p "$APP_DIR"
mkdir -p "$MAINT_DIR"

chown -R ubuntu:ubuntu "$APP_DIR"
chmod -R 755 "$APP_DIR"

# Create default maintenance page
echo "<h1>Site under maintenance</h1>" > "$MAINT_DIR/index.html"

# ---------------------------
# Install Nginx
# ---------------------------
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx

# ---------------------------
# Configure Nginx with fallback
# ---------------------------
cat <<EOF > /etc/nginx/sites-available/app-name
server {
    listen 80;
    server_name _;

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

        # Fallback to maintenance page if Node.js is down
        proxy_intercept_errors on;
        error_page 502 = /index.html;
    }
}
EOF

ln -sf /etc/nginx/sites-available/app-name /etc/nginx/sites-enabled/app-name
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl reload nginx

# ---------------------------
# Final Log
# ---------------------------
echo "User data setup completed successfully at $(date)"
echo "Deployment directory: $APP_DIR"
echo "Maintenance page ready at $MAINT_DIR/index.html"

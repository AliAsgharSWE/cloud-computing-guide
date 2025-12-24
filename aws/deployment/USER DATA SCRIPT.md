#!/bin/bash
set -e

LOG_FILE="/var/log/user-data.log"
exec > >(tee -a $LOG_FILE) 2>&1

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
# Install Nginx
# ---------------------------
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx

# ---------------------------
# Create application directory
# ---------------------------
mkdir -p /var/www/paymate-api
chown -R ubuntu:ubuntu /var/www/paymate-api
chmod -R 755 /var/www/paymate-api

# ---------------------------
# Nginx Reverse Proxy
# ---------------------------
cat <<EOF > /etc/nginx/sites-available/paymate-api
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/paymate-api /etc/nginx/sites-enabled/paymate-api
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl reload nginx

# ---------------------------
# Final Log
# ---------------------------
echo "User data setup completed successfully at $(date)"

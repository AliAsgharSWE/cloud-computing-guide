#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/user-data.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🚀 EC2 bootstrap started at $(date)"

# ---------------------------
# Base system updates & core packages
# ---------------------------
apt-get update -y
apt-get upgrade -y
apt-get install -y curl unzip software-properties-common ca-certificates ufw git build-essential

# ---------------------------
# Node.js LTS (system-wide)
# ---------------------------
install_node() {
  local NODE_VERSION=${1:-lts}  # default to LTS
  curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
  apt-get install -y nodejs
  npm config set fund false
  npm config set audit false
  echo "✅ Node.js installed: $(node -v)"
}

install_node lts

# ---------------------------
# PM2 process manager
# ---------------------------
npm install -g pm2
pm2 startup systemd -u ubuntu --hp /home/ubuntu
echo "✅ PM2 installed"

# ---------------------------
# App directories
# ---------------------------
APP_DIR="/var/www/app"
MAINT_DIR="/var/www/html"

mkdir -p "$APP_DIR" "$MAINT_DIR"
chown -R ubuntu:ubuntu "$APP_DIR"
chmod -R 755 "$APP_DIR"

# ---------------------------
# Maintenance page
# ---------------------------
cat <<EOF > "$MAINT_DIR/maintenance.html"
<!DOCTYPE html>
<html>
<head>
  <title>Maintenance</title>
  <style>
    body { font-family: sans-serif; text-align: center; margin-top: 10%; }
  </style>
</head>
<body>
  <h1 style="color: #333; font-size: 24px; font-weight: bold;">Maintenance in progress, please check back later.</h1>
  <p style="color: #666; font-size: 16px;">We'll be right back.</p>
</body>
</html>
EOF

# ---------------------------
# Nginx setup
# ---------------------------
apt-get install -y nginx
systemctl enable nginx

cat <<EOF > /etc/nginx/sites-available/app
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

        proxy_intercept_errors on;
        error_page 502 503 504 = /maintenance.html;
    }

    location = /maintenance.html {
        root /var/www/html;
        internal;
    }
}
EOF

ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx
echo "✅ Nginx configured"

# ---------------------------
# Firewall setup
# ---------------------------
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable
echo "✅ Firewall enabled"

# ---------------------------
# Helpful function: Upgrade Node in future
# ---------------------------
cat <<'EOF' > /usr/local/bin/upgrade-node
#!/bin/bash
# Usage: sudo upgrade-node <version|lts>
VERSION="${1:-lts}"
curl -fsSL https://deb.nodesource.com/setup_${VERSION}.x | bash -
apt-get install -y nodejs
npm config set fund false
npm config set audit false
echo "✅ Node upgraded to $(node -v)"
EOF

chmod +x /usr/local/bin/upgrade-node
echo "✅ upgrade-node script installed (sudo upgrade-node lts)"

# ---------------------------
# Final PM2 startup & log
# ---------------------------
sudo -u ubuntu pm2 save
echo "✅ Bootstrap complete at $(date)"
echo "App directory: $APP_DIR"
echo "Maintenance page: $MAINT_DIR/maintenance.html"

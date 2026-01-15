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
# Prisma CLI (required for migrations)
# ---------------------------
npm install -g prisma @prisma/client
echo "✅ Prisma CLI installed"

# ---------------------------
# PostgreSQL installation & setup
# ---------------------------
apt-get install -y postgresql postgresql-contrib
systemctl enable postgresql
systemctl start postgresql
echo "✅ PostgreSQL installed & running"

# Create DB and user
sudo -u postgres psql <<EOF
CREATE DATABASE appdb;
CREATE USER appuser WITH ENCRYPTED PASSWORD 'StrongPassword123!';
GRANT ALL PRIVILEGES ON DATABASE appdb TO appuser;
EOF
echo "✅ Database 'appdb' and user 'appuser' created"

# ---------------------------
# App directories (matching CI/CD deployment path)
# ---------------------------
APP_DIR="/var/www/checkpoint"
MAINT_DIR="/var/www/html"

mkdir -p "$APP_DIR" "$APP_DIR/backups" "$APP_DIR/logs" "$APP_DIR/uploads" "$MAINT_DIR"
chown -R ubuntu:ubuntu "$APP_DIR"
chmod -R 755 "$APP_DIR"
chmod 700 "$APP_DIR"  # Secure the main directory
echo "✅ App directories created: $APP_DIR"

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
# SSH Configuration (keepalive for CI/CD)
# ---------------------------
SSH_CONFIG="/etc/ssh/sshd_config"
if ! grep -q "ClientAliveInterval" "$SSH_CONFIG"; then
  echo "" >> "$SSH_CONFIG"
  echo "# SSH Keepalive for CI/CD deployments" >> "$SSH_CONFIG"
  echo "ClientAliveInterval 30" >> "$SSH_CONFIG"
  echo "ClientAliveCountMax 10" >> "$SSH_CONFIG"
  systemctl restart sshd
  echo "✅ SSH keepalive configured"
else
  echo "✅ SSH keepalive already configured"
fi

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
# Additional tools for CI/CD
# ---------------------------
# Install curl (if not already installed) for health checks
apt-get install -y curl

# Ensure ubuntu user has proper permissions
usermod -aG sudo ubuntu
echo "✅ User permissions configured"

# ---------------------------
# Create initial .env placeholder (will be replaced by CI/CD)
# ---------------------------
if [ ! -f "$APP_DIR/.env" ]; then
  touch "$APP_DIR/.env"
  chown ubuntu:ubuntu "$APP_DIR/.env"
  chmod 600 "$APP_DIR/.env"
  echo "✅ .env placeholder created"
fi

# ---------------------------
# Final PM2 startup & log
# ---------------------------
sudo -u ubuntu pm2 save || true  # May fail if no processes, that's OK
echo "✅ Bootstrap complete at $(date)"
echo ""
echo "📋 EC2 Instance Ready for CI/CD Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "App directory: $APP_DIR"
echo "Backups directory: $APP_DIR/backups"
echo "Logs directory: $APP_DIR/logs"
echo "Uploads directory: $APP_DIR/uploads"
echo "Maintenance page: $MAINT_DIR/maintenance.html"
echo ""
echo "Installed Software:"
echo "  - Node.js: $(node -v)"
echo "  - npm: $(npm -v)"
echo "  - PM2: $(pm2 -v)"
echo "  - Prisma: $(prisma --version 2>/dev/null || echo 'installed')"
echo ""
echo "Database:"
echo "  - Database: appdb"
echo "  - User: appuser"
echo "  - Password: StrongPassword123!"
echo ""
echo "SSH Configuration:"
echo "  - Keepalive: Enabled (ClientAliveInterval 30)"
echo "  - Ready for CI/CD deployments"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

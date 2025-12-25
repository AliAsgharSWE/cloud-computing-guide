# 🎯 Master Deployment Guide: Node.js Backend on EC2 with GitHub Actions CI/CD

**End state (Non-Negotiable):**

- One app directory: `/var/www/app-name`
- ❌ No `git clone` on EC2
- ✅ Code deployed only via GitHub Actions
- ✅ Environment variables securely injected from GitHub Secrets
- ✅ PM2 cluster mode, survives reboots
- ✅ Zero-downtime reloads
- ✅ Backup & rollback enabled
- ✅ Nginx with timeout and reverse proxy configuration
- ✅ PostgreSQL database installed and configured

---

## 🧠 Architecture Overview

**Local machine:**

- Develop and push code to `main`.

**GitHub Actions (CI/CD):**

- Build app, package artifact
- Inject `.env` from secrets
- Upload artifact
- SSH into EC2
- Deploy artifact, install prod deps, run migrations, reload PM2
- Verify deployment & rollback if needed

**EC2 (Production Server):**

- Only receives build artifacts
- Runs app via PM2 cluster
- Clean directory with no git repo


---
> **If you use the automated EC2 bootstrap script [`ec2-bootstrap-without-domain.sh`](../userdata/ec2-bootstrap-without-domain.sh), you can **skip Steps 1–5 below**:

**What the script already does for you:**
- Performs all initial system updates & security upgrades
- Installs the correct version of Node.js
- Installs, configures, and enables Nginx (including a maintenance page)
- Creates and permission-secures deployment directories
- Installs and sets up PM2 process manager
- Installs and configures PostgreSQL with database and user

**What to do next:**  
**You can skip to [STEP 7](#step-7-cicd-deploy-with-github-actions) of this guide** (CI/CD with GitHub Actions deployment, artifact handling, PM2 reload, etc).

---

[View or download the recommended EC2 bootstrap script  
`ec2-bootstrap-without-domain.sh`](../userdata/ec2-bootstrap-without-domain.sh)

## STEP 1: Initial EC2 Server Setup (One-Time Only)

SSH into EC2:

```bash
ssh ubuntu@YOUR_EC2_IP

Update and upgrade packages:

```bash
sudo apt update && sudo apt upgrade -y
```

---

## STEP 2: Install Node.js (One-Time Only)

Install Node.js via `n` (latest LTS):

```bash
sudo apt install -y npm
sudo npm install -g n
sudo n lts   # or sudo n 20
```

Reconnect to apply:

```bash
exit
ssh ubuntu@YOUR_EC2_IP
node -v
```

---

## STEP 3: Install & Configure Nginx (One-Time Only)

```bash
sudo apt install nginx -y
sudo systemctl enable nginx
sudo systemctl start nginx
```

Create Nginx config:

```bash
sudo nano /etc/nginx/sites-available/app-name
```

```nginx
server {
    listen 80;
    server_name YOUR_DOMAIN_OR_EC2_IP;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

Enable site:

```bash
sudo ln -s /etc/nginx/sites-available/app-name /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

---

## STEP 4: Create Deployment Directory (One-Time Only)

```bash
sudo mkdir -p /var/www/app-name
sudo chown -R ubuntu:ubuntu /var/www/app-name
```

⚠️ This directory will **never** contain a git repo.

---

## STEP 5: Install PM2 (One-Time Only)

```bash
sudo npm install -g pm2
pm2 startup
```

Copy the printed command and execute it:

```bash
pm2 save
```

✅ Guarantees PM2 auto-start after reboot.

---

## STEP 6: Install & Configure PostgreSQL (One-Time Only)

Install PostgreSQL:

```bash
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql
```

Create database and user:

```bash
sudo -u postgres psql <<EOF
CREATE DATABASE appdb;
CREATE USER appuser WITH ENCRYPTED PASSWORD 'StrongPassword123!';
GRANT ALL PRIVILEGES ON DATABASE appdb TO appuser;
EOF
```

⚠️ **Security Note:** Change `'StrongPassword123!'` to a strong password and store it securely in GitHub Secrets as `DATABASE_URL`. E.g.

```
DATABASE_URL=postgresql://appuser:StrongPassword123!@localhost:5432/appdb
```
---

## Verify EC2 Bootstrap Installation

After your EC2 instance launches, verify that all installations completed successfully using the comprehensive verification guide:

📋 **[Complete Verification Guide](./Verification%20Guide.md)** - Step-by-step commands to verify:

- ✅ User-data script execution
- ✅ Node.js & npm installation
- ✅ PM2 process manager & systemd integration
- ✅ PostgreSQL database & user setup
- ✅ App & maintenance directories
- ✅ Nginx configuration & service
- ✅ Firewall (UFW) rules
- ✅ Helper scripts
- ✅ Common issues & troubleshooting

**Quick Check:**
```bash
sudo cat /var/log/user-data.log
```

Look for "✅ Bootstrap complete" at the end of the log file.

---

## Fix App Directory to Match Deployment Path

### Problem:

EC2 app directory (created by user-data script) does not match the path expected by deployment scripts.

This can cause PM2 errors, failed deployments, or missing `.env` and logs.

**Example:** User-data script creates `/var/www/app`, but your deployment expects `/var/www/app-name`.

### ✅ Steps to fix

#### 1. Rename the directory
```bash
sudo mv /var/www/app /var/www/app-name
```

#### 2. Fix ownership
```bash
sudo chown -R ubuntu:ubuntu /var/www/app-name
```

#### 3. Verify
```bash
ls -ld /var/www/app-name
```

**Expected output:**
```
drwxr-xr-x 2 ubuntu ubuntu ...
```

⚠️ **Important:** Replace `app-name` with your actual app name that matches your deployment configuration (e.g., as specified in `ecosystem.config.cjs` and GitHub Actions workflow).

---

## STEP 7: Prepare Your App for CI/CD

Required files in repo:

- `package.json`
- `ecosystem.config.cjs`
- `build` script
- `/dist` output
- `/health` endpoint

Example **ecosystem.config.cjs** ([view the starter template here](../Eco-system/ecosystem.config.cjs)).  
You can copy this starter and modify it as needed for your app or another dummy ecosystem.config.cjs is in the following:

```js
module.exports = {
  apps: [
    {
      name: "app-name",
      script: "dist/main.js",
      exec_mode: "cluster",
      instances: "max",
      env: {
        NODE_ENV: "production"
      }
    }
  ]
};
```

---

## STEP 8: Configure GitHub Secrets

In your GitHub repository → Settings → Secrets → Actions:

- `EC2_HOST` – EC2 public IP
- `EC2_USERNAME` – EC2 user (e.g., `ubuntu`) and for Amazon Machine Image (e.g., `ec2-user`)
- `EC2_SSH_KEY` – Private key content
- `DATABASE_URL`, `JWT_SECRET`, `REFRESH_TOKEN_SECRET`, `PORT`, `SERVER_URL`, `FRONTEND_URL`, SMTP secrets and others...
- **Ensure that the `DATABASE_URL` references your EC2-hosted or managed database instance, not your local development database.**

⚠️ Never commit `.env` to git.

---

## STEP 9: GitHub Actions Workflow

Create `.github/workflows/deploy.yml`:

**CI Phase (Build & Package):**

- Checkout code
- Install deps
- Build app
- Package `dist`, `src`, `package*.json`, `ecosystem.config.cjs`
- Upload artifact

**CD Phase (Deploy & Verify):**

- Download artifact
- SSH into EC2
- Fix ownership
- Backup current version (keep last 5)
- Extract artifact
- Install prod deps
- Create `.env` if missing
- Start/reload PM2 cluster (zero-downtime)
- Verify via curl
- Rollback on failure if needed

*(The full YAML is robust and production-ready.  
View the actual workflow YAML in [`aws/deployment/CI-CD/github-actions-workflow.yml`](./github-actions-workflow.yml) for a ready-to-use template.)*

---

## STEP 10: Deployment Flow (Every Push)

1. `git push origin main`
2. GitHub Actions builds & packages app
3. Artifact uploaded & deployed to EC2
4. `/var/www/app-name` updated
5. PM2 reloads app (zero-downtime)
6. Backup maintained
7. Deployment verified via health check
8. Automatic rollback if failure

---

## STEP 11: Verification & Debugging

On EC2:

```bash
pm2 status
pm2 logs app-name
curl http://localhost:8000/health
```

---

## 🚫 What You Must NEVER Do

- ❌ `git clone` on EC2
- ❌ Edit code manually on server
- ❌ Run app without PM2
- ❌ Store secrets in repo

---

## 🏁 Final Outcome

- Enterprise-grade CI/CD with GitHub Actions
- Artifact-only deployment
- PM2 cluster zero-downtime reloads
- Backup & rollback safety
- Nginx with timeouts and reverse proxy
- Scalable, clean production environment
```

---

If you want, I can also **include the full ready-to-use GitHub Actions YAML** inside this Markdown so it’s **copy-paste deploy-ready**.  

Do you want me to do that?

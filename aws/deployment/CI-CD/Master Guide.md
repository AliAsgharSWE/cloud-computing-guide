Here’s the combined deployment guide in clean **Markdown** format:

```markdown
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

```
---
**Note: If you are using the EC2 bootstrap script ec2-bootstrap-without-domain.sh
, you can ignore Markdown Steps 1–5:**

STEP 1: Initial EC2 Server Setup (update & upgrade)

STEP 2: Install Node.js

STEP 3: Install & Configure Nginx

STEP 4: Create Deployment Directory

STEP 5: Install PM2

The script already handles system updates, Node.js installation, Nginx setup with a maintenance page, deployment directories, and PM2 installation.

Continue following STEP 6 onwards in the Markdown guide for app CI/CD, GitHub Actions, deployment flow, and verification.

**Download or view the EC2 bootstrap script:** [`ec2-bootstrap-without-domain.sh`](../userdata/ec2-bootstrap-without-domain.sh)
---

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

## STEP 6: Prepare Your App for CI/CD

Required files in repo:

- `package.json`
- `ecosystem.config.cjs`
- `build` script
- `/dist` output
- `/health` endpoint

Example **ecosystem.config.cjs**:

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

## STEP 7: Configure GitHub Secrets

In your GitHub repository → Settings → Secrets → Actions:

- `EC2_HOST` – EC2 public IP
- `EC2_USERNAME` – EC2 user (e.g., `ubuntu`)
- `EC2_SSH_KEY` – Private key content
- `DATABASE_URL`, `JWT_SECRET`, `REFRESH_TOKEN_SECRET`, `PORT`, `SERVER_URL`, `FRONTEND_URL`, SMTP secrets

⚠️ Never commit `.env` to git.

---

## STEP 8: GitHub Actions Workflow

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

*(The full YAML is robust and production-ready.)*

---

## STEP 9: Deployment Flow (Every Push)

1. `git push origin main`
2. GitHub Actions builds & packages app
3. Artifact uploaded & deployed to EC2
4. `/var/www/app-name` updated
5. PM2 reloads app (zero-downtime)
6. Backup maintained
7. Deployment verified via health check
8. Automatic rollback if failure

---

## STEP 10: Verification & Debugging

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

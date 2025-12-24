## 🎯 Final Deployment Goal (Non-Negotiable)

This guide sets up a **fully automated, production-grade CI/CD pipeline** for a Node.js backend using GitHub Actions and EC2.

**End state:**

* ONE app directory: `/var/www/app-name`
* ❌ No `git clone` on EC2
* ✅ Code deployed only via GitHub Actions
* ✅ Environment variables injected securely from GitHub Secrets
* ✅ PM2 always running and survives server reboots
* ✅ Zero-downtime reloads

---

## 🧠 Architecture Overview (Understand First)

**Local machine**

* You write code
* You push to `main`

⬇️

**GitHub Actions (CI/CD)**

* Installs deps
* Builds app
* Creates a deployment artifact
* Injects `.env` from secrets
* SSHs into EC2
* Deploys + reloads PM2

⬇️

**EC2 (Production Server)**

* NEVER runs `git clone`
* ONLY receives build artifacts
* Runs app via PM2

---

## STEP 1: Initial EC2 Server Preparation (One-Time Only)

SSH into your EC2 instance:

```bash
ssh ubuntu@YOUR_EC2_IP
```

Update system packages:

```bash
sudo apt update && sudo apt upgrade -y
```

---

## STEP 2: Install Node.js (One-Time Only)

Install Node Version Manager and latest LTS:

```bash
sudo apt install -y npm
sudo npm install -g n
sudo n lts   # or sudo n 20
```

Reconnect to apply changes:

```bash
exit
ssh ubuntu@YOUR_EC2_IP
node -v
```

---

## STEP 3: Install and Configure Nginx (One-Time Only)

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
        proxy_pass http://localhost:4300;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
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

⚠️ **This directory will NEVER contain a git repo.**

---

## STEP 5: Install PM2 (One-Time Only)

```bash
sudo npm install -g pm2
pm2 startup
```

👉 Copy and execute the command PM2 prints.

```bash
pm2 save
```

This guarantees PM2 auto-starts after reboot.

---

## STEP 6: Prepare Your Application for CI/CD

### Required Files in Repo

* `ecosystem.config.cjs`
* `package.json`
* `build` script
* `dist/` output
* `/health` endpoint

### ecosystem.config.cjs (Example)

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

## STEP 7: Configure GitHub Secrets (Critical)

GitHub → Repo → Settings → Secrets → Actions

Required secrets:

* `EC2_HOST`
* `EC2_USERNAME` (ubuntu)
* `EC2_SSH_KEY`
* `DATABASE_URL`
* `JWT_SECRET`
* `REFRESH_TOKEN_SECRET`
* `PORT`
* `SERVER_URL`
* `FRONTEND_URL`
* SMTP secrets

⚠️ **Never commit `.env` to git**

---

## STEP 8: GitHub Actions CI/CD Workflow (Automated Deployment)

Create:

```
.github/workflows/deploy.yml
```

### CI Phase (Build)

* Checkout code
* Install dependencies
* Build app
* Package only required files

### CD Phase (Deploy)

* Copy artifact to EC2
* Generate `.env` from secrets
* Backup previous version
* Extract new build
* Install prod deps
* Run Prisma migrations
* Reload PM2

👉 Your provided workflow is **architecturally correct** and follows best practices.

---

## STEP 9: Deployment Flow (What Happens on Every Push)

1. `git push origin main`
2. GitHub Actions builds app
3. Artifact uploaded
4. Artifact copied to EC2
5. `/var/www/app-name` updated
6. PM2 reloads app (zero downtime)
7. Health check verified

---

## STEP 10: Verification & Debugging

On EC2:

```bash
pm2 status
pm2 logs app-name
```

Health check:

```bash
curl http://localhost:4300/health
```

---

## 🚫 What You Must NEVER Do

* ❌ `git clone` on EC2
* ❌ Edit code manually on server
* ❌ Run app without PM2
* ❌ Store secrets in repo

---

## 🏁 Final Outcome

You now have:

* Enterprise-grade CI/CD
* Reproducible deployments
* Zero-downtime releases
* Rollback safety
* Clean server state

This setup scales to teams, microservices, and production traffic without changing fundamentals.

**This is how senior engineers deploy.**

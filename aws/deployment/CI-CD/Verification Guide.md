# EC2 Bootstrap Verification Guide

Complete verification checklist for installations performed by `ec2-bootstrap-without-domain.sh` user-data script.

---

## 1️⃣ Confirm User-Data Script Ran Successfully

### Check user-data log
```bash
sudo cat /var/log/user-data.log
```

### What to look for

✅ **EC2 bootstrap started**  
✅ **Node.js installed**  
✅ **PM2 installed**  
✅ **PostgreSQL installed & running**  
✅ **Nginx configured**  
✅ **Bootstrap complete**

❌ **If the log stops suddenly, that's where it failed.**

👉 **If this file does not exist, user-data didn't run.**

---

## 2️⃣ Verify Node.js & npm

### Check versions
```bash
node -v
npm -v
```

**Expected:**
- `v18.x.x` or `v20.x.x` (LTS)
- `9.x+` or `10.x+`

### Verify NodeSource installation
```bash
which node
```

**Expected:**
```
/usr/bin/node
```

---

## 3️⃣ Verify PM2 & Startup Persistence

### Check PM2 version and status
```bash
pm2 -v
pm2 list
```

**Expected:**
- PM2 version printed
- Empty list is OK (no app yet)

### Check systemd startup
```bash
systemctl status pm2-ubuntu
```

**Expected:**
```
Active: active (running)
```

⚠️ **If this is inactive, PM2 startup did not register correctly.**

---

## 4️⃣ Verify PostgreSQL

### Check service status
```bash
systemctl status postgresql
```

**Expected:**
```
Active: active (running)
```

### Verify database and user

Connect to PostgreSQL:
```bash
sudo -u postgres psql
```

Inside psql, run:
```sql
\l          -- List all databases
\du         -- List all users
\q          -- Quit
```

**Expected:**
- Database: `appdb`
- User: `appuser`

### Test login
```bash
psql -h localhost -U appuser -d appdb
```

**Expected:** If it asks for password (`StrongPassword123!`) and logs in → ✅ **success**

---

## 5️⃣ Verify App & Maintenance Directories

### Check directory structure

```bash
ls -ld /var/www/app
ls -l /var/www/html/maintenance.html
```

**Expected:**

- `/var/www/app` exists and is owned by `ubuntu:ubuntu`

  Example output:
  ```
  drwxr-xr-x 2 ubuntu ubuntu 4096 Dec 25 18:07 /var/www/app
  ```

- `maintenance.html` exists in `/var/www/html/`

  Example output:
  ```
  -rw-r--r-- 1 root root 312 Dec 25 18:07 /var/www/html/maintenance.html
  ```

**What this confirms:**

- The app directory is ready for deployments.
- The Nginx maintenance page is present for fallback when the app is down.

## 6️⃣ Verify Nginx

### Check configuration syntax
```bash
sudo nginx -t
```

**Expected:**
```
syntax is ok
test is successful
```

### Restart Nginx after changes

```bash
sudo systemctl restart nginx
```

### Check service status
```bash
sudo systemctl status nginx
```

**Expected:**
```
Active: active (running)
```

### Test from browser

Open in browser:
```
http://<EC2_PUBLIC_IP>
```

**Expected:** Since no app is running on port 8000, you should see:

👉 **Maintenance page**

This confirms:
- ✅ Nginx proxy works
- ✅ Error interception works
- ✅ Maintenance fallback works

---

## 7️⃣ Verify Firewall (UFW)

### Check firewall status
```bash
sudo ufw status
```

**Expected:**
```
Status: active

22/tcp                     ALLOW       OpenSSH
80,443/tcp                 ALLOW       Nginx Full
```

⚠️ **If SSH (22) is blocked → STOP IMMEDIATELY and fix firewall rules!**

---

## 8️⃣ Managing Node.js Version: Upgrade, Downgrade, or Install Specific Version

Want to check, upgrade, or downgrade your Node.js version? Here’s how to do it reliably and safely.

### 1️⃣ RECOMMENDED: Use `n` Node Version Manager

Install `n` globally if you haven't already:
```bash
sudo npm install -g n
```

- To upgrade or switch to Node.js 20 (for example):
  ```bash
  sudo n 20
  ```

- To switch to the latest LTS:
  ```bash
  sudo n lts
  ```

- To downgrade to Node.js 18:
  ```bash
  sudo n 18
  ```

- Check your current Node.js version:
  ```bash
  node -v
  ```

**Why use `n`?**
- Instantly switch between Node.js versions
- Works for both upgrade and downgrade
- No repo conflicts or need to know exact package versions
- Industry-standard and trouble-free

---

### 2️⃣ ADVANCED: Use `apt-get` to Install a Specific Node Version

You *can* also use `apt-get` to install a specific version (requires knowing the exact package string):

```bash
apt-cache showpkg nodejs
```
Find the available versions, then:
```bash
sudo apt-get install -y nodejs=<exact-version>
```
*Example:*
```bash
sudo apt-get install -y nodejs=20.5.1-1nodesource1
```
> ⚠️ This approach is tricky, unnecessary for most users, and can cause headaches with dependencies. **Just use `n` instead**, unless you have a special OS or package constraint.

---

### ✅ Best Practice / Recommended Fix

- Use your existing `upgrade-node` script for fast LTS upgrades:
  ```bash
  sudo upgrade-node lts
  ```

- For upgrades/downgrades to arbitrary versions (e.g., test your app on Node 18 or 20), use `n`:
  ```bash
  sudo npm install -g n
  sudo n 20
  node -v    # should now show v20.x.x
  ```

This is fast, clean, and avoids NodeSource/apt issues.

---

#### 🔎 Quick Check: Is the `upgrade-node` helper script present?
```bash
ls -l /usr/local/bin/upgrade-node
```
**Expected:** File exists and is executable (mode should include "x").


## 9️⃣ Common Issues & Solutions

### 🔴 PostgreSQL password hard-coded

**Issue:** Password `StrongPassword123!` is hard-coded in user-data script.

**For production:**
- Move DB credentials to AWS Secrets Manager
- Or use environment variables injected via CI/CD
- Never commit passwords to version control

### 🔴 PM2 save before app exists

**Note:** The script runs `pm2 save` before any app is deployed. This is fine, but once you deploy:

```bash
pm2 start ecosystem.config.js
pm2 save
```

### 🔴 User-data script failed

**If user-data didn't run:**
1. Check CloudWatch logs (if enabled)
2. Check EC2 console → Instance → View instance logs
3. Manually run the bootstrap script
4. Check instance metadata: `curl http://169.254.169.254/latest/user-data`

### 🔴 Service not starting

**If a service (Nginx, PostgreSQL, PM2) is not running:**

```bash
# Check service status
sudo systemctl status <service-name>

# Check service logs
sudo journalctl -u <service-name> -n 50

# Restart service
sudo systemctl restart <service-name>
```

---

## ✅ Final Verdict

This user-data script is:
- ✔️ Industry-standard
- ✔️ Idempotent enough
- ✔️ Safe for fresh EC2
- ✔️ Ready for CI/CD deployment
- ✔️ Well-logged & debuggable

---

## Quick Verification Command

Run all basic checks at once:

```bash
echo "=== User-Data Log ===" && sudo tail -20 /var/log/user-data.log && \
echo -e "\n=== Node.js ===" && node -v && npm -v && \
echo -e "\n=== PM2 ===" && pm2 -v && systemctl is-active pm2-ubuntu && \
echo -e "\n=== PostgreSQL ===" && systemctl is-active postgresql && \
echo -e "\n=== Nginx ===" && nginx -t && systemctl is-active nginx && \
echo -e "\n=== Firewall ===" && sudo ufw status | head -5 && \
echo -e "\n=== Directories ===" && ls -ld /var/www/app /var/www/html/maintenance.html
```


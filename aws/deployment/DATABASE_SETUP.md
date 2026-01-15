# PostgreSQL Setup and Verification Guide

This guide will help you set up and verify PostgreSQL on your EC2 instance.

## Quick Start

### 1. Run the Setup Script

SSH into your EC2 instance and run:

```bash
# Make script executable
chmod +x scripts/setup-postgres.sh

# Run the setup script
sudo bash scripts/setup-postgres.sh
```

This script will:
- Install PostgreSQL (if not already installed)
- Create the database (`appdb`) and user (`appuser`)
- Configure PostgreSQL to accept connections
- Test the connection
- Display the connection string

### 2. Verify Database Connection

After setup, verify the connection:

```bash
# Make script executable
chmod +x scripts/verify-database.sh

# Run verification (from app directory)
cd /var/www/checkpoint
sudo bash scripts/verify-database.sh
```

### 3. Configure Environment Variables

Add the database connection string to your `.env` file:

```bash
cd /var/www/checkpoint
nano .env
```

Add or update:
```env
POSTGRES_DATABASE_URL=postgresql://appuser:StrongPassword123!@localhost:5432/appdb
```

**⚠️ Important:** Change `StrongPassword123!` to a strong password in production!

### 4. Run Prisma Migrations

After setting up the database, run migrations:

```bash
cd /var/www/checkpoint
npx prisma migrate deploy
```

This will create all the necessary tables in your database.

### 5. Verify from Application

Test the database connection from your application:

```bash
# Check database health endpoint
curl http://localhost:8000/api/monitoring/database
```

Or visit in browser:
- `http://your-server-ip/api/monitoring/database`

## Manual Setup (Alternative)

If you prefer to set up PostgreSQL manually:

### 1. Install PostgreSQL

```bash
sudo apt-get update
sudo apt-get install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql
```

### 2. Create Database and User

```bash
sudo -u postgres psql
```

Then in the PostgreSQL prompt:

```sql
CREATE DATABASE appdb;
CREATE USER appuser WITH ENCRYPTED PASSWORD 'YourStrongPasswordHere';
GRANT ALL PRIVILEGES ON DATABASE appdb TO appuser;
ALTER DATABASE appdb OWNER TO appuser;
\c appdb
GRANT ALL ON SCHEMA public TO appuser;
ALTER SCHEMA public OWNER TO appuser;
\q
```

### 3. Configure PostgreSQL

Edit PostgreSQL configuration:

```bash
# Find PostgreSQL version
psql --version

# Edit postgresql.conf (replace X.X with your version)
sudo nano /etc/postgresql/X.X/main/postgresql.conf
```

Ensure this line exists:
```
listen_addresses = 'localhost'
```

Edit authentication:

```bash
sudo nano /etc/postgresql/X.X/main/pg_hba.conf
```

Add these lines:
```
host    appdb    appuser    127.0.0.1/32    md5
host    appdb    appuser    ::1/128         md5
```

Restart PostgreSQL:

```bash
sudo systemctl restart postgresql
```

### 4. Test Connection

```bash
export PGPASSWORD='YourStrongPasswordHere'
psql -h localhost -U appuser -d appdb -c "SELECT version();"
unset PGPASSWORD
```

## Verification Endpoints

Your application provides several endpoints to verify database health:

### 1. Database Health Check

```bash
curl http://localhost:8000/api/monitoring/database
```

Response example:
```json
{
  "status": "ok",
  "latency": "5ms",
  "database": {
    "connected": true,
    "version": "PostgreSQL 16.0",
    "tables": 15,
    "migrationsApplied": true
  }
}
```

### 2. General Health Check

```bash
curl http://localhost:8000/api/monitoring/health
```

### 3. Readiness Check

```bash
curl http://localhost:8000/api/monitoring/readiness
```

## Troubleshooting

### Connection Refused

If you get "connection refused":

1. Check if PostgreSQL is running:
   ```bash
   sudo systemctl status postgresql
   ```

2. Check PostgreSQL logs:
   ```bash
   sudo tail -f /var/log/postgresql/postgresql-*-main.log
   ```

3. Verify PostgreSQL is listening:
   ```bash
   sudo netstat -tlnp | grep 5432
   ```

### Authentication Failed

If authentication fails:

1. Check `pg_hba.conf` configuration
2. Verify user exists:
   ```bash
   sudo -u postgres psql -c "\du"
   ```

3. Reset user password:
   ```bash
   sudo -u postgres psql -c "ALTER USER appuser WITH PASSWORD 'NewPassword';"
   ```

### Permission Denied

If you get permission errors:

1. Grant proper permissions:
   ```bash
   sudo -u postgres psql -d appdb -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO appuser;"
   sudo -u postgres psql -d appdb -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO appuser;"
   ```

2. Set default privileges:
   ```bash
   sudo -u postgres psql -d appdb -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO appuser;"
   ```

### Migrations Not Running

If migrations fail:

1. Check Prisma connection:
   ```bash
   cd /var/www/checkpoint
   npx prisma db pull
   ```

2. Check migration status:
   ```bash
   npx prisma migrate status
   ```

3. Force reset (⚠️ WARNING: This will delete all data):
   ```bash
   npx prisma migrate reset
   ```

## Security Best Practices

1. **Change Default Password**: Always change `StrongPassword123!` to a strong, unique password
2. **Use Environment Variables**: Never hardcode passwords in scripts
3. **Limit Access**: Only allow connections from localhost (already configured)
4. **Regular Backups**: Set up automated database backups
5. **Monitor Logs**: Regularly check PostgreSQL logs for suspicious activity

## Connection String Format

The connection string format is:
```
postgresql://[user]:[password]@[host]:[port]/[database]
```

Example:
```
postgresql://appuser:StrongPassword123!@localhost:5432/appdb
```

## Next Steps

After setting up PostgreSQL:

1. ✅ Run Prisma migrations: `npx prisma migrate deploy`
2. ✅ Verify connection: `curl http://localhost:8000/api/monitoring/database`
3. ✅ Check application logs: `pm2 logs checkpoint`
4. ✅ Monitor database: Use the health check endpoints regularly

## Support

If you encounter issues:

1. Check application logs: `pm2 logs checkpoint`
2. Check PostgreSQL logs: `/var/log/postgresql/`
3. Verify environment variables: `cat /var/www/checkpoint/.env | grep DATABASE`
4. Test connection manually: Use the verification script

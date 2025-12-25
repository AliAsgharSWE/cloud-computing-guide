name: Deploy PayMate API to EC2

on:
  push:
    branches: [main]
  workflow_dispatch: # manual trigger

jobs:
  build:
    name: Build Application
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20.13.1"
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Generate Prisma Client
        run: npm run generate

      - name: Build TypeScript
        run: npm run build

      - name: Create deployment package (without node_modules)
        run: |
          mkdir -p deploy
          cp -r dist deploy/
          cp -r prisma deploy/
          cp package*.json deploy/
          cp ecosystem.config.cjs deploy/
          # Copy .env.example if exists
          [ -f .env.example ] && cp .env.example deploy/ || echo "No .env.example found"
          tar -czf deploy.tar.gz -C deploy .

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: deployment-package
          path: deploy.tar.gz
          retention-days: 1

  deploy:
    name: Deploy to EC2
    needs: build
    runs-on: ubuntu-latest

    steps:
      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: deployment-package

      - name: Deploy to EC2 via SSH
        env:
          EC2_HOST: ${{ secrets.EC2_HOST }}
          EC2_USERNAME: ${{ secrets.EC2_USERNAME }}
          SSH_PRIVATE_KEY: ${{ secrets.EC2_SSH_KEY }}
          # Server Configuration
          NODE_ENV: production
          PORT: ${{ secrets.PORT }}
          SERVER_URL: ${{ secrets.SERVER_URL }}
          FRONTEND_URL: ${{ secrets.FRONTEND_URL }}
          # Database
          POSTGRES_DATABASE_URL: ${{ secrets.POSTGRES_DATABASE_URL }}
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
          # JWT Configuration
          JWT_SECRET: ${{ secrets.JWT_SECRET }}
          REFRESH_TOKEN_SECRET: ${{ secrets.REFRESH_TOKEN_SECRET }}
          JWT_EXPIRY: ${{ secrets.JWT_EXPIRY }}
          REFRESH_TOKEN_EXPIRY: ${{ secrets.REFRESH_TOKEN_EXPIRY }}
          # Email Configuration
          SMTP_HOST: ${{ secrets.SMTP_HOST }}
          SMTP_PORT: ${{ secrets.SMTP_PORT }}
          SMTP_USER: ${{ secrets.SMTP_USER }}
          SMTP_PASSWORD: ${{ secrets.SMTP_PASSWORD }}
          SMTP_FROM: ${{ secrets.SMTP_FROM }}
          # Application
          APP_NAME: ${{ secrets.APP_NAME }}
          PROMETHEUS_URL: ${{ secrets.PROMETHEUS_URL }}
          GOOGLE_CLIENT_ID: ${{ secrets.GOOGLE_CLIENT_ID }}
        run: |
          # Create SSH key file
          echo "$SSH_PRIVATE_KEY" > private_key.pem
          chmod 600 private_key.pem

          # Copy deployment package to EC2
          scp -i private_key.pem -o StrictHostKeyChecking=no \
            deploy.tar.gz ${EC2_USERNAME}@${EC2_HOST}:/tmp/

          # Set defaults in bash (GitHub Actions doesn't support || in YAML)
          PORT="${PORT:-4300}"
          JWT_EXPIRY="${JWT_EXPIRY:-15m}"
          REFRESH_TOKEN_EXPIRY="${REFRESH_TOKEN_EXPIRY:-7d}"
          SMTP_PORT="${SMTP_PORT:-587}"
          APP_NAME="${APP_NAME:-PayMate}"
          PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"

          # Create .env file content
          # Use DATABASE_URL if provided, otherwise use POSTGRES_DATABASE_URL
          DB_URL="${DATABASE_URL:-${POSTGRES_DATABASE_URL}}"
          
          {
            echo "# Server Configuration"
            echo "NODE_ENV=${NODE_ENV}"
            echo "PORT=${PORT}"
            echo "SERVER_URL=${SERVER_URL}"
            echo "FRONTEND_URL=${FRONTEND_URL}"
            echo ""
            echo "# Database"
            echo "POSTGRES_DATABASE_URL=${POSTGRES_DATABASE_URL}"
            echo "DATABASE_URL=${DB_URL}"
            echo ""
            echo "# JWT Configuration"
            echo "JWT_SECRET=${JWT_SECRET}"
            echo "REFRESH_TOKEN_SECRET=${REFRESH_TOKEN_SECRET}"
            echo "JWT_EXPIRY=${JWT_EXPIRY}"
            echo "REFRESH_TOKEN_EXPIRY=${REFRESH_TOKEN_EXPIRY}"
            echo ""
            echo "# Email Configuration"
            echo "SMTP_HOST=${SMTP_HOST}"
            echo "SMTP_PORT=${SMTP_PORT}"
            echo "SMTP_USER=${SMTP_USER}"
            echo "SMTP_PASSWORD=${SMTP_PASSWORD}"
            echo "SMTP_FROM=${SMTP_FROM}"
            echo ""
            echo "# Application"
            echo "APP_NAME=${APP_NAME}"
            echo "PROMETHEUS_URL=${PROMETHEUS_URL}"
            [ -n "${GOOGLE_CLIENT_ID}" ] && echo "GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}"
          } > .env.tmp

          # Validate .env file - fail fast if critical vars are missing
          echo "Validating .env file..."
          if ! grep -q "^DATABASE_URL=" .env.tmp && ! grep -q "^POSTGRES_DATABASE_URL=" .env.tmp; then
            echo "❌ CRITICAL: .env missing DATABASE_URL or POSTGRES_DATABASE_URL"
            exit 1
          fi
          if ! grep -q "^JWT_SECRET=" .env.tmp; then
            echo "❌ CRITICAL: .env missing JWT_SECRET"
            exit 1
          fi
          if ! grep -q "^REFRESH_TOKEN_SECRET=" .env.tmp; then
            echo "❌ CRITICAL: .env missing REFRESH_TOKEN_SECRET"
            exit 1
          fi
          if ! grep -q "^SMTP_HOST=" .env.tmp; then
            echo "❌ CRITICAL: .env missing SMTP_HOST (required for production)"
            exit 1
          fi
          echo "✅ .env validation passed"

          # Copy .env file to EC2
          scp -i private_key.pem -o StrictHostKeyChecking=no \
            .env.tmp ${EC2_USERNAME}@${EC2_HOST}:/tmp/.env.new

          # SSH into EC2 and deploy
          ssh -i private_key.pem -o StrictHostKeyChecking=no \
            ${EC2_USERNAME}@${EC2_HOST} << 'EOF'
            
            # Navigate to app directory
            cd /var/www/app-name

            # Fix ownership first (important!)
            echo "Fixing directory ownership..."
            sudo chown -R ubuntu:ubuntu /var/www/app-name
            
            
            # Backup current version
            if [ -d "dist" ]; then
              timestamp=$(date +%Y%m%d_%H%M%S)
              mkdir -p backups
              tar -czf backups/backup_${timestamp}.tar.gz dist prisma package.json ecosystem.config.cjs .env 2>/dev/null || true
              # Keep only last 5 backups
              ls -t backups/backup_*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm
            fi
            
            # Extract new version (this will overwrite existing files)
            echo "Extracting new deployment package..."
            tar --overwrite -xzf /tmp/deploy.tar.gz -C /var/www/app-name
            rm /tmp/deploy.tar.gz

            # Fix ownership after extraction
            sudo chown -R ubuntu:ubuntu /var/www/app-name
            
            # Move .env file to app directory
            echo "Updating .env file..."
            mv /tmp/.env.new .env
            chmod 600 .env
            
            # Install dependencies (needed for Prisma generate)
            echo ""
            echo "Installing dependencies..."
            npm ci
            
            # Generate Prisma Client
            echo "Generating Prisma Client..."
            npm run generate
            
            # Remove dev dependencies (production optimization)
            echo "Removing dev dependencies..."
            npm prune --production
            
            # Run database migrations (production-safe command)
            echo "Running database migrations..."
            npx prisma migrate deploy
            
            # Create logs and uploads directories
            mkdir -p logs uploads
            
            # Zero-downtime reload with PM2 (NO sudo - runs as current user)
            if pm2 describe app-name > /dev/null 2>&1; then
              echo "Reloading PM2 app (zero-downtime)..."
              pm2 reload ecosystem.config.cjs --update-env
            else
              echo "Starting new PM2 process..."
              pm2 start ecosystem.config.cjs
            fi
            
            # Save PM2 process list (NO sudo)
            pm2 save
           
          EOF

          # Cleanup
          rm -f .env.tmp private_key.pem

      - name: Verify deployment
        env:
          EC2_HOST: ${{ secrets.EC2_HOST }}
          EC2_USERNAME: ${{ secrets.EC2_USERNAME }}
          SSH_PRIVATE_KEY: ${{ secrets.EC2_SSH_KEY }}
          PORT: ${{ secrets.PORT }}
        run: |
          echo "Waiting for application to start...."
          sleep 10

          # Set default port
          PORT="${PORT:-4300}"

          # Create SSH key file for health check
          echo "$SSH_PRIVATE_KEY" > private_key.pem
          chmod 600 private_key.pem

          # Check health endpoint directly on the server (verifies Node app, not nginx)
          for i in {1..3}; do
            echo "Attempt $i of 3..."
            response=$(ssh -i private_key.pem -o StrictHostKeyChecking=no \
              ${EC2_USERNAME}@${EC2_HOST} \
              "curl -s -o /dev/null -w '%{http_code}' http://localhost:${PORT}/health 2>/dev/null || echo '000'")
            
            if [ "$response" = "200" ]; then
              echo "✅ Deployment successful! Health check passed with status: $response"
              rm -f private_key.pem
              exit 0
            fi
            
            echo "Got response: $response, waiting 5 seconds..."
            sleep 5
          done

          echo "❌ Deployment verification failed after 3 attempts"
          echo "Please check PM2 logs on the server: pm2 logs app-name"
          rm -f private_key.pem
          exit 1

      - name: Rollback on failure
        if: failure()
        env:
          EC2_HOST: ${{ secrets.EC2_HOST }}
          EC2_USERNAME: ${{ secrets.EC2_USERNAME }}
          SSH_PRIVATE_KEY: ${{ secrets.EC2_SSH_KEY }}
        run: |
          echo "🔄 Attempting to rollback to previous version..."

          echo "$SSH_PRIVATE_KEY" > private_key.pem
          chmod 600 private_key.pem

          ssh -i private_key.pem -o StrictHostKeyChecking=no \
            ${EC2_USERNAME}@${EC2_HOST} << 'EOF'
            
            cd /var/www/app-name

            # Fix ownership first (important!)
            sudo chown -R ubuntu:ubuntu /var/www/app-name
            
            # Find latest backup
            latest_backup=$(ls -t backups/backup_*.tar.gz 2>/dev/null | head -1)
            
            if [ -n "$latest_backup" ]; then
              echo "Found backup: $latest_backup"
              tar -xzf "$latest_backup" -C /var/www/app-name
              npm ci
              npm run generate
              npm prune --production

              pm2 reload ecosystem.config.cjs || pm2 start ecosystem.config.cjs
              pm2 save
              echo "✅ Rolled back to previous version"
            else
              echo "⚠️ No backup found, cannot rollback"
            fi
          EOF

          rm private_key.pem

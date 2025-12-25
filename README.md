# Cloud Computing Guide (AWS · GCP · Azure)

Production-ready cloud computing guides focused on **real deployments**, **security**, and **automation**.

## What this repo is
- Practical cloud guides used in real projects
- Step-by-step deployment instructions
- CI/CD, security, monitoring, and scaling
- Ready-to-use scripts and workflows

## What this repo is NOT
- Certification dumps
- Copy-paste vendor docs
- Theory-only explanations

## Cloud Providers Covered
- **AWS** (EC2, VPC, RDS, Nginx, PM2, CI/CD) ⭐ Currently available
- Google Cloud Platform (Compute Engine, Cloud Run) - Coming soon
- Microsoft Azure (VMs, App Service) - Coming soon

## Project Structure

```
aws/
└── deployment/
    ├── CI-CD/
    │   ├── github-actions-workflow.yml         # GitHub Actions workflow for automated deployments
    │   ├── CI-CD-Pipeline.md                   # Workflow documentation and reference
    │   └── Step by Step Guide to implement CI-CD Deployment.md  # Complete deployment guide
    │
    └── userdata/
        ├── ec2-bootstrap-basic.sh              # Basic EC2 initialization script
        ├── ec2-bootstrap-without-domain.sh     # EC2 setup without domain (uses public IP)
        └── ec2-bootstrap-with-domain-production.sh  # Production-ready setup with domain & SSL
```

## AWS Deployment Guide

### Quick Start

1. **EC2 Instance Setup**
   - Choose a user-data script based on your needs:
     - **Basic**: `ec2-bootstrap-basic.sh` - Minimal setup
     - **No Domain**: `ec2-bootstrap-without-domain.sh` - Uses public IP
     - **Production**: `ec2-bootstrap-with-domain-production.sh` - Includes domain and SSL setup

2. **CI/CD Pipeline Setup**
   - Follow the [Step-by-Step CI/CD Deployment Guide](aws/deployment/CI-CD/Step%20by%20Step%20Guide%20to%20implement%20CI-CD%20Deployment.md)
   - Use the [GitHub Actions Workflow](aws/deployment/CI-CD/github-actions-workflow.yml) as a template
   - Reference the [Workflow Documentation](aws/deployment/CI-CD/CI-CD-Pipeline.md) for details

### Features

**EC2 Bootstrap Scripts:**
- ✅ Automated Node.js LTS installation
- ✅ PM2 process manager setup
- ✅ Nginx reverse proxy configuration
- ✅ Maintenance page fallback
- ✅ SSL/HTTPS support (production script)
- ✅ Production-ready directory structure

**CI/CD Pipeline:**
- ✅ Zero-downtime deployments
- ✅ Automated builds and tests
- ✅ Secure environment variable injection
- ✅ Automated rollback on failure
- ✅ Health check verification
- ✅ PM2 process management

### What's Included

**User-Data Scripts:**
- Pre-configured EC2 initialization scripts
- Node.js, PM2, and Nginx installation
- Proper directory structure (`/var/www/app-name`)
- Nginx configuration with proxy settings
- Maintenance page fallback for graceful degradation

**CI/CD Pipeline:**
- Complete GitHub Actions workflow
- Build and deployment automation
- Secure secret management
- Database migration support (Prisma)
- Backup and rollback capabilities
- Production-ready deployment strategy

## Who this is for
- Backend & Full-stack developers
- DevOps engineers
- Startup founders deploying production apps
- Engineers seeking production-grade deployment solutions

## Getting Started

1. **For EC2 Setup**: Copy the appropriate user-data script to your EC2 instance configuration
2. **For CI/CD**: Follow the step-by-step guide in `aws/deployment/CI-CD/`
3. **Customize**: Adapt scripts and workflows to your specific application needs

## Status
🚧 Actively maintained and expanded

## License
MIT

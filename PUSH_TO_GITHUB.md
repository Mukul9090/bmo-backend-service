# Push to GitHub - Step by Step Guide

## Prerequisites
- GitHub account
- GitHub repository created (or we'll create one)
- Git configured on your machine

## Step 1: Create GitHub Repository (if not exists)

1. Go to https://github.com/new
2. Repository name: `BMO` (or your preferred name)
3. Description: "Backend Service with Hot/Standby Failover"
4. Choose Public or Private
5. **DO NOT** initialize with README, .gitignore, or license (we already have files)
6. Click "Create repository"

## Step 2: Add All Files and Commit

Run these commands in your terminal:

```bash
cd "/Users/mukul/Desktop/untitled folder/BMO"

# Add all files
git add .

# Check what will be committed
git status

# Commit with a message
git commit -m "Initial commit: Backend service with hot/standby failover and CI/CD pipeline"
```

## Step 3: Connect to GitHub and Push

Replace `YOUR_USERNAME` with your GitHub username:

```bash
# Add remote repository (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/BMO.git

# Or if using SSH:
# git remote add origin git@github.com:YOUR_USERNAME/BMO.git

# Rename branch to main (if needed)
git branch -M main

# Push to GitHub
git push -u origin main
```

## Step 4: Set Up GitHub Secrets (Required for CI/CD)

After pushing, go to your repository on GitHub:

1. Click **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add these secrets:

   **Secret 1:**
   - Name: `DOCKER_USERNAME`
   - Value: Your Docker Hub username (e.g., `mukul1599`)

   **Secret 2:**
   - Name: `DOCKER_PASSWORD`
   - Value: Your Docker Hub password or access token

## Step 5: Verify CI/CD Pipeline

1. Go to **Actions** tab in your GitHub repository
2. You should see the workflow file
3. The pipeline will run automatically on next push to main branch

## Quick Command Summary

```bash
cd "/Users/mukul/Desktop/untitled folder/BMO"
git add .
git commit -m "Initial commit: Backend service with hot/standby failover and CI/CD pipeline"
git remote add origin https://github.com/YOUR_USERNAME/BMO.git
git branch -M main
git push -u origin main
```

## Troubleshooting

### If you get authentication error:
```bash
# Use GitHub Personal Access Token instead of password
# Or set up SSH keys: https://docs.github.com/en/authentication/connecting-to-github-with-ssh
```

### If repository already exists:
```bash
# Remove existing remote (if any)
git remote remove origin

# Add your repository
git remote add origin https://github.com/YOUR_USERNAME/BMO.git
git push -u origin main
```

### If you need to update later:
```bash
git add .
git commit -m "Your commit message"
git push
```


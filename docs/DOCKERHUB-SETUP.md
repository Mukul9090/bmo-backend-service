# Docker Hub Setup Guide

This guide explains how to set up Docker Hub integration for GitHub Actions.

## Step 1: Create Docker Hub Account (if needed)

1. Go to https://hub.docker.com/
2. Sign up or log in with your account

## Step 2: Create Docker Hub Access Token

1. Log in to Docker Hub
2. Go to: **Account Settings** → **Security** → **New Access Token**
3. Give it a name: `github-actions` (or any name you prefer)
4. Set permissions: **Read & Write** (or **Read, Write & Delete**)
5. Click **Generate**
6. **Copy the token immediately** - you won't be able to see it again!

## Step 3: Create Repository on Docker Hub

1. Go to: https://hub.docker.com/repositories
2. Click **Create Repository**
3. Repository name: `bmo-backend-service`
4. Visibility: **Public** (or Private if you prefer)
5. Click **Create**

Your image will be available at: `mukul9090/bmo-backend-service`

## Step 4: Add Token to GitHub Secrets

1. Go to your GitHub repository: https://github.com/Mukul9090/bmo-backend-service
2. Navigate to: **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `DOCKERHUB_TOKEN`
5. Value: (paste your Docker Hub access token)
6. Click **Add secret**

## Step 5: Verify Setup

After pushing to GitHub, the CD workflow will:
1. Build the Docker image
2. Push to Docker Hub: `mukul9090/bmo-backend-service:latest`
3. Push to GitHub Container Registry: `ghcr.io/Mukul9090/bmo-backend-service:latest`

## Using the Image

Once pushed, you can pull and use the image:

```bash
# Pull from Docker Hub
docker pull mukul9090/bmo-backend-service:latest

# Run locally
docker run -p 8080:8080 -e CLUSTER_ROLE=hot mukul9090/bmo-backend-service:latest

# Use in Kubernetes
# Update k8s/deployment.yaml to use:
# image: mukul9090/bmo-backend-service:latest
```

## Image Tags

The workflow automatically creates these tags:
- `latest` - Latest build from main branch
- `main` - Latest build from main branch
- `main-<sha>` - Specific commit SHA
- `v1.0.0` - Version tags (when creating releases)

## Troubleshooting

### Error: "unauthorized: authentication required"
- Check that `DOCKERHUB_TOKEN` secret is set correctly
- Verify the token has write permissions
- Make sure the repository name matches: `bmo-backend-service`

### Error: "repository does not exist"
- Create the repository on Docker Hub first
- Verify the repository name matches in the workflow

### Image not appearing on Docker Hub
- Check GitHub Actions logs for errors
- Verify the workflow completed successfully
- Wait a few minutes for Docker Hub to update


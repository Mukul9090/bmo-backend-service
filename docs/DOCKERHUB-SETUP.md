# Docker Hub Setup Guide

Guide for setting up Docker Hub integration with GitHub Actions.

## Step 1: Create Docker Hub Account

1. Go to https://hub.docker.com/
2. Sign up or log in

## Step 2: Create Access Token

1. Log in to Docker Hub
2. Navigate to **Account Settings** → **Security** → **New Access Token**
3. Name: `github-actions`
4. Permissions: **Read & Write**
5. Click **Generate**
6. **Copy the token immediately** - it won't be shown again

## Step 3: Create Repository

1. Go to https://hub.docker.com/repositories
2. Click **Create Repository**
3. Repository name: `backend-service` (or your preferred name)
4. Visibility: **Public** or **Private**
5. Click **Create**

## Step 4: Add Token to GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add secrets:
   - Name: `DOCKER_USERNAME` - Your Docker Hub username
   - Name: `DOCKER_PASSWORD` - Your Docker Hub access token

## Step 5: Update Workflow

Ensure your GitHub Actions workflow uses these secrets:

```yaml
- name: Login to Docker Hub
  uses: docker/login-action@v2
  with:
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_PASSWORD }}
```

## Using the Image

Once pushed, pull and use the image:

```bash
# Pull image
docker pull <username>/backend-service:latest

# Run locally
docker run -p 8080:8080 -e CLUSTER_ROLE=hot <username>/backend-service:latest
```

## Troubleshooting

### "unauthorized: authentication required"
- Verify `DOCKER_USERNAME` and `DOCKER_PASSWORD` secrets are set correctly
- Ensure token has write permissions
- Check repository name matches in workflow

### "repository does not exist"
- Create the repository on Docker Hub first
- Verify repository name matches in workflow

### Image not appearing
- Check GitHub Actions logs for errors
- Wait a few minutes for Docker Hub to update
- Verify workflow completed successfully

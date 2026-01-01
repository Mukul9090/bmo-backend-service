# GitHub Actions Workflows

This directory contains CI/CD workflows for the backend service.

## Workflows

### 1. CI (`ci.yml`)
Runs on every push and pull request to `main` or `develop` branches.

**Jobs:**
- **Test**: Runs Python tests and validates application startup
- **Build**: Builds Docker image and tests it
- **Lint**: Runs code linting and validates Kubernetes manifests

### 2. CD (`cd.yml`)
Runs on pushes to `main` branch.

**Jobs:**
- **Build and Push**: Builds Docker image and pushes to GitHub Container Registry
- **Deploy**: Deploys to Kubernetes (requires cluster configuration)

**Required Secrets:**
- `DOCKERHUB_TOKEN`: Docker Hub access token (required for pushing to Docker Hub)
- `KUBECONFIG`: Base64-encoded kubeconfig file (optional, for deployment)

**Docker Hub Setup:**
1. Go to Docker Hub: https://hub.docker.com/settings/security
2. Create an access token
3. Add as GitHub Secret:
   - Go to: Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `DOCKERHUB_TOKEN`
   - Value: (paste your Docker Hub access token)

### 3. Release (`release.yml`)
Runs when a new GitHub release is created.

**Jobs:**
- **Build and Push**: Builds and pushes release image with version tag

## Setup Instructions

### 1. Enable GitHub Actions
Workflows are automatically enabled when pushed to GitHub.

### 2. Configure Kubernetes Deployment (Optional)

If you want automatic deployment to Kubernetes:

1. Get your kubeconfig:
   ```bash
   cat ~/.kube/config | base64
   ```

2. Add as GitHub Secret:
   - Go to: Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `KUBECONFIG`
   - Value: (paste base64-encoded kubeconfig)

### 3. View Workflow Runs
- Go to: Actions tab in your GitHub repository
- View workflow runs and logs

## Image Registry

Images are pushed to both Docker Hub and GitHub Container Registry:

**Docker Hub:**
- Format: `mukul9090/bmo-backend-service:tag`
- Publicly accessible at: https://hub.docker.com/r/mukul9090/bmo-backend-service
- Tags: `main`, `latest`, `main-<sha>`, version tags

**GitHub Container Registry:**
- Format: `ghcr.io/Mukul9090/bmo-backend-service:tag`
- Tags: `main`, `latest`, `main-<sha>`, version tags

## Manual Workflow Triggers

You can also trigger workflows manually:
- Go to Actions tab
- Select workflow
- Click "Run workflow"

## Workflow Status Badge

Add to your README.md:
```markdown
![CI](https://github.com/YOUR_USERNAME/YOUR_REPO/workflows/CI/badge.svg)
```


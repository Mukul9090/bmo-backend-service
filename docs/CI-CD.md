# CI/CD Pipeline Documentation

## Overview

This repository includes a complete CI/CD pipeline using GitHub Actions that automatically builds, tests, and deploys the backend service to Kubernetes with hot/standby failover configuration.

## Pipeline Architecture

```
┌─────────────────┐
│  Code Push/PR   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Build & Push    │
│ Docker Image    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Deploy to K8s   │
│ - Hot Cluster   │
│ - Standby       │
│ - HAProxy       │
└─────────────────┘
```

## Workflow Triggers

The pipeline runs automatically on:
- **Push to main/master branch** - Full build and deployment
- **Pull Requests** - Build only (no deployment)
- **Manual trigger** - Via GitHub Actions UI (workflow_dispatch)

## Required GitHub Secrets

Configure these secrets in your GitHub repository settings:

### Docker Hub Credentials
- `DOCKER_USERNAME` - Your Docker Hub username (e.g., `mukul1599`)
- `DOCKER_PASSWORD` - Your Docker Hub access token or password

### How to Set Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret:
   - Name: `DOCKER_USERNAME`
   - Value: Your Docker Hub username
   - Name: `DOCKER_PASSWORD`
   - Value: Your Docker Hub password or access token

## Runner Requirements

The pipeline uses a self-hosted runner named **BMO-platform** (macOS ARM64).

### Prerequisites on Runner

1. **Docker** - For building images
2. **kubectl** - For Kubernetes deployments
3. **Kubernetes cluster access** - kubectl must be configured with cluster access
4. **GitHub Actions Runner** - Must be registered and running

### Verify Runner Setup

```bash
# Check Docker
docker --version

# Check kubectl
kubectl version --client
kubectl config current-context

# Check runner status
# Should show "BMO-platform" as available
```

## Pipeline Jobs

### 1. Build and Push

**Job:** `build-and-push`
- Builds Docker image for multiple platforms (linux/amd64, linux/arm64)
- Pushes to Docker Hub
- Uses build cache for faster builds
- Tags images with branch name and `latest` for main branch

### 2. Deploy

**Job:** `deploy`
- Creates Kubernetes namespaces (backend-hot, backend-standby)
- Deploys ConfigMaps with cluster roles
- Deploys Hot and Standby clusters
- Deploys HAProxy load balancer
- Waits for all resources to be ready
- Verifies deployment health

## Deployment Process

1. **Namespaces**: Creates `backend-hot` and `backend-standby` namespaces
2. **ConfigMaps**: Sets `CLUSTER_ROLE=hot` and `CLUSTER_ROLE=standby`
3. **Hot Cluster**: Deploys 3 replicas in `backend-hot` namespace
4. **Standby Cluster**: Deploys 3 replicas in `backend-standby` namespace
5. **Services**: Creates NodePort services (30080 for hot, 30081 for standby)
6. **HAProxy**: Deploys load balancer with automatic failover

## Verification

The pipeline automatically verifies:
- ✅ All pods are running
- ✅ Services are created
- ✅ Health endpoints respond correctly
- ✅ HAProxy is routing traffic

## Manual Deployment

You can also deploy manually using the provided scripts:

```bash
# Deploy all resources
kubectl apply -f k8s/

# Or use the deployment script
./deploy-minikube.sh
```

## Troubleshooting

### Build Fails

- Check Docker Hub credentials in secrets
- Verify runner has Docker installed
- Check Docker Hub rate limits

### Deployment Fails

- Verify kubectl is configured: `kubectl config current-context`
- Check cluster connectivity: `kubectl get nodes`
- Verify namespaces can be created
- Check resource quotas

### Health Checks Fail

- Verify pods are running: `kubectl get pods -A`
- Check pod logs: `kubectl logs <pod-name> -n <namespace>`
- Verify services: `kubectl get svc -A`

## Monitoring

After deployment, monitor your clusters:

```bash
# Check all resources
kubectl get all -n backend-hot
kubectl get all -n backend-standby
kubectl get all -l app=haproxy

# View logs
kubectl logs -l app=backend-service -n backend-hot --tail=50
kubectl logs -l app=haproxy --tail=50
```

## Rollback

To rollback a deployment:

```bash
# Rollback to previous deployment
kubectl rollout undo deployment/backend-service -n backend-hot
kubectl rollout undo deployment/backend-service -n backend-standby

# Or scale down
kubectl scale deployment backend-service --replicas=0 -n backend-hot
```

## Environment Variables

The pipeline uses these environment variables (can be customized in workflow):

- `DOCKER_IMAGE`: `mukul1599/backend-service`
- `DOCKER_TAG`: `latest`
- `K8S_NAMESPACE_HOT`: `backend-hot`
- `K8S_NAMESPACE_STANDBY`: `backend-standby`

## Next Steps

1. Set up GitHub secrets (Docker Hub credentials)
2. Ensure runner is online and configured
3. Push to main branch to trigger deployment
4. Monitor the Actions tab for deployment status


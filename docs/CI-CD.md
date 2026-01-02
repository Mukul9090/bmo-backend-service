# CI/CD Pipeline Documentation

Complete CI/CD pipeline using GitHub Actions for automated build, test, and deployment.

## Overview

The pipeline automatically:
- Runs tests on every push/PR
- Builds Docker images
- Pushes to Docker Hub
- Deploys to Kubernetes with hot/standby clusters and HAProxy

## Pipeline Architecture

```
Code Push/PR → Build & Test → Build Docker Image → Push to Registry → Deploy to K8s
```

## Workflow Triggers

- **Push to main/master** - Full build and deployment
- **Pull Requests** - Build and test only (no deployment)
- **Manual trigger** - Via GitHub Actions UI

## Required Secrets

Configure in **Settings** → **Secrets and variables** → **Actions**:

- `DOCKER_USERNAME` - Docker Hub username
- `DOCKER_PASSWORD` - Docker Hub access token

## Pipeline Jobs

### 1. Build and Push

- Runs tests
- Builds multi-platform Docker image (linux/amd64, linux/arm64)
- Pushes to Docker Hub
- Tags with branch name and `latest` for main branch

### 2. Deploy

- Creates namespaces (`backend-hot`, `backend-standby`)
- Deploys ConfigMaps with cluster roles
- Deploys Hot and Standby clusters (3 replicas each)
- Deploys HAProxy load balancer
- Waits for all resources to be ready
- Verifies deployment health

## Deployment Details

1. **Namespaces**: `backend-hot` and `backend-standby`
2. **ConfigMaps**: Sets `CLUSTER_ROLE=hot` and `CLUSTER_ROLE=standby`
3. **Hot Cluster**: 3 replicas in `backend-hot` namespace
4. **Standby Cluster**: 3 replicas in `backend-standby` namespace
5. **Services**: NodePort services (30080 for hot, 30081 for standby)
6. **HAProxy**: Load balancer with automatic failover

## Verification

Pipeline automatically verifies:
- ✅ All pods are running
- ✅ Services are created
- ✅ Health endpoints respond correctly
- ✅ HAProxy is routing traffic

## Manual Deployment

```bash
# Deploy all resources
kubectl apply -f k8s/
```

## Troubleshooting

### Build Fails
- Check Docker Hub credentials in secrets
- Verify runner has Docker installed
- Check Docker Hub rate limits

### Deployment Fails
- Verify kubectl is configured: `kubectl config current-context`
- Check cluster connectivity
- Verify namespaces can be created

### Health Checks Fail
- Verify pods are running: `kubectl get pods -A`
- Check pod logs: `kubectl logs <pod-name> -n <namespace>`
- Verify services: `kubectl get svc -A`

## Monitoring

```bash
# Check all resources
kubectl get all -n backend-hot
kubectl get all -n backend-standby
kubectl get all -l app=haproxy

# View logs
kubectl logs -l app=backend-service -n backend-hot --tail=50
```

## Rollback

```bash
# Rollback deployment
kubectl rollout undo deployment/backend-service -n backend-hot
kubectl rollout undo deployment/backend-service -n backend-standby

# Scale down
kubectl scale deployment backend-service --replicas=0 -n backend-hot
```

## Environment Variables

Customizable in workflow:
- `DOCKER_IMAGE`: Docker image name
- `DOCKER_TAG`: Image tag (default: `latest`)
- `K8S_NAMESPACE_HOT`: Hot cluster namespace (default: `backend-hot`)
- `K8S_NAMESPACE_STANDBY`: Standby cluster namespace (default: `backend-standby`)

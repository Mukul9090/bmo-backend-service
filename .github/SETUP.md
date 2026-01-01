# GitHub Actions CI/CD Setup Guide

## Quick Setup Checklist

### 1. GitHub Secrets Configuration

Go to your repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these secrets:

| Secret Name | Description | Example |
|------------|-------------|---------|
| `DOCKER_USERNAME` | Docker Hub username | `mukul1599` |
| `DOCKER_PASSWORD` | Docker Hub password or access token | `dckr_pat_...` |

**Note:** For Docker Hub, you can use either:
- Your account password, OR
- An access token (recommended for security)

To create a Docker Hub access token:
1. Go to Docker Hub → Account Settings → Security
2. Click "New Access Token"
3. Copy the token and use it as `DOCKER_PASSWORD`

### 2. Verify Self-Hosted Runner

Your runner **BMO-platform** (macOS ARM64) must be:
- ✅ Online and idle
- ✅ Has Docker installed
- ✅ Has kubectl installed and configured
- ✅ Has access to your Kubernetes cluster

**Test runner setup:**
```bash
# On the runner machine
docker --version
kubectl version --client
kubectl config current-context
kubectl get nodes
```

### 3. Test the Pipeline

1. **Push to main branch** - Triggers full deployment
2. **Create a PR** - Triggers build only (no deployment)
3. **Manual trigger** - Go to Actions → Select workflow → Run workflow

### 4. Monitor Deployment

After pushing, check:
- **Actions tab** - See pipeline progress
- **Deployment Summary** - View at the end of the workflow run
- **Kubernetes cluster** - Verify resources are created

## Troubleshooting

### Pipeline doesn't start
- Check if runner is online: GitHub → Settings → Actions → Runners
- Verify workflow file is in `.github/workflows/` directory

### Build fails
- Check Docker Hub credentials
- Verify runner has Docker installed
- Check Docker Hub rate limits (free tier: 200 pulls/6 hours)

### Deployment fails
- Verify kubectl is configured: `kubectl config current-context`
- Check cluster connectivity: `kubectl get nodes`
- Verify you have permissions to create namespaces and deployments

### Health checks fail
- Check pod status: `kubectl get pods -A`
- View pod logs: `kubectl logs <pod-name> -n <namespace>`
- Verify services: `kubectl get svc -A`

## Workflow File Location

The workflow is located at:
```
.github/workflows/deploy.yml
```

## Customization

You can customize the workflow by editing `.github/workflows/deploy.yml`:

- **Docker image name**: Change `DOCKER_IMAGE` in env section
- **Kubernetes namespaces**: Change `K8S_NAMESPACE_HOT` and `K8S_NAMESPACE_STANDBY`
- **Deployment replicas**: Edit `k8s/deployment.yaml`
- **HAProxy configuration**: Edit `k8s/haproxy-configmap.yaml`

## Support

For issues or questions:
1. Check the workflow logs in GitHub Actions
2. Review the CI/CD documentation: `docs/CI-CD.md`
3. Check Kubernetes cluster logs


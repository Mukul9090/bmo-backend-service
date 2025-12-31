# Deployment Instructions

## Prerequisites
- Docker installed
- Kubernetes cluster access (kubectl configured)
- Docker registry access (optional, for image push)

## Step 1: Build Docker Image

```bash
# Build the image
docker build -t backend-service:latest .

# If using a registry, tag and push:
# docker tag backend-service:latest <registry>/backend-service:latest
# docker push <registry>/backend-service:latest
```

## Step 2: Load Image to Cluster (if using local cluster)

For local/minikube/kind clusters, load the image directly:

```bash
# For minikube
minikube image load backend-service:latest

# For kind
kind load docker-image backend-service:latest
```

## Step 3: Deploy to Kubernetes

Apply manifests in order:

```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Create ConfigMap
kubectl apply -f k8s/configmap.yaml

# Create Deployment
kubectl apply -f k8s/deployment.yaml

# Create Service
kubectl apply -f k8s/service.yaml
```

Or apply all at once:

```bash
kubectl apply -f k8s/
```

## Step 4: Verify Deployment

```bash
# Check pods
kubectl get pods -n backend

# Check service
kubectl get svc -n backend

# Check deployment status
kubectl get deployment -n backend

# View logs
kubectl logs -n backend -l app=backend-service --tail=50
```

## Step 5: Test the Service

```bash
# Port forward to access the service locally
kubectl port-forward -n backend svc/backend-service 8080:80

# In another terminal, test endpoints:
curl http://localhost:8080/healthz
curl http://localhost:8080/
```

## Updating CLUSTER_ROLE

To change the cluster role (e.g., to "standby"):

```bash
# Update ConfigMap
kubectl set data configmap/backend-config CLUSTER_ROLE=standby -n backend

# Restart pods to pick up new env var
kubectl rollout restart deployment/backend-service -n backend
```

Or edit the ConfigMap directly:

```bash
kubectl edit configmap backend-config -n backend
```


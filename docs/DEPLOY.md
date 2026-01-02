# Kubernetes Deployment Guide

General guide for deploying the backend service to any Kubernetes cluster.

## Prerequisites

- Docker installed
- Kubernetes cluster access (kubectl configured)
- Docker registry access (optional, for image push)

## Step 1: Build Docker Image

```bash
# Build the image
docker build -t backend-service:latest .

# If using a registry, tag and push:
docker tag backend-service:latest <registry>/backend-service:latest
docker push <registry>/backend-service:latest
```

## Step 2: Load Image to Cluster

For local clusters (minikube/kind):

```bash
# Minikube
minikube image load backend-service:latest

# Kind
kind load docker-image backend-service:latest
```

## Step 3: Deploy to Kubernetes

Apply manifests in order:

```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Create ConfigMap (choose hot or standby)
kubectl apply -f k8s/configmap-hot.yaml
# OR for standby: kubectl apply -f k8s/configmap-standby.yaml

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

# Check deployment
kubectl get deployment -n backend

# View logs
kubectl logs -n backend -l app=backend-service --tail=50
```

## Step 5: Test the Service

```bash
# Port forward
kubectl port-forward -n backend svc/backend-service 8080:80

# Test endpoints
curl http://localhost:8080/healthz
curl http://localhost:8080/
```

## Updating CLUSTER_ROLE

```bash
# Update ConfigMap
kubectl set data configmap/backend-config CLUSTER_ROLE=standby -n backend

# Restart pods to pick up new env var
kubectl rollout restart deployment/backend-service -n backend
```

Or edit directly:

```bash
kubectl edit configmap backend-config -n backend
```

## High Availability Setup

For hot/standby failover with HAProxy:

```bash
# Deploy HAProxy components
kubectl apply -f k8s/haproxy-configmap.yaml
kubectl apply -f k8s/haproxy-deployment.yaml
kubectl apply -f k8s/haproxy-service.yaml
```

HAProxy will automatically route traffic to the hot cluster and failover to standby if needed.

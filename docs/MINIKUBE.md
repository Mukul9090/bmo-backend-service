# Minikube Deployment Guide

Complete guide for deploying the backend service to Minikube for local development.

## Prerequisites

- Minikube installed
- kubectl configured
- Docker installed

## Quick Start

```bash
# Start Minikube
minikube start --driver=docker

# Build and load image
eval $(minikube docker-env)
docker build -t backend-service:latest .
eval $(minikube docker-env -u)

# Deploy
kubectl apply -f k8s/

# Access via port-forward
kubectl port-forward -n backend svc/backend-service 8080:80
```

## Detailed Steps

### 1. Start Minikube

```bash
minikube start --driver=docker
minikube status
```

### 2. Build and Load Image

**Option A: Build in Minikube context (Recommended)**
```bash
eval $(minikube docker-env)
docker build -t backend-service:latest .
docker images | grep backend-service
eval $(minikube docker-env -u)
```

**Option B: Build locally and load**
```bash
docker build -t backend-service:latest .
minikube image load backend-service:latest
```

### 3. Deploy to Kubernetes

```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Create ConfigMap (hot or standby)
kubectl apply -f k8s/configmap-hot.yaml

# Deploy application
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Or apply all at once
kubectl apply -f k8s/
```

### 4. Verify Deployment

```bash
# Check pods
kubectl get pods -n backend

# Check service
kubectl get svc -n backend

# View logs
kubectl logs -n backend -l app=backend-service --tail=50
```

### 5. Access Application

```bash
# Port forward
kubectl port-forward -n backend svc/backend-service 8080:80

# Test endpoints
curl http://localhost:8080/healthz
curl http://localhost:8080/
```

## Troubleshooting

### ImagePullBackOff

```bash
# Ensure image exists in Minikube
eval $(minikube docker-env)
docker images | grep backend-service

# Rebuild if needed
docker build -t backend-service:latest .
kubectl delete pods -n backend -l app=backend-service
```

### Pods Not Ready

```bash
# Check pod logs
kubectl logs -n backend <pod-name>

# Check pod events
kubectl describe pod -n backend <pod-name>

# Test health endpoint from pod
kubectl exec -it -n backend <pod-name> -- curl localhost:8080/healthz
```

### Connection Refused

```bash
# Verify port-forward is running
ps aux | grep port-forward

# Restart port-forward
kubectl port-forward -n backend svc/backend-service 8080:80

# Test from inside cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n backend -- curl http://backend-service/healthz
```

## Useful Commands

```bash
# View all resources
kubectl get all -n backend

# Scale deployment
kubectl scale deployment backend-service -n backend --replicas=5

# Restart deployment
kubectl rollout restart deployment/backend-service -n backend

# Update ConfigMap
kubectl set data configmap/backend-config CLUSTER_ROLE=standby -n backend
kubectl rollout restart deployment/backend-service -n backend

# Delete everything
kubectl delete -f k8s/
```

## Cleanup

```bash
# Delete application
kubectl delete -f k8s/

# Stop Minikube
minikube stop

# Delete Minikube cluster
minikube delete
```

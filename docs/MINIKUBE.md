# Minikube Deployment Guide

## Step 1: Choose Minikube Driver

### Docker Driver (Recommended for Local Development)

**Why Docker Driver:**
- Faster startup time
- Lower resource usage
- Shares Docker daemon with your host
- Easier image loading (no need to push to registry)
- Better for local development and testing

**When to use VM Driver:**
- Need complete isolation
- Testing VM-specific features
- Production-like environment simulation

**For this guide, we'll use Docker driver.**

---

## Step 2: Start Minikube

### Check if Minikube is installed:
```bash
minikube version
```

### Start Minikube with Docker driver:
```bash
minikube start --driver=docker
```

**What this does:**
- Creates a Minikube cluster using Docker
- Sets up kubectl context to point to Minikube
- Takes 1-2 minutes on first run

### Verify Minikube is running:
```bash
minikube status
kubectl get nodes
```

**Expected output:**
```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   1m    v1.28.0
```

---

## Step 3: Build and Load Docker Image

### Option A: Using Minikube's Docker Environment (Recommended)

**Build image in Minikube's Docker context:**
```bash
# Point Docker to Minikube's Docker daemon
eval $(minikube docker-env)

# Build the image
docker build -t backend-service:latest .

# Verify image exists
docker images | grep backend-service
```

**What this does:**
- Uses Minikube's internal Docker daemon
- Image is immediately available to Kubernetes
- No need to push to registry

**Important:** Keep this terminal session open, or re-run `eval $(minikube docker-env)` in new terminals.

### Option B: Using minikube image load

```bash
# Build image normally (on your host)
docker build -t backend-service:latest .

# Load into Minikube
minikube image load backend-service:latest
```

**When to use:** If you prefer building on your host Docker.

---

## Step 4: Deploy to Kubernetes

### Apply manifests in order:

```bash
# Navigate to project root
cd /Users/mukul/Desktop/BMO

# 1. Create namespace
kubectl apply -f k8s/namespace.yaml

# 2. Create ConfigMap
kubectl apply -f k8s/configmap.yaml

# 3. Create Deployment
kubectl apply -f k8s/deployment.yaml

# 4. Create Service
kubectl apply -f k8s/service.yaml
```

**Or apply all at once:**
```bash
kubectl apply -f k8s/
```

**What happens:**
- Namespace `backend` is created
- ConfigMap sets `CLUSTER_ROLE=hot`
- Deployment creates 3 pod replicas
- Service exposes pods on port 80

---

## Step 5: Verify Deployment

### Check Pods:
```bash
kubectl get pods -n backend
```

**Expected output (after ~30 seconds):**
```
NAME                              READY   STATUS    RESTARTS   AGE
backend-service-xxxxxxxxxx-xxxxx  1/1     Running   0          30s
backend-service-xxxxxxxxxx-xxxxx  1/1     Running   0          30s
backend-service-xxxxxxxxxx-xxxxx  1/1     Running   0          30s
```

**Watch pods until all are Running:**
```bash
kubectl get pods -n backend -w
```
Press `Ctrl+C` to stop watching.

### Check Deployment:
```bash
kubectl get deployment -n backend
```

**Expected output:**
```
NAME              READY   UP-TO-DATE   AVAILABLE   AGE
backend-service   3/3     3            3           1m
```

### Check Service:
```bash
kubectl get svc -n backend
```

**Expected output:**
```
NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
backend-service   ClusterIP   10.96.xxx.xxx   <none>        80/TCP    1m
```

### Check ConfigMap:
```bash
kubectl get configmap -n backend
kubectl describe configmap backend-config -n backend
```

### View Pod Logs:
```bash
# View logs from all pods
kubectl logs -n backend -l app=backend-service --tail=50

# View logs from specific pod
kubectl logs -n backend <pod-name>
```

---

## Step 6: Access the Application

### Method 1: Port Forward (Recommended for Testing)

```bash
# Forward local port 8080 to service port 80
kubectl port-forward -n backend svc/backend-service 8080:80
```

**Keep this terminal open.** In another terminal, test:

```bash
# Health check endpoint
curl http://localhost:8080/healthz

# Root endpoint
curl http://localhost:8080/
```

**Expected responses:**
```json
{"role":"hot","status":"ok"}
{"message":"backend-service running","role":"hot"}
```

### Method 2: Minikube Service (Alternative)

```bash
# Open service in browser (creates tunnel)
minikube service backend-service -n backend
```

This opens the service URL in your default browser.

### Method 3: Direct Pod Access (Debugging)

```bash
# Get pod name
POD_NAME=$(kubectl get pods -n backend -l app=backend-service -o jsonpath='{.items[0].metadata.name}')

# Port forward to specific pod
kubectl port-forward -n backend $POD_NAME 8080:8080
```

---

## Step 7: Troubleshooting Common Errors

### Error 1: ImagePullBackOff

**Symptoms:**
```bash
kubectl get pods -n backend
# Shows: ImagePullBackOff or ErrImagePull
```

**Causes:**
- Image not found in Minikube's Docker daemon
- Wrong image name/tag
- Docker context not pointing to Minikube

**Fix:**
```bash
# Ensure you're using Minikube's Docker
eval $(minikube docker-env)

# Rebuild and verify
docker build -t backend-service:latest .
docker images | grep backend-service

# Delete and recreate pods
kubectl delete pods -n backend -l app=backend-service
```

### Error 2: CrashLoopBackOff

**Symptoms:**
```bash
kubectl get pods -n backend
# Shows: CrashLoopBackOff
```

**Causes:**
- Application error
- Security context issues
- Missing dependencies

**Fix:**
```bash
# Check pod logs
kubectl logs -n backend <pod-name>

# Check pod events
kubectl describe pod -n backend <pod-name>

# Common fix: Check if app is listening on 0.0.0.0:8080
# (Your server.py already does this correctly)
```

**If security context is the issue:**
```bash
# Temporarily check without security context
# Edit deployment.yaml, comment out securityContext section
# Then: kubectl apply -f k8s/deployment.yaml
```

### Error 3: Connection Refused

**Symptoms:**
```bash
curl http://localhost:8080/healthz
# Connection refused
```

**Causes:**
- Port forward not running
- Wrong port mapping
- Service not created

**Fix:**
```bash
# Check if port-forward is running
ps aux | grep port-forward

# Restart port-forward
kubectl port-forward -n backend svc/backend-service 8080:80

# Verify service exists
kubectl get svc -n backend

# Test from inside cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n backend -- curl http://backend-service/healthz
```

### Error 4: Pods Not Ready

**Symptoms:**
```bash
kubectl get pods -n backend
# Shows: 0/1 Ready
```

**Causes:**
- Readiness probe failing
- Application not responding on /healthz
- Wrong port in probe

**Fix:**
```bash
# Check readiness probe status
kubectl describe pod -n backend <pod-name> | grep -A 10 "Readiness"

# Check if /healthz endpoint works
kubectl exec -it -n backend <pod-name> -- curl localhost:8080/healthz

# If probe is too aggressive, increase initialDelaySeconds in deployment.yaml
```

### Error 5: Namespace Not Found

**Symptoms:**
```bash
Error from server (NotFound): namespaces "backend" not found
```

**Fix:**
```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Or create manually
kubectl create namespace backend
```

---

## Step 8: Useful Commands

### View Everything:
```bash
kubectl get all -n backend
```

### Delete Everything:
```bash
kubectl delete -f k8s/
```

### Restart Deployment:
```bash
kubectl rollout restart deployment/backend-service -n backend
```

### Scale Deployment:
```bash
kubectl scale deployment backend-service -n backend --replicas=5
```

### Update ConfigMap:
```bash
# Change CLUSTER_ROLE to standby
kubectl set data configmap/backend-config CLUSTER_ROLE=standby -n backend

# Restart pods to pick up change
kubectl rollout restart deployment/backend-service -n backend
```

### Enter Pod Shell:
```bash
POD_NAME=$(kubectl get pods -n backend -l app=backend-service -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n backend $POD_NAME -- /bin/sh
```

### View Resource Usage:
```bash
kubectl top pods -n backend
kubectl top nodes
```

---

## Step 9: Clean Up

### Stop Port Forward:
Press `Ctrl+C` in the terminal running port-forward.

### Delete Application:
```bash
kubectl delete -f k8s/
```

### Stop Minikube:
```bash
minikube stop
```

### Delete Minikube Cluster (Complete Cleanup):
```bash
minikube delete
```

---

## Quick Reference Checklist

- [ ] Minikube started with Docker driver
- [ ] Docker image built in Minikube context
- [ ] All Kubernetes manifests applied
- [ ] All 3 pods in Running state
- [ ] Service created and accessible
- [ ] Port-forward working
- [ ] Health endpoint responding
- [ ] Root endpoint responding

---

## Next Steps

Once deployment is working:
- Test failover by deleting a pod: `kubectl delete pod -n backend <pod-name>`
- Scale up/down: `kubectl scale deployment backend-service -n backend --replicas=5`
- Update ConfigMap to change CLUSTER_ROLE
- Monitor logs: `kubectl logs -f -n backend -l app=backend-service`


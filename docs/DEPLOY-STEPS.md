# Step-by-Step Minikube Deployment Guide

## Prerequisites
- Docker image built: `backend-service:latest`
- Minikube installed
- kubectl configured

---

## Step 1: Start Minikube

**Command:**
```bash
minikube start --driver=docker
```

**What this does:**
- Starts Minikube cluster using Docker driver
- Configures kubectl to use Minikube context
- Takes 1-2 minutes on first run

**Verify:**
```bash
kubectl get nodes
```
Expected: Shows `minikube` node in `Ready` state

**Common Issues:**
- **Docker not running**: Start Docker Desktop first
- **Port conflicts**: Stop other services using ports 8443, 10250

---

## Step 2: Load Docker Image into Minikube

**Why:** Minikube has its own Docker daemon. Your local image needs to be loaded into Minikube's Docker.

### Method 1: Using `minikube image load` (Recommended)

**Command:**
```bash
minikube image load backend-service:latest
```

**What this does:**
- Copies your local image into Minikube's Docker registry
- Image becomes available to Kubernetes pods

**Verify:**
```bash
minikube image ls | grep backend-service
```

### Method 2: Build in Minikube's Docker Context

**Commands:**
```bash
# Point Docker to Minikube
eval $(minikube docker-env)

# Build image (uses Minikube's Docker)
cd /Users/mukul/Desktop/BMO
docker build -t backend-service:latest .

# Verify
docker images | grep backend-service

# Reset Docker context (optional)
eval $(minikube docker-env -u)
```

**When to use:** If Method 1 doesn't work or you want to rebuild in Minikube

---

## Step 3: Apply Kubernetes Manifests

**Order matters:** Apply in this sequence:

### 3.1 Create Namespace
```bash
kubectl apply -f k8s/namespace.yaml
```
**What this does:** Creates the `backend` namespace

**Verify:**
```bash
kubectl get namespace backend
```

### 3.2 Create ConfigMap
```bash
kubectl apply -f k8s/configmap.yaml
```
**What this does:** Creates ConfigMap with `CLUSTER_ROLE=hot`

**Verify:**
```bash
kubectl get configmap -n backend
kubectl describe configmap backend-config -n backend
```

### 3.3 Create Deployment
```bash
kubectl apply -f k8s/deployment.yaml
```
**What this does:** Creates 3 pod replicas running your app

**Verify:**
```bash
kubectl get pods -n backend
```
Wait until all pods show `Running` and `1/1 Ready`

**Watch pods:**
```bash
kubectl get pods -n backend -w
```
Press `Ctrl+C` to stop watching

### 3.4 Create Service
```bash
kubectl apply -f k8s/service.yaml
```
**What this does:** Creates ClusterIP service on port 80 → 8080

**Verify:**
```bash
kubectl get svc -n backend
```

### Apply All at Once (Alternative)
```bash
kubectl apply -f k8s/
```

---

## Step 4: Verify Deployment

### Check Pod Status
```bash
kubectl get pods -n backend
```

**Expected output:**
```
NAME                              READY   STATUS    RESTARTS   AGE
backend-service-xxxxxxxxxx-xxxxx  1/1     Running   0          30s
backend-service-xxxxxxxxxx-xxxxx  1/1     Running   0          30s
backend-service-xxxxxxxxxx-xxxxx  1/1     Running   0          30s
```

**All pods should show:**
- `STATUS: Running`
- `READY: 1/1`
- No `ImagePullBackOff` or `ErrImagePull`

### Check Deployment
```bash
kubectl get deployment -n backend
```

**Expected:**
```
NAME              READY   UP-TO-DATE   AVAILABLE   AGE
backend-service   3/3     3            3           1m
```

### Check Service
```bash
kubectl get svc -n backend
```

**Expected:**
```
NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
backend-service   ClusterIP   10.96.xxx.xxx   <none>        80/TCP    1m
```

### View Pod Logs
```bash
# All pods
kubectl logs -n backend -l app=backend-service --tail=50

# Specific pod
kubectl logs -n backend <pod-name>
```

---

## Step 5: Access the Application

### Method 1: Port Forward (Recommended)

**Command:**
```bash
kubectl port-forward -n backend svc/backend-service 8080:80
```

**What this does:**
- Forwards local port 8080 to service port 80
- Keep this terminal open

**In another terminal, test:**
```bash
# Health check
curl http://localhost:8080/healthz

# Root endpoint
curl http://localhost:8080/
```

**Expected responses:**
```json
{"role":"hot","status":"ok"}
{"message":"backend-service running","role":"hot"}
```

**Stop port-forward:** Press `Ctrl+C`

### Method 2: Minikube Service Tunnel

**Command:**
```bash
minikube service backend-service -n backend
```

**What this does:**
- Opens service URL in browser
- Creates temporary tunnel

---

## Troubleshooting Common Errors

### Error 1: ImagePullBackOff

**Symptoms:**
```bash
kubectl get pods -n backend
# Shows: ImagePullBackOff or ErrImagePull
```

**Cause:** Image not found in Minikube's Docker registry

**Fix:**
```bash
# Load image into Minikube
minikube image load backend-service:latest

# Verify
minikube image ls | grep backend-service

# Delete and recreate pods
kubectl delete pods -n backend -l app=backend-service
```

**Alternative Fix:**
```bash
# Build in Minikube context
eval $(minikube docker-env)
docker build -t backend-service:latest .
eval $(minikube docker-env -u)

# Restart deployment
kubectl rollout restart deployment/backend-service -n backend
```

---

### Error 2: Pod Stuck in Pending

**Symptoms:**
```bash
kubectl get pods -n backend
# Shows: STATUS Pending
```

**Causes:**
- Insufficient resources
- Node not ready
- Image pull issues

**Fix:**
```bash
# Check pod events
kubectl describe pod -n backend <pod-name>

# Check node resources
kubectl top nodes

# Check if node is ready
kubectl get nodes

# If node not ready, restart Minikube
minikube stop
minikube start --driver=docker
```

---

### Error 3: Connection Refused

**Symptoms:**
```bash
curl http://localhost:8080/healthz
# Connection refused
```

**Causes:**
- Port-forward not running
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

---

### Error 4: CrashLoopBackOff

**Symptoms:**
```bash
kubectl get pods -n backend
# Shows: CrashLoopBackOff
```

**Causes:**
- Application error
- Security context issues
- Missing environment variables

**Fix:**
```bash
# Check pod logs
kubectl logs -n backend <pod-name>

# Check pod events
kubectl describe pod -n backend <pod-name>

# Check if ConfigMap exists
kubectl get configmap -n backend

# Verify environment variable
kubectl exec -n backend <pod-name> -- env | grep CLUSTER_ROLE
```

---

### Error 5: Pods Not Ready (0/1)

**Symptoms:**
```bash
kubectl get pods -n backend
# Shows: 0/1 Ready
```

**Causes:**
- Readiness probe failing
- Application not responding

**Fix:**
```bash
# Check readiness probe
kubectl describe pod -n backend <pod-name> | grep -A 10 "Readiness"

# Test endpoint from inside pod
kubectl exec -it -n backend <pod-name> -- curl localhost:8080/healthz

# Check application logs
kubectl logs -n backend <pod-name>
```

---

## Quick Reference Commands

### Deployment
```bash
# Start Minikube
minikube start --driver=docker

# Load image
minikube image load backend-service:latest

# Deploy
kubectl apply -f k8s/

# Verify
kubectl get all -n backend
```

### Access
```bash
# Port forward
kubectl port-forward -n backend svc/backend-service 8080:80

# Test
curl http://localhost:8080/healthz
```

### Debugging
```bash
# Pod logs
kubectl logs -n backend -l app=backend-service -f

# Pod shell
kubectl exec -it -n backend <pod-name> -- /bin/sh

# Describe resources
kubectl describe pod -n backend <pod-name>
kubectl describe deployment -n backend backend-service
```

### Cleanup
```bash
# Delete application
kubectl delete -f k8s/

# Stop Minikube
minikube stop

# Delete Minikube (complete cleanup)
minikube delete
```

---

## Success Checklist

- [ ] Minikube started and node is Ready
- [ ] Docker image loaded into Minikube
- [ ] All Kubernetes resources created (namespace, configmap, deployment, service)
- [ ] All 3 pods in Running state with 1/1 Ready
- [ ] No ImagePullBackOff errors
- [ ] Service created and accessible
- [ ] Port-forward working
- [ ] Health endpoint responding: `{"role":"hot","status":"ok"}`
- [ ] Root endpoint responding: `{"message":"backend-service running","role":"hot"}`

---

## Next Steps

Once deployment is working:
- Test failover: `kubectl delete pod -n backend <pod-name>` (should auto-recreate)
- Scale: `kubectl scale deployment backend-service -n backend --replicas=5`
- Update ConfigMap: `kubectl set data configmap/backend-config CLUSTER_ROLE=standby -n backend`
- Monitor: `kubectl logs -f -n backend -l app=backend-service`


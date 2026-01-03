# Network and Security Configuration

## Overview

This document describes the minimal but effective network security configuration implemented in the high availability system. The configuration uses Kubernetes Network Policies to control traffic flow and ensure secure communication between components.

## What is Network Security in Kubernetes?

**Network Policies** are like firewalls for your Kubernetes pods. They control:
- **Who can talk to your pods** (Ingress)
- **Where your pods can connect** (Egress)

Think of it like a security guard that only allows specific people to enter and leave a building.

## Our Network Security Setup

### 1. Network Policies

We have **2 simple Network Policy files**:

#### `k8s/network-policy-backend.yaml`
- **Purpose**: Controls traffic to/from backend services
- **Applied to**: Both `backend-hot` and `backend-standby` namespaces
- **Rules**:
  - ✅ Allow traffic FROM HAProxy (load balancer)
  - ✅ Allow traffic FROM Prometheus (for metrics)
  - ✅ Allow DNS queries (required for service discovery)
  - ❌ Block everything else

#### `k8s/network-policy-haproxy.yaml`
- **Purpose**: Controls traffic to/from HAProxy
- **Applied to**: `default` namespace
- **Rules**:
  - ✅ Allow traffic FROM anywhere (HAProxy is the entry point)
  - ✅ Allow traffic TO backend services (hot and standby)
  - ✅ Allow DNS queries
  - ❌ Block everything else

### 2. Namespace Labels

Namespaces are labeled so Network Policies can identify them:

```yaml
metadata:
  name: backend-hot
  labels:
    name: backend-hot  # This label is used by Network Policies
```

### 3. Pod Security (Already in deployment.yaml)

Your deployment already has security settings:

```yaml
securityContext:
  runAsNonRoot: true      # Don't run as root user
  runAsUser: 1000         # Run as user ID 1000
  allowPrivilegeEscalation: false  # Can't gain more privileges
  capabilities:
    drop:
      - ALL               # Remove all Linux capabilities
```

## How It Works

### Traffic Flow with Network Policies

```
Internet
   ↓
HAProxy (default namespace)
   ↓ [Allowed by network policy]
Backend Services (backend-hot/standby)
   ↓ [Allowed by network policy]
Prometheus (monitoring namespace)
```

### What Gets Blocked

Without Network Policies:
- ❌ Any pod could talk to any other pod
- ❌ No traffic control
- ❌ Security risk

With Network Policies:
- ✅ Only HAProxy can reach backend services
- ✅ Only Prometheus can scrape metrics
- ✅ Backend services can only make DNS queries
- ✅ Everything else is blocked

## Simple Explanation

**Think of Network Policies like a building with security:**

1. **HAProxy** = Main entrance (anyone can come in)
2. **Backend Services** = Office rooms (only HAProxy and Prometheus can enter)
3. **Prometheus** = Security guard (can check all rooms for metrics)
4. **DNS** = Phone system (everyone needs it to make calls)

## Deployment

### Apply Network Policies

```bash
# Apply network policies
kubectl apply -f k8s/network-policy-backend.yaml
kubectl apply -f k8s/network-policy-haproxy.yaml
```

### Verify They're Working

```bash
# Check network policies
kubectl get networkpolicies -A

# Should show:
# - backend-network-policy in backend-hot
# - backend-network-policy in backend-standby
# - haproxy-network-policy in default
```

## Testing

### Test That Policies Work

```bash
# Try to access backend from a test pod (should fail)
kubectl run test-pod --image=curlimages/curl -n backend-hot --rm -it -- \
  curl http://backend-service.backend-standby.svc.cluster.local:80/healthz

# This should fail because network policy blocks direct pod-to-pod communication
```

### Test That HAProxy Can Reach Backend (should work)

```bash
# HAProxy can reach backend (allowed by policy)
kubectl exec -n default deployment/haproxy -- \
  curl http://backend-service.backend-hot.svc.cluster.local:80/healthz

# This should work because network policy allows it
```

## What This Achieves

### Security Benefits

1. **Isolation**: Backend services are isolated from other pods
2. **Least Privilege**: Only necessary traffic is allowed
3. **Defense in Depth**: Multiple layers of security
4. **Compliance**: Meets security best practices

### For Your Assignment

This demonstrates:
- ✅ Understanding of network segmentation
- ✅ Implementation of security policies
- ✅ Traffic control and isolation
- ✅ Best practices for Kubernetes security

## Interview Talking Points

When asked about network security, you can say:

1. **"We use Kubernetes Network Policies to control traffic flow"**
   - Explain that Network Policies act like firewalls
   - Only allow necessary communication

2. **"We implement the principle of least privilege"**
   - Backend services only accept traffic from HAProxy and Prometheus
   - Everything else is blocked by default

3. **"We use namespace isolation"**
   - Different namespaces for different components
   - Network policies enforce boundaries between namespaces

4. **"We combine network security with pod security"**
   - Network Policies (who can talk to pods)
   - Security Contexts (how pods run)

## Failover Compatibility

**✅ Network Policies Support Failover:**

The network policies are designed to work seamlessly with the failover mechanism:

1. **HAProxy can reach both clusters:**
   - HAProxy Network Policy allows egress to both `backend-hot` and `backend-standby`
   - Allows both port 80 (service port) and port 8080 (pod port)
   - This ensures health checks and traffic routing work

2. **Both clusters accept HAProxy traffic:**
   - Hot cluster allows ingress from HAProxy on port 8080
   - Standby cluster allows ingress from HAProxy on port 8080
   - Both are ready to receive traffic when needed

3. **Failover flow:**
   - HAProxy checks hot cluster health (allowed by network policy) ✅
   - If hot fails, HAProxy switches to standby (allowed by network policy) ✅
   - When hot recovers, traffic returns (allowed by network policy) ✅

**Result:** Network policies do NOT block failover - they actually ensure secure failover!

## Summary

**What we have:**
- 2 Network Policy files (simple and effective)
- Namespace labels for policy matching
- Pod security contexts (already in deployment)
- Clear documentation
- **Failover-compatible policies**

**What it does:**
- Controls who can talk to your services
- Blocks unauthorized traffic
- Allows only necessary communication
- **Supports automatic failover**
- Demonstrates security best practices

**Why it's minimal:**
- Only 2 policy files (not 6+ like complex setups)
- Simple rules (easy to understand)
- Covers the basics (meets requirements)
- Interview-ready (you can explain it clearly)
- **Failover-ready (policies don't interfere with HAProxy failover)**

This is a **minimal but complete** network security setup that demonstrates your understanding while being simple enough to explain in an interview, and it fully supports your failover mechanism!


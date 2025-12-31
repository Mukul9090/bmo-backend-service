#!/bin/bash
# Minikube Deployment Script for backend-service

set -e

echo "=== Step 1: Starting Minikube ==="
minikube start --driver=docker
echo "✓ Minikube started"

echo ""
echo "=== Step 2: Loading Docker Image into Minikube ==="
# Method 1: Using minikube image load (recommended)
minikube image load backend-service:latest
echo "✓ Image loaded into Minikube"

# Alternative Method (if above doesn't work):
# eval $(minikube docker-env)
# docker build -t backend-service:latest .
# eval $(minikube docker-env -u)

echo ""
echo "=== Step 3: Verifying Image in Minikube ==="
minikube image ls | grep backend-service || echo "⚠ Image not found, trying alternative method..."

echo ""
echo "=== Step 4: Applying Kubernetes Manifests ==="
cd "$(dirname "$0")"
kubectl apply -f k8s/namespace.yaml
echo "✓ Namespace created"

kubectl apply -f k8s/configmap.yaml
echo "✓ ConfigMap created"

kubectl apply -f k8s/deployment.yaml
echo "✓ Deployment created"

kubectl apply -f k8s/service.yaml
echo "✓ Service created"

echo ""
echo "=== Step 5: Waiting for Pods to be Ready ==="
kubectl wait --for=condition=ready pod -l app=backend-service -n backend --timeout=120s || true

echo ""
echo "=== Step 6: Deployment Status ==="
kubectl get pods -n backend
kubectl get svc -n backend

echo ""
echo "=== Step 7: Testing Deployment ==="
echo "Starting port-forward in background..."
kubectl port-forward -n backend svc/backend-service 8080:80 > /tmp/port-forward.log 2>&1 &
PORT_FORWARD_PID=$!
sleep 3

echo ""
echo "Testing endpoints..."
curl -s http://localhost:8080/healthz && echo ""
curl -s http://localhost:8080/ && echo ""

echo ""
echo "=== Deployment Complete! ==="
echo "Port-forward is running (PID: $PORT_FORWARD_PID)"
echo "To stop port-forward: kill $PORT_FORWARD_PID"
echo "To view logs: kubectl logs -n backend -l app=backend-service -f"


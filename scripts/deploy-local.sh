#!/bin/bash
# Local deployment script for hot/standby clusters and HAProxy
# This script deploys all resources to a local Kubernetes cluster

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOCKER_IMAGE="${DOCKER_IMAGE:-mukul1599/backend-service}"
DOCKER_TAG="${DOCKER_TAG:-latest}"
NAMESPACE_HOT="backend-hot"
NAMESPACE_STANDBY="backend-standby"
REPLICAS="${REPLICAS:-2}"

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        echo "Error: kubectl is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        echo "Error: Cannot connect to Kubernetes cluster"
        echo "Make sure your cluster is running (minikube, kind, Docker Desktop, etc.)"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Deploy namespaces
deploy_namespaces() {
    print_info "Deploying namespaces..."
    kubectl apply -f k8s/namespace.yaml
    kubectl apply -f monitoring/namespace.yaml
    print_success "Namespaces deployed"
}

# Deploy monitoring
deploy_monitoring() {
    print_info "Deploying monitoring stack..."
    kubectl apply -f monitoring/prometheus/
    kubectl apply -f monitoring/grafana/
    print_success "Monitoring stack deployed"
}

# Deploy backend clusters
deploy_backend_clusters() {
    print_info "Deploying backend clusters..."
    
    # Deploy ConfigMaps
    kubectl create configmap backend-config \
        --from-literal=CLUSTER_ROLE=hot \
        -n "$NAMESPACE_HOT" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    kubectl create configmap backend-config \
        --from-literal=CLUSTER_ROLE=standby \
        -n "$NAMESPACE_STANDBY" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    print_success "ConfigMaps deployed"
    
    # Deploy hot cluster
    print_info "Deploying hot cluster..."
    sed "s/namespace: backend/namespace: $NAMESPACE_HOT/" k8s/deployment.yaml | \
        sed "s|image: $DOCKER_IMAGE$|image: $DOCKER_IMAGE:$DOCKER_TAG|" | \
        sed "s/replicas: [0-9]*/replicas: $REPLICAS/" | kubectl apply -f -
    
    # Deploy standby cluster
    print_info "Deploying standby cluster..."
    sed "s/namespace: backend/namespace: $NAMESPACE_STANDBY/" k8s/deployment.yaml | \
        sed "s|image: $DOCKER_IMAGE$|image: $DOCKER_IMAGE:$DOCKER_TAG|" | \
        sed "s/replicas: [0-9]*/replicas: $REPLICAS/" | kubectl apply -f -
    
    print_success "Backend deployments created"
    
    # Deploy services
    print_info "Deploying services..."
    sed "s/namespace: backend/namespace: $NAMESPACE_HOT/" k8s/service.yaml | kubectl apply -f -
    sed "s/namespace: backend/namespace: $NAMESPACE_STANDBY/" k8s/service.yaml | \
        sed 's/nodePort: 30080/nodePort: 30081/' | kubectl apply -f -
    
    print_success "Services deployed"
}

# Deploy HAProxy
deploy_haproxy() {
    print_info "Deploying HAProxy..."
    kubectl apply -f k8s/haproxy-configmap.yaml -f k8s/haproxy-deployment.yaml -f k8s/haproxy-service.yaml
    print_success "HAProxy deployed"
}

# Deploy network policies
deploy_network_policies() {
    print_info "Deploying network policies..."
    kubectl apply -f k8s/network-policy-backend.yaml
    kubectl apply -f k8s/network-policy-haproxy.yaml
    print_success "Network policies deployed"
}

# Wait for deployments
wait_for_deployments() {
    print_info "Waiting for deployments to be ready..."
    
    kubectl wait --for=condition=available --timeout=300s \
        deployment/backend-service -n "$NAMESPACE_HOT" || true
    
    kubectl wait --for=condition=available --timeout=300s \
        deployment/backend-service -n "$NAMESPACE_STANDBY" || true
    
    kubectl wait --for=condition=available --timeout=300s \
        deployment/haproxy || true
    
    print_success "Deployments are ready"
}

# Print deployment summary
print_summary() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   Deployment Summary                   ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    
    print_info "Hot cluster pods:"
    kubectl get pods -n "$NAMESPACE_HOT" -l app=backend-service
    
    echo ""
    print_info "Standby cluster pods:"
    kubectl get pods -n "$NAMESPACE_STANDBY" -l app=backend-service
    
    echo ""
    print_info "HAProxy pods:"
    kubectl get pods -l app=haproxy
    
    echo ""
    print_info "Services:"
    kubectl get svc -n "$NAMESPACE_HOT"
    kubectl get svc -n "$NAMESPACE_STANDBY"
    kubectl get svc -l app=haproxy
    
    echo ""
    print_success "Deployment complete!"
    echo ""
    print_info "To test the deployment, run:"
    echo "  ./scripts/test-deployments-local.sh"
    echo ""
    print_info "To access services locally, use port-forward:"
    echo "  kubectl port-forward -n $NAMESPACE_HOT svc/backend-service 8080:80"
    echo "  kubectl port-forward -n $NAMESPACE_STANDBY svc/backend-service 8081:80"
    echo "  kubectl port-forward svc/haproxy 9090:9090"
}

# Main execution
main() {
    echo "╔════════════════════════════════════════╗"
    echo "║   Local Kubernetes Deployment         ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    
    check_prerequisites
    deploy_namespaces
    deploy_monitoring
    deploy_backend_clusters
    deploy_haproxy
    deploy_network_policies
    wait_for_deployments
    print_summary
}

# Run main function
main


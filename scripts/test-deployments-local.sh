#!/bin/bash
# Local deployment testing script
# Tests Kubernetes deployments for hot/standby clusters and HAProxy

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
# Auto-detect namespaces or use defaults
if kubectl get namespace cluster-hot &>/dev/null; then
    NAMESPACE_HOT="cluster-hot"
elif kubectl get namespace backend-hot &>/dev/null; then
    NAMESPACE_HOT="backend-hot"
else
    NAMESPACE_HOT="backend-hot"
fi

if kubectl get namespace cluster-standby &>/dev/null; then
    NAMESPACE_STANDBY="cluster-standby"
elif kubectl get namespace backend-standby &>/dev/null; then
    NAMESPACE_STANDBY="backend-standby"
else
    NAMESPACE_STANDBY="backend-standby"
fi

NAMESPACE_MONITORING="monitoring"
EXPECTED_REPLICAS=2
TIMEOUT=300

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Print functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    print_success "kubectl is installed"
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        print_info "Make sure your cluster is running and kubectl is configured"
        exit 1
    fi
    print_success "Kubernetes cluster is accessible"
    
    # Check cluster context
    CONTEXT=$(kubectl config current-context)
    print_info "Current cluster context: $CONTEXT"
    
    # Check if namespaces exist
    if ! kubectl get namespace "$NAMESPACE_HOT" &> /dev/null; then
        print_warning "Namespace $NAMESPACE_HOT does not exist"
    else
        print_success "Namespace $NAMESPACE_HOT exists"
    fi
    
    if ! kubectl get namespace "$NAMESPACE_STANDBY" &> /dev/null; then
        print_warning "Namespace $NAMESPACE_STANDBY does not exist"
    else
        print_success "Namespace $NAMESPACE_STANDBY exists"
    fi
}

# Test pod status
test_pod_status() {
    print_header "Testing Pod Status"
    
    # Check hot cluster pods
    HOT_PODS=$(kubectl get pods -n "$NAMESPACE_HOT" -l app=backend-service --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ -z "$HOT_PODS" ]; then
        HOT_PODS=0
    fi
    
    print_info "Hot cluster pods running: $HOT_PODS (expected: $EXPECTED_REPLICAS)"
    if [ "$HOT_PODS" -ge "$EXPECTED_REPLICAS" ]; then
        print_success "Hot cluster has sufficient pods"
    else
        print_error "Hot cluster has insufficient pods ($HOT_PODS < $EXPECTED_REPLICAS)"
    fi
    
    # Check standby cluster pods
    STANDBY_PODS=$(kubectl get pods -n "$NAMESPACE_STANDBY" -l app=backend-service --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ -z "$STANDBY_PODS" ]; then
        STANDBY_PODS=0
    fi
    
    print_info "Standby cluster pods running: $STANDBY_PODS (expected: $EXPECTED_REPLICAS)"
    if [ "$STANDBY_PODS" -ge "$EXPECTED_REPLICAS" ]; then
        print_success "Standby cluster has sufficient pods"
    else
        print_error "Standby cluster has insufficient pods ($STANDBY_PODS < $EXPECTED_REPLICAS)"
    fi
    
    # Check HAProxy pods
    HAPROXY_PODS=$(kubectl get pods -l app=haproxy --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ -z "$HAPROXY_PODS" ]; then
        HAPROXY_PODS=0
    fi
    
    print_info "HAProxy pods running: $HAPROXY_PODS (expected: 1)"
    if [ "$HAPROXY_PODS" -ge "1" ]; then
        print_success "HAProxy has sufficient pods"
    else
        print_error "HAProxy has insufficient pods ($HAPROXY_PODS < 1)"
    fi
    
    # Show pod details
    echo ""
    print_info "Pod Details:"
    kubectl get pods -n "$NAMESPACE_HOT" -l app=backend-service 2>/dev/null || true
    kubectl get pods -n "$NAMESPACE_STANDBY" -l app=backend-service 2>/dev/null || true
    kubectl get pods -l app=haproxy 2>/dev/null || true
}

# Test service endpoints
test_service_endpoints() {
    print_header "Testing Service Endpoints"
    
    # Check hot cluster service
    if kubectl get svc -n "$NAMESPACE_HOT" backend-service &> /dev/null; then
        print_success "Hot cluster service exists"
        HOT_SVC_TYPE=$(kubectl get svc -n "$NAMESPACE_HOT" backend-service -o jsonpath='{.spec.type}' 2>/dev/null || echo "unknown")
        print_info "Hot cluster service type: $HOT_SVC_TYPE"
    else
        print_error "Hot cluster service does not exist"
    fi
    
    # Check standby cluster service
    if kubectl get svc -n "$NAMESPACE_STANDBY" backend-service &> /dev/null; then
        print_success "Standby cluster service exists"
        STANDBY_SVC_TYPE=$(kubectl get svc -n "$NAMESPACE_STANDBY" backend-service -o jsonpath='{.spec.type}' 2>/dev/null || echo "unknown")
        print_info "Standby cluster service type: $STANDBY_SVC_TYPE"
    else
        print_error "Standby cluster service does not exist"
    fi
    
    # Check HAProxy service
    if kubectl get svc haproxy &> /dev/null || kubectl get svc -l app=haproxy &> /dev/null; then
        print_success "HAProxy service exists"
    else
        print_error "HAProxy service does not exist"
    fi
}

# Test health endpoints via kubectl
test_health_endpoints() {
    print_header "Testing Health Endpoints"
    
    # Test hot cluster health
    print_info "Testing hot cluster health endpoint..."
    HOT_HEALTH=$(kubectl run test-health-hot-$(date +%s) --image=curlimages/curl:latest --restart=Never --rm -i -- \
        curl -s -f -w "\n%{http_code}" http://backend-service.$NAMESPACE_HOT.svc.cluster.local:80/healthz 2>/dev/null || echo "FAILED")
    
    if echo "$HOT_HEALTH" | grep -q "200"; then
        print_success "Hot cluster health endpoint is responding"
    else
        print_error "Hot cluster health endpoint failed"
        echo "$HOT_HEALTH" | head -5
    fi
    
    # Test standby cluster health
    print_info "Testing standby cluster health endpoint..."
    STANDBY_HEALTH=$(kubectl run test-health-standby-$(date +%s) --image=curlimages/curl:latest --restart=Never --rm -i -- \
        curl -s -f -w "\n%{http_code}" http://backend-service.$NAMESPACE_STANDBY.svc.cluster.local:80/healthz 2>/dev/null || echo "FAILED")
    
    if echo "$STANDBY_HEALTH" | grep -q "200"; then
        print_success "Standby cluster health endpoint is responding"
    else
        print_error "Standby cluster health endpoint failed"
        echo "$STANDBY_HEALTH" | head -5
    fi
}

# Test cluster role configuration
test_cluster_roles() {
    print_header "Testing Cluster Role Configuration"
    
    # Test hot cluster role
    print_info "Testing hot cluster role..."
    HOT_ROLE=$(kubectl run test-role-hot-$(date +%s) --image=curlimages/curl:latest --restart=Never --rm -i -- \
        curl -s http://backend-service.$NAMESPACE_HOT.svc.cluster.local:80/ 2>/dev/null | grep -o '"role":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    
    if [ "$HOT_ROLE" = "hot" ]; then
        print_success "Hot cluster role is correct: $HOT_ROLE"
    else
        print_error "Hot cluster role is incorrect: $HOT_ROLE (expected: hot)"
    fi
    
    # Test standby cluster role
    print_info "Testing standby cluster role..."
    STANDBY_ROLE=$(kubectl run test-role-standby-$(date +%s) --image=curlimages/curl:latest --restart=Never --rm -i -- \
        curl -s http://backend-service.$NAMESPACE_STANDBY.svc.cluster.local:80/ 2>/dev/null | grep -o '"role":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    
    if [ "$STANDBY_ROLE" = "standby" ]; then
        print_success "Standby cluster role is correct: $STANDBY_ROLE"
    else
        print_error "Standby cluster role is incorrect: $STANDBY_ROLE (expected: standby)"
    fi
}

# Test HAProxy (if accessible)
test_haproxy() {
    print_header "Testing HAProxy"
    
    # Check if HAProxy pod is running
    HAPROXY_POD=$(kubectl get pods -l app=haproxy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$HAPROXY_POD" ]; then
        print_error "HAProxy pod not found"
        return
    fi
    
    print_success "HAProxy pod found: $HAPROXY_POD"
    
    # Test HAProxy health via internal service
    print_info "Testing HAProxy health endpoint..."
    HAPROXY_SVC=$(kubectl get svc -l app=haproxy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "haproxy")
    
    HAPROXY_HEALTH=$(kubectl run test-haproxy-$(date +%s) --image=curlimages/curl:latest --restart=Never --rm -i -- \
        curl -s -f -w "\n%{http_code}" http://$HAPROXY_SVC:9090/healthz 2>/dev/null || echo "FAILED")
    
    if echo "$HAPROXY_HEALTH" | grep -q "200"; then
        print_success "HAProxy health endpoint is responding"
    else
        print_warning "HAProxy health endpoint test failed (may need port-forward)"
    fi
}

# Test via port-forward (for local access)
test_via_port_forward() {
    print_header "Testing via Port-Forward (Local Access)"
    
    # Check if Python requests is available
    if ! python3 -c "import requests" 2>/dev/null; then
        print_warning "Python requests not available, skipping port-forward tests"
        print_info "Install with: pip install requests"
        return
    fi
    
    print_info "Setting up port-forwards..."
    
    # Start port-forwards in background
    kubectl port-forward -n "$NAMESPACE_HOT" svc/backend-service 8080:80 > /tmp/port-forward-hot.log 2>&1 &
    PF_HOT_PID=$!
    
    kubectl port-forward -n "$NAMESPACE_STANDBY" svc/backend-service 8081:80 > /tmp/port-forward-standby.log 2>&1 &
    PF_STANDBY_PID=$!
    
    HAPROXY_SVC=$(kubectl get svc -l app=haproxy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$HAPROXY_SVC" ]; then
        kubectl port-forward svc/$HAPROXY_SVC 9090:9090 > /tmp/port-forward-haproxy.log 2>&1 &
        PF_HAPROXY_PID=$!
    else
        PF_HAPROXY_PID=""
    fi
    
    # Wait for port-forwards to be ready
    sleep 5
    
    # Verify port-forwards are working
    for i in {1..10}; do
        if curl -s -f http://localhost:8080/healthz > /dev/null 2>&1 && \
           curl -s -f http://localhost:8081/healthz > /dev/null 2>&1; then
            break
        fi
        sleep 1
    done
    
    # Test hot cluster
    print_info "Testing hot cluster via localhost:8080..."
    if curl -s -f http://localhost:8080/healthz > /dev/null 2>&1; then
        HOT_ROLE=$(curl -s http://localhost:8080/ 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin).get('role', 'unknown'))" 2>/dev/null || echo "unknown")
        if [ "$HOT_ROLE" = "hot" ]; then
            print_success "Hot cluster accessible and role correct via port-forward"
        else
            print_error "Hot cluster accessible but role incorrect: $HOT_ROLE"
        fi
    else
        print_error "Hot cluster not accessible via port-forward"
    fi
    
    # Test standby cluster
    print_info "Testing standby cluster via localhost:8081..."
    if curl -s -f http://localhost:8081/healthz > /dev/null 2>&1; then
        STANDBY_ROLE=$(curl -s http://localhost:8081/ 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin).get('role', 'unknown'))" 2>/dev/null || echo "unknown")
        if [ "$STANDBY_ROLE" = "standby" ]; then
            print_success "Standby cluster accessible and role correct via port-forward"
        else
            print_error "Standby cluster accessible but role incorrect: $STANDBY_ROLE"
        fi
    else
        print_error "Standby cluster not accessible via port-forward"
    fi
    
    # Test HAProxy
    print_info "Testing HAProxy via localhost:9090..."
    if curl -s -f http://localhost:9090/healthz > /dev/null 2>&1; then
        print_success "HAProxy accessible via port-forward"
        
        # Test HAProxy routing
        HAPROXY_ROLE=$(curl -s http://localhost:9090/ 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin).get('role', 'unknown'))" 2>/dev/null || echo "unknown")
        if [ "$HAPROXY_ROLE" = "hot" ]; then
            print_success "HAProxy routing to hot cluster correctly"
        else
            print_warning "HAProxy routing to: $HAPROXY_ROLE (expected: hot)"
        fi
    else
        print_error "HAProxy not accessible via port-forward"
    fi
    
    # Cleanup port-forwards
    print_info "Cleaning up port-forwards..."
    kill $PF_HOT_PID $PF_STANDBY_PID $PF_HAPROXY_PID 2>/dev/null || true
    sleep 2
}

# Print summary
print_summary() {
    print_header "Test Summary"
    
    TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
    echo -e "Total tests: $TOTAL_TESTS"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}✅ All tests passed!${NC}\n"
        return 0
    else
        echo -e "\n${RED}❌ Some tests failed${NC}\n"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║   Local Deployment Test Suite         ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_prerequisites
    test_pod_status
    test_service_endpoints
    test_health_endpoints
    test_cluster_roles
    test_haproxy
    test_via_port_forward
    print_summary
    
    exit $?
}

# Run main function
main


#!/bin/bash

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Accept optional context parameters
HOT_CONTEXT="${1:-}"
STANDBY_CONTEXT="${2:-}"
HAPROXY_CONTEXT="${3:-}"
DOCKER_IMAGE="${4:-mukul1599/backend-service}"
DOCKER_TAG="${5:-latest}"

# If contexts provided, use them; otherwise use default kubectl context
KUBECTL_CMD_HOT="kubectl"
KUBECTL_CMD_STANDBY="kubectl"
KUBECTL_CMD_HAPROXY="kubectl"

if [ -n "$HOT_CONTEXT" ]; then
    KUBECTL_CMD_HOT="kubectl --context=$HOT_CONTEXT"
    echo -e "${BLUE}Using hot cluster context: $HOT_CONTEXT${NC}"
fi

if [ -n "$STANDBY_CONTEXT" ]; then
    KUBECTL_CMD_STANDBY="kubectl --context=$STANDBY_CONTEXT"
    echo -e "${BLUE}Using standby cluster context: $STANDBY_CONTEXT${NC}"
fi

if [ -n "$HAPROXY_CONTEXT" ]; then
    KUBECTL_CMD_HAPROXY="kubectl --context=$HAPROXY_CONTEXT"
    echo -e "${BLUE}Using HAProxy cluster context: $HAPROXY_CONTEXT${NC}"
fi

echo -e "${BLUE}Starting deployment...${NC}"
echo -e "${BLUE}Docker Image: $DOCKER_IMAGE:$DOCKER_TAG${NC}"
echo ""

# Function to check if resource exists
check_resource() {
    local resource=$1
    local namespace=$2
    if kubectl get "$resource" -n "$namespace" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local selector=$2
    local timeout=${3:-120}
    
    echo -e "${YELLOW}Waiting for pods with selector '$selector' in namespace '$namespace'...${NC}"
    if kubectl wait --for=condition=ready --timeout=${timeout}s pod -l "$selector" -n "$namespace" 2>/dev/null; then
        echo -e "${GREEN}Pods are ready${NC}"
        return 0
    else
        echo -e "${YELLOW}WARNING: Some pods may not be ready yet${NC}"
        return 1
    fi
}

# ============================================================================
# Step 1: Deploy Monitoring Namespace
# ============================================================================
echo -e "${BLUE}Step 1: Deploying monitoring namespace...${NC}"
kubectl apply -f monitoring/namespace.yaml
echo -e "${GREEN}SUCCESS: Monitoring namespace created${NC}"
echo ""

# ============================================================================
# Step 2: Deploy Prometheus
# ============================================================================
echo -e "${BLUE}Step 2: Deploying Prometheus...${NC}"
kubectl apply -f monitoring/prometheus/serviceaccount.yaml
kubectl apply -f monitoring/prometheus/configmap.yaml
kubectl apply -f monitoring/prometheus/deployment.yaml
kubectl apply -f monitoring/prometheus/service.yaml
echo -e "${GREEN}SUCCESS: Prometheus deployed${NC}"
echo ""

# ============================================================================
# Step 2.5: Deploy kube-state-metrics
# ============================================================================
echo -e "${BLUE}Step 2.5: Deploying kube-state-metrics...${NC}"
kubectl apply -f monitoring/kube-state-metrics/serviceaccount.yaml
kubectl apply -f monitoring/kube-state-metrics/deployment.yaml
kubectl apply -f monitoring/kube-state-metrics/service.yaml

# Wait for kube-state-metrics to be ready
wait_for_pods "monitoring" "app.kubernetes.io/name=kube-state-metrics" 120

echo -e "${GREEN}SUCCESS: kube-state-metrics deployed and ready${NC}"
echo ""

# ============================================================================
# Step 3: Deploy Grafana
# ============================================================================
echo -e "${BLUE}Step 3: Deploying Grafana...${NC}"
kubectl apply -f monitoring/grafana/configmap-datasources.yaml
kubectl apply -f monitoring/grafana/deployment.yaml
kubectl apply -f monitoring/grafana/service.yaml
echo -e "${GREEN}SUCCESS: Grafana deployed${NC}"
echo ""

# ============================================================================
# Step 4: Deploy Hot Cluster
# ============================================================================
echo -e "${BLUE}Step 4: Deploying Hot Cluster...${NC}"
$KUBECTL_CMD_HOT apply -f k8s/cluster-hot/configmap.yaml
sed "s|image: mukul1599/backend-service$|image: $DOCKER_IMAGE:$DOCKER_TAG|" k8s/cluster-hot/deployment.yaml | $KUBECTL_CMD_HOT apply -f -
$KUBECTL_CMD_HOT apply -f k8s/cluster-hot/service.yaml
$KUBECTL_CMD_HOT apply -f k8s/cluster-hot/network-policy.yaml
echo -e "${GREEN}SUCCESS: Hot cluster deployed${NC}"
echo ""

# ============================================================================
# Step 5: Deploy Standby Cluster
# ============================================================================
echo -e "${BLUE}Step 5: Deploying Standby Cluster...${NC}"
$KUBECTL_CMD_STANDBY apply -f k8s/cluster-standby/configmap.yaml
sed "s|image: mukul1599/backend-service$|image: $DOCKER_IMAGE:$DOCKER_TAG|" k8s/cluster-standby/deployment.yaml | $KUBECTL_CMD_STANDBY apply -f -
$KUBECTL_CMD_STANDBY apply -f k8s/cluster-standby/service.yaml
$KUBECTL_CMD_STANDBY apply -f k8s/cluster-standby/network-policy.yaml
echo -e "${GREEN}SUCCESS: Standby cluster deployed${NC}"
echo ""

# ============================================================================
# Step 6: Wait for services to get IPs
# ============================================================================
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 5

# Wait for backend pods to be ready
if [ -n "$HOT_CONTEXT" ]; then
    $KUBECTL_CMD_HOT wait --for=condition=ready --timeout=120s pod -l app=backend-service-hot -n default 2>/dev/null || true
else
    wait_for_pods "default" "app=backend-service-hot" 120
fi

if [ -n "$STANDBY_CONTEXT" ]; then
    $KUBECTL_CMD_STANDBY wait --for=condition=ready --timeout=120s pod -l "app=backend-service,cluster=standby" -n default 2>/dev/null || true
else
    wait_for_pods "default" "app=backend-service,cluster=standby" 120
fi

# ============================================================================
# Step 6.5: Get Service IPs and Deploy HAProxy (Internal Only)
# ============================================================================
echo -e "${BLUE}Step 6.5: Deploying HAProxy (Internal Only - ClusterIP)...${NC}"

# Get service ClusterIPs
HOT_IP=$($KUBECTL_CMD_HOT get svc backend-service-hot -n default -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
STANDBY_IP=$($KUBECTL_CMD_STANDBY get svc backend-service -n default -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")

if [ -z "$HOT_IP" ] || [ -z "$STANDBY_IP" ]; then
    echo -e "${RED}ERROR: Could not get service IPs${NC}"
    echo "Hot IP: $HOT_IP"
    echo "Standby IP: $STANDBY_IP"
    exit 1
fi

echo -e "${GREEN}Hot cluster IP: ${HOT_IP}:80${NC}"
echo -e "${GREEN}Standby cluster IP: ${STANDBY_IP}:80${NC}"

# Update HAProxy config with actual IPs
sed "s|<HOT_CLUSTER_EXTERNAL_IP>|${HOT_IP}:80|g" k8s/haproxy/configmap.yaml | \
  sed "s|<STANDBY_CLUSTER_EXTERNAL_IP>|${STANDBY_IP}:80|g" | \
  $KUBECTL_CMD_HAPROXY apply -f -

$KUBECTL_CMD_HAPROXY apply -f k8s/haproxy/deployment.yaml
$KUBECTL_CMD_HAPROXY apply -f k8s/haproxy/service.yaml
$KUBECTL_CMD_HAPROXY apply -f k8s/haproxy/network-policy.yaml

echo -e "${GREEN}SUCCESS: HAProxy deployed (ClusterIP - internal only)${NC}"
echo -e "${BLUE}   Note: HAProxy is NOT exposed externally. All traffic must go through WAF.${NC}"
echo ""

# Wait for HAProxy to be ready
echo -e "${YELLOW}Waiting for HAProxy to be ready...${NC}"
if [ -n "$HAPROXY_CONTEXT" ]; then
    $KUBECTL_CMD_HAPROXY wait --for=condition=ready --timeout=60s pod -l app=haproxy -n default 2>/dev/null || true
else
    wait_for_pods "default" "app=haproxy" 60
fi

# ============================================================================
# Step 7: Deploy ModSecurity WAF (Public Entry Point)
# ============================================================================
echo -e "${BLUE}Step 7: Deploying ModSecurity WAF (Public Entry Point)...${NC}"

# Get HAProxy ClusterIP for WAF configuration
HAPROXY_CLUSTER_IP=$($KUBECTL_CMD_HAPROXY get svc haproxy -n default -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")

if [ -z "$HAPROXY_CLUSTER_IP" ]; then
    echo -e "${RED}ERROR: Could not get HAProxy ClusterIP${NC}"
    echo -e "${YELLOW}Waiting for HAProxy service to be ready...${NC}"
    sleep 5
    HAPROXY_CLUSTER_IP=$($KUBECTL_CMD_HAPROXY get svc haproxy -n default -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
    if [ -z "$HAPROXY_CLUSTER_IP" ]; then
        echo -e "${RED}ERROR: HAProxy ClusterIP still not available${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}HAProxy ClusterIP: ${HAPROXY_CLUSTER_IP}:9090${NC}"

# Deploy ModSecurity WAF ConfigMaps first
$KUBECTL_CMD_HAPROXY apply -f k8s/waf/configmap-modsecurity.yaml

# Update WAF nginx config with HAProxy ClusterIP (DNS resolution is unreliable)
echo -e "${BLUE}Configuring WAF to proxy to HAProxy via ClusterIP (${HAPROXY_CLUSTER_IP})${NC}"
sed "s|<HAPROXY_CLUSTER_IP>|${HAPROXY_CLUSTER_IP}|g" k8s/waf/configmap-nginx.yaml | \
  $KUBECTL_CMD_HAPROXY apply -f -
$KUBECTL_CMD_HAPROXY apply -f k8s/waf/deployment.yaml

$KUBECTL_CMD_HAPROXY apply -f k8s/waf/service.yaml
$KUBECTL_CMD_HAPROXY apply -f k8s/waf/network-policy.yaml

echo -e "${GREEN}SUCCESS: ModSecurity WAF manifests applied${NC}"
echo ""

# Wait for WAF pods to be ready with retry logic
echo -e "${YELLOW}Waiting for WAF pods to be ready...${NC}"
MAX_RETRIES=5
RETRY_COUNT=0
WAF_READY=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if [ -n "$HAPROXY_CONTEXT" ]; then
        if $KUBECTL_CMD_HAPROXY wait --for=condition=ready --timeout=30s pod -l app=modsecurity-waf -n default 2>/dev/null; then
            WAF_READY=true
            break
        fi
    else
        if wait_for_pods "default" "app=modsecurity-waf" 30; then
            WAF_READY=true
            break
        fi
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -e "${YELLOW}WARNING: WAF pods not ready yet, retrying... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
    
    # Check for pod errors
    FAILED_PODS=$($KUBECTL_CMD_HAPROXY get pods -l app=modsecurity-waf -n default -o jsonpath='{.items[?(@.status.phase!="Running")].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$FAILED_PODS" ]; then
        echo -e "${YELLOW}Checking pod status...${NC}"
        $KUBECTL_CMD_HAPROXY get pods -l app=modsecurity-waf -n default 2>/dev/null || true
        echo -e "${YELLOW}Checking pod logs for errors...${NC}"
        for pod in $FAILED_PODS; do
            echo -e "${YELLOW}Pod $pod logs:${NC}"
            $KUBECTL_CMD_HAPROXY logs $pod -n default --tail=10 2>/dev/null || true
        done
    fi
    
    sleep 5
done

if [ "$WAF_READY" = true ]; then
    echo -e "${GREEN}SUCCESS: ModSecurity WAF pods are ready${NC}"
    
    # Verify WAF pods are actually running (not crashing)
    CRASHING_PODS=$($KUBECTL_CMD_HAPROXY get pods -l app=modsecurity-waf -n default -o jsonpath='{.items[?(@.status.containerStatuses[0].ready==false)].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$CRASHING_PODS" ]; then
        echo -e "${RED}ERROR: Warning: Some WAF pods are not ready${NC}"
        $KUBECTL_CMD_HAPROXY get pods -l app=modsecurity-waf -n default 2>/dev/null || true
    else
        echo -e "${GREEN}SUCCESS: All WAF pods are running successfully${NC}"
    fi
else
    echo -e "${RED}ERROR: Warning: WAF pods did not become ready after $MAX_RETRIES attempts${NC}"
    echo -e "${YELLOW}Checking WAF pod status...${NC}"
    $KUBECTL_CMD_HAPROXY get pods -l app=modsecurity-waf -n default 2>/dev/null || true
    echo -e "${YELLOW}This may be normal if WAF is still starting up. Continuing deployment...${NC}"
fi
echo ""

# ============================================================================
# Step 7.5: Verify Prometheus can query kube-state-metrics
# ============================================================================
echo -e "${BLUE}Step 7.5: Verifying Prometheus metrics...${NC}"
echo -e "${YELLOW}Waiting for Prometheus to discover kube-state-metrics...${NC}"
sleep 10

# Wait for Prometheus to be ready
wait_for_pods "monitoring" "app=prometheus" 60

# Verify kube-state-metrics query works
PROM_POD=$(kubectl get pod -n monitoring -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$PROM_POD" ]; then
    echo -e "${YELLOW}Testing Prometheus query for kube-state-metrics...${NC}"
    QUERY_RESULT=$(kubectl exec -n monitoring "$PROM_POD" -- wget -qO- 'http://localhost:9090/api/v1/query?query=kube_pod_container_resource_requests{resource="cpu"}' 2>/dev/null | python3 -c "import sys, json; data=json.load(sys.stdin); print('success' if data.get('status')=='success' and len(data.get('data',{}).get('result',[])) > 0 else 'failed')" 2>/dev/null || echo "failed")
    
    if [ "$QUERY_RESULT" = "success" ]; then
        echo -e "${GREEN}SUCCESS: Prometheus can query kube-state-metrics successfully${NC}"
    else
        echo -e "${YELLOW}WARNING: Prometheus query test inconclusive (may need more time to scrape)${NC}"
    fi
else
    echo -e "${YELLOW}WARNING: Prometheus pod not found, skipping query verification${NC}"
fi
echo ""

# ============================================================================
# Step 8: Display Status
# ============================================================================
echo -e "${BLUE}Deployment Status:${NC}"
echo ""

echo -e "${YELLOW}Backend Services:${NC}"
$KUBECTL_CMD_HOT get pods -n default -l app=backend-service 2>/dev/null || echo "Hot cluster pods not found"
$KUBECTL_CMD_STANDBY get pods -n default -l app=backend-service 2>/dev/null || echo "Standby cluster pods not found"
echo ""

echo -e "${YELLOW}HAProxy:${NC}"
$KUBECTL_CMD_HAPROXY get pods -n default -l app=haproxy 2>/dev/null || echo "HAProxy pods not found"
echo ""

echo -e "${YELLOW}Monitoring:${NC}"
kubectl get pods -n monitoring
echo ""

echo -e "${YELLOW}Services:${NC}"
$KUBECTL_CMD_HOT get svc -n default | grep -E "backend-service|haproxy" || true
$KUBECTL_CMD_STANDBY get svc -n default | grep -E "backend-service" || true
$KUBECTL_CMD_HAPROXY get svc -n default | grep -E "haproxy" || true
kubectl get svc -n monitoring
echo ""

# ============================================================================
# Step 9: Port Forwarding Instructions
# ============================================================================
echo -e "${GREEN}SUCCESS: Deployment complete!${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Access Instructions:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Option 1: Port Forwarding (Recommended)${NC}"
echo "Run these commands in separate terminals:"
echo ""
echo -e "${GREEN}# Terminal 1: ModSecurity WAF (Public Entry Point)${NC}"
echo "  kubectl port-forward -n default svc/modsecurity-waf 8080:80"
echo "  → Access at: http://localhost:8080"
echo "  → All traffic goes: WAF → HAProxy → Backend Clusters"
echo "  → Note: HAProxy is internal-only (ClusterIP), not directly accessible"
echo ""
echo -e "${GREEN}# Terminal 2: Grafana${NC}"
echo "  kubectl port-forward -n monitoring svc/grafana 3000:3000"
echo "  → Access at: http://localhost:3000"
echo "  → Username: admin"
echo "  → Password: admin"
echo ""
echo -e "${GREEN}# Terminal 3: Prometheus${NC}"
echo "  kubectl port-forward -n monitoring svc/prometheus 9091:9090"
echo "  → Access at: http://localhost:9091"
echo "  → Test query: sum(kube_pod_container_resource_requests{resource=\"cpu\"}) by (pod, namespace)"
echo ""
echo -e "${YELLOW}Option 2: NodePort (if available)${NC}"
echo "  WAF:        http://<node-ip>:30080"
echo "  Grafana:    http://<node-ip>:30300"
echo "  Prometheus: http://<node-ip>:30091"
echo ""
echo -e "${BLUE}Architecture: User → WAF (port 8080) → HAProxy (internal) → Backend Clusters${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ============================================================================
# Auto-start port forwarding for WAF
# ============================================================================
# Kill any existing port-forward on port 8080
pkill -f "kubectl port-forward.*modsecurity-waf.*8080" 2>/dev/null || true
sleep 1

# Start port-forward in background
echo -e "${BLUE}Starting port forward for WAF on port 8080 (background)...${NC}"
$KUBECTL_CMD_HAPROXY port-forward -n default svc/modsecurity-waf 8080:80 --address=127.0.0.1 > /tmp/waf-portforward.log 2>&1 &
PF_PID=$!

# Wait a moment for port-forward to initialize
sleep 2

# Verify port-forward is working
if kill -0 $PF_PID 2>/dev/null; then
    # Test connection
    if curl -s -f http://127.0.0.1:8080/waf-health > /dev/null 2>&1; then
        echo -e "${GREEN}SUCCESS: Port-forward active on http://localhost:8080${NC}"
        echo -e "${BLUE}Access your application at: http://localhost:8080${NC}"
        echo -e "${BLUE}Traffic flow: WAF → HAProxy → Backend Clusters${NC}"
    else
        echo -e "${YELLOW}WARNING: Port-forward started but connection test failed${NC}"
        echo -e "${YELLOW}Port-forward may still be initializing. Check logs: cat /tmp/waf-portforward.log${NC}"
    fi
else
    echo -e "${RED}ERROR: Port-forward failed to start${NC}"
    echo -e "${YELLOW}Check logs: cat /tmp/waf-portforward.log${NC}"
fi
echo ""

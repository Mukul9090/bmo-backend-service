#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Accept optional context parameters
HOT_CONTEXT="${1:-}"
STANDBY_CONTEXT="${2:-}"
HAPROXY_CONTEXT="${3:-}"

# If contexts provided, use them; otherwise use default kubectl context
KUBECTL_CMD_HOT="kubectl"
KUBECTL_CMD_STANDBY="kubectl"
KUBECTL_CMD_HAPROXY="kubectl"

if [ -n "$HOT_CONTEXT" ]; then
    KUBECTL_CMD_HOT="kubectl --context=$HOT_CONTEXT"
fi

if [ -n "$STANDBY_CONTEXT" ]; then
    KUBECTL_CMD_STANDBY="kubectl --context=$STANDBY_CONTEXT"
fi

if [ -n "$HAPROXY_CONTEXT" ]; then
    KUBECTL_CMD_HAPROXY="kubectl --context=$HAPROXY_CONTEXT"
fi

echo -e "${YELLOW}🧹 Cleaning up all deployments...${NC}"
echo ""

# Stop any running port forwards
echo -e "${BLUE}Stopping port forwards...${NC}"
pkill -f "kubectl port-forward" || true
pkill -f "keep-haproxy-forward" || true
sleep 2

# Delete HAProxy
echo -e "${BLUE}Deleting HAProxy...${NC}"
$KUBECTL_CMD_HAPROXY delete deployment haproxy -n default --ignore-not-found=true || true
$KUBECTL_CMD_HAPROXY delete service haproxy -n default --ignore-not-found=true || true
$KUBECTL_CMD_HAPROXY delete configmap haproxy-config -n default --ignore-not-found=true || true
$KUBECTL_CMD_HAPROXY delete networkpolicy haproxy-network-policy -n default --ignore-not-found=true || true

# Delete backend clusters
echo -e "${BLUE}Deleting backend clusters...${NC}"
$KUBECTL_CMD_HOT delete deployment backend-service-hot -n default --ignore-not-found=true || true
$KUBECTL_CMD_HOT delete deployment backend-service -n default --ignore-not-found=true || true
$KUBECTL_CMD_HOT delete service backend-service-hot -n default --ignore-not-found=true || true
$KUBECTL_CMD_HOT delete service backend-service -n default --ignore-not-found=true || true
$KUBECTL_CMD_HOT delete configmap backend-config-hot -n default --ignore-not-found=true || true
$KUBECTL_CMD_HOT delete configmap backend-config -n default --ignore-not-found=true || true
$KUBECTL_CMD_HOT delete networkpolicy backend-network-policy -n default --ignore-not-found=true || true
$KUBECTL_CMD_HOT delete horizontalpodautoscaler backend-hot-hpa -n default --ignore-not-found=true || true

$KUBECTL_CMD_STANDBY delete deployment backend-service -n default --ignore-not-found=true || true
$KUBECTL_CMD_STANDBY delete deployment backend-service-standby -n default --ignore-not-found=true || true
$KUBECTL_CMD_STANDBY delete service backend-service -n default --ignore-not-found=true || true
$KUBECTL_CMD_STANDBY delete configmap backend-config-standby -n default --ignore-not-found=true || true
$KUBECTL_CMD_STANDBY delete configmap backend-config -n default --ignore-not-found=true || true
$KUBECTL_CMD_STANDBY delete networkpolicy backend-network-policy -n default --ignore-not-found=true || true
$KUBECTL_CMD_STANDBY delete horizontalpodautoscaler backend-hpa -n default --ignore-not-found=true || true

# Delete monitoring (use default context for monitoring namespace)
echo -e "${BLUE}Deleting monitoring stack...${NC}"
kubectl delete -f monitoring/grafana/ --ignore-not-found=true || true
kubectl delete -f monitoring/prometheus/ --ignore-not-found=true || true
kubectl delete -f monitoring/kube-state-metrics/ --ignore-not-found=true || true
kubectl delete -f monitoring/loki/ --ignore-not-found=true || true
kubectl delete -f monitoring/promtail/ --ignore-not-found=true || true
kubectl delete -f monitoring/namespace.yaml --ignore-not-found=true || true

# Wait for resources to be deleted
echo -e "${YELLOW}Waiting for resources to be deleted...${NC}"
sleep 5

echo -e "${GREEN}✅ Cleanup complete!${NC}"

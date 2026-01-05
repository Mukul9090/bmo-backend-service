#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📡 Starting port forwarding for all services...${NC}"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop all port forwards${NC}"
echo ""

# Function to handle cleanup on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}Stopping all port forwards...${NC}"
    pkill -f "kubectl port-forward" || true
    exit 0
}

trap cleanup SIGINT SIGTERM

# Start port forwards in background
echo -e "${GREEN}Starting HAProxy on port 9090...${NC}"
kubectl port-forward -n default svc/haproxy 9090:9090 > /tmp/haproxy-portforward.log 2>&1 &
HAPROXY_PID=$!

sleep 2

echo -e "${GREEN}Starting Grafana on port 3000...${NC}"
kubectl port-forward -n monitoring svc/grafana 3000:3000 > /tmp/grafana-portforward.log 2>&1 &
GRAFANA_PID=$!

sleep 2

echo -e "${GREEN}Starting Prometheus on port 9091...${NC}"
kubectl port-forward -n monitoring svc/prometheus 9091:9090 > /tmp/prometheus-portforward.log 2>&1 &
PROMETHEUS_PID=$!

sleep 2

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}✅ Port forwarding active!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}HAProxy:    http://localhost:9090${NC}"
echo -e "${GREEN}Grafana:    http://localhost:3000 (admin/admin)${NC}"
echo -e "${GREEN}Prometheus: http://localhost:9091${NC}"
echo ""
echo -e "${YELLOW}Port forwards are running in the background.${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop all port forwards.${NC}"
echo ""

# Wait for all background processes
wait $HAPROXY_PID $GRAFANA_PID $PROMETHEUS_PID

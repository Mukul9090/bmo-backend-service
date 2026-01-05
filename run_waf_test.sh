#!/bin/bash

# WAF Test Runner Script
# Automatically sets up port-forward and runs WAF security tests
# Usage: ./run_waf_test.sh [context]
#   context: Optional kubectl context name (defaults to current context)

set -e

# Accept optional context parameter
KUBECTL_CONTEXT="${1:-}"

# Set up kubectl command with optional context
if [ -n "$KUBECTL_CONTEXT" ]; then
    KUBECTL_CMD="kubectl --context=$KUBECTL_CONTEXT"
    echo "Using kubectl context: $KUBECTL_CONTEXT"
else
    KUBECTL_CMD="kubectl"
    echo "Using default kubectl context"
fi

# Cleanup function
cleanup() {
    if [ -n "$PF_PID" ]; then
        kill $PF_PID 2>/dev/null || true
        wait $PF_PID 2>/dev/null || true
    fi
    rm -f /tmp/test_waf_local.py
}
trap cleanup EXIT

echo "Setting up port-forward for WAF service..."

# Initialize variables
SERVICE_EXISTS=false
SERVICE_NAMESPACE="default"

# Check if service exists in default namespace
if $KUBECTL_CMD get svc modsecurity-waf -n default &>/dev/null; then
    SERVICE_EXISTS=true
    SERVICE_NAMESPACE="default"
else
    # Check other namespaces
    for ns in $($KUBECTL_CMD get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
        if $KUBECTL_CMD get svc modsecurity-waf -n "$ns" &>/dev/null; then
            SERVICE_EXISTS=true
            SERVICE_NAMESPACE="$ns"
            break
        fi
    done
fi

# Kill any existing port-forwards on port 8080
lsof -ti:8080 | xargs kill -9 2>/dev/null || true
sleep 1

# Start port-forward
$KUBECTL_CMD port-forward -n "$SERVICE_NAMESPACE" svc/modsecurity-waf 8080:80 > /tmp/waf-portforward.log 2>&1 &
PF_PID=$!

# Wait for port-forward to be ready
sleep 2

# Check if port-forward process is running
if ! kill -0 $PF_PID 2>/dev/null; then
    echo "ERROR: Port-forward process failed to start"
    cat /tmp/waf-portforward.log 2>/dev/null || true
    exit 1
fi

# Try to connect with retries
echo "Waiting for port-forward to be ready..."
MAX_RETRIES=10
RETRY_COUNT=0
PORT_READY=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # Try root endpoint first (most likely to work)
    if curl -s -f http://localhost:8080/ > /dev/null 2>&1; then
        PORT_READY=true
        break
    fi
    # Try health endpoint
    if curl -s -f http://localhost:8080/waf-health > /dev/null 2>&1; then
        PORT_READY=true
        break
    fi
    # Try healthz endpoint
    if curl -s -f http://localhost:8080/healthz > /dev/null 2>&1; then
        PORT_READY=true
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 1
done

if [ "$PORT_READY" = false ]; then
    echo "ERROR: Port-forward failed to connect after $MAX_RETRIES attempts"
    echo "Port-forward log:"
    cat /tmp/waf-portforward.log 2>/dev/null || true
    echo ""
    echo "Check if WAF service is running:"
    $KUBECTL_CMD get svc modsecurity-waf -n default
    echo ""
    echo "Check if WAF pods are running:"
    $KUBECTL_CMD get pods -l app=modsecurity-waf -n default
    exit 1
fi

echo "SUCCESS: Port-forward active on localhost:8080"
echo ""
echo "Running WAF security tests..."
echo ""

# Run the test with WAF_URL environment variable set
WAF_URL="http://localhost:8080" python3 test_waf.py

# Cleanup is handled by trap
echo ""
echo "SUCCESS: Test complete! Check ModSecurity logs with:"
echo "   $KUBECTL_CMD exec -n default deployment/modsecurity-waf -- tail -100 /var/log/modsec_audit.log"

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

# Debug logging function
log_debug() {
    local hypothesis_id="$1"
    local location="$2"
    local message="$3"
    local data="$4"
    local timestamp=$(date +%s%3N)
    echo "{\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"$hypothesis_id\",\"location\":\"$location\",\"message\":\"$message\",\"data\":$data,\"timestamp\":$timestamp}" >> /Users/mukul/Desktop/HAproxytest/BMO/.cursor/debug.log
}

# Cleanup function
cleanup() {
    if [ -n "$PF_PID" ]; then
        kill $PF_PID 2>/dev/null || true
        wait $PF_PID 2>/dev/null || true
    fi
    rm -f /tmp/test_waf_local.py
}
trap cleanup EXIT

echo "🔧 Setting up port-forward for WAF service..."

# #region agent log
CURRENT_CTX=$($KUBECTL_CMD config current-context 2>/dev/null || echo "none")
log_debug "H3" "run_waf_test.sh:28" "Current kubectl context" "{\"context\":\"$CURRENT_CTX\"}"
# #endregion

# Initialize variables
SERVICE_EXISTS=false
SERVICE_NAMESPACE="default"

# #region agent log
log_debug "H1,H4" "run_waf_test.sh:34" "Checking if WAF service exists before port-forward" "{\"namespace\":\"default\",\"service\":\"modsecurity-waf\"}"
# #endregion

# Check if service exists in default namespace (H1, H4)
if $KUBECTL_CMD get svc modsecurity-waf -n default &>/dev/null; then
    # #region agent log
    log_debug "H1,H4" "run_waf_test.sh:28" "WAF service exists in default namespace" "{\"service\":\"modsecurity-waf\",\"namespace\":\"default\"}"
    # #endregion
    SERVICE_EXISTS=true
    SERVICE_NAMESPACE="default"
else
    # #region agent log
    log_debug "H1,H4" "run_waf_test.sh:34" "WAF service NOT found in default namespace" "{\"service\":\"modsecurity-waf\",\"namespace\":\"default\"}"
    # #endregion
    
    # #region agent log
    ALL_SERVICES=$($KUBECTL_CMD get svc -n default -o json 2>/dev/null | jq -r '.items[].metadata.name' 2>/dev/null | tr '\n' ',' || echo "error")
    log_debug "H2" "run_waf_test.sh:48" "All services in default namespace" "{\"services\":\"$ALL_SERVICES\"}"
    # #endregion
    
    # #region agent log
    ALL_NAMESPACES=$($KUBECTL_CMD get namespaces -o json 2>/dev/null | jq -r '.items[].metadata.name' 2>/dev/null | tr '\n' ',' || echo "error")
    log_debug "H2" "run_waf_test.sh:52" "All namespaces" "{\"namespaces\":\"$ALL_NAMESPACES\"}"
    # #endregion
    
    # Check other namespaces (H2)
    for ns in $($KUBECTL_CMD get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
        if $KUBECTL_CMD get svc modsecurity-waf -n "$ns" &>/dev/null; then
            # #region agent log
            log_debug "H2" "run_waf_test.sh:48" "WAF service found in different namespace" "{\"service\":\"modsecurity-waf\",\"namespace\":\"$ns\"}"
            # #endregion
            SERVICE_EXISTS=true
            SERVICE_NAMESPACE="$ns"
            break
        fi
    done
    
    # #region agent log
    WAF_DEPLOYMENT=$($KUBECTL_CMD get deployment modsecurity-waf -n default -o json 2>/dev/null | jq -r '.metadata.name // "not_found"' || echo "error")
    log_debug "H1" "run_waf_test.sh:67" "WAF deployment status" "{\"deployment\":\"$WAF_DEPLOYMENT\",\"namespace\":\"default\"}"
    # #endregion
    
    # #region agent log
    WAF_PODS=$($KUBECTL_CMD get pods -l app=modsecurity-waf -n default -o json 2>/dev/null | jq -r '.items | length' || echo "error")
    log_debug "H1" "run_waf_test.sh:71" "WAF pods count" "{\"pod_count\":\"$WAF_PODS\",\"namespace\":\"default\"}"
    # #endregion
fi

# Kill any existing port-forwards on port 8080
lsof -ti:8080 | xargs kill -9 2>/dev/null || true
sleep 1

# #region agent log
log_debug "H3" "run_waf_test.sh:68" "Attempting port-forward" "{\"namespace\":\"$SERVICE_NAMESPACE\",\"service\":\"modsecurity-waf\",\"context\":\"$CURRENT_CTX\",\"service_exists\":\"$SERVICE_EXISTS\"}"
# #endregion

# Start port-forward
$KUBECTL_CMD port-forward -n "$SERVICE_NAMESPACE" svc/modsecurity-waf 8080:80 > /tmp/waf-portforward.log 2>&1 &
PF_PID=$!

# #region agent log
log_debug "H1,H4" "run_waf_test.sh:75" "Port-forward process started" "{\"pid\":\"$PF_PID\"}"
# #endregion

# Wait for port-forward to be ready (check process first)
sleep 2

# Check if port-forward process is running
if ! kill -0 $PF_PID 2>/dev/null; then
    # #region agent log
    PORT_FORWARD_ERROR=$(cat /tmp/waf-portforward.log 2>/dev/null || echo "no_log_file")
    log_debug "H1,H4" "run_waf_test.sh:85" "Port-forward process failed" "{\"pid\":\"$PF_PID\",\"error\":\"$PORT_FORWARD_ERROR\"}"
    # #endregion
    echo "❌ Port-forward process failed to start"
    cat /tmp/waf-portforward.log 2>/dev/null || true
    exit 1
fi

# Try to connect with retries
echo "⏳ Waiting for port-forward to be ready..."
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
    echo "❌ Port-forward failed to connect after $MAX_RETRIES attempts"
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

echo "✅ Port-forward active on localhost:8080"
echo ""
echo "🚀 Running WAF security tests..."
echo ""

# Run the test with WAF_URL environment variable set
WAF_URL="http://localhost:8080" python3 test_waf.py

# Cleanup is handled by trap
echo ""
echo "✅ Test complete! Check ModSecurity logs with:"
echo "   $KUBECTL_CMD exec -n default deployment/modsecurity-waf -- tail -100 /var/log/modsec_audit.log"

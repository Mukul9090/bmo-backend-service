#!/bin/bash
# Diagnostic script for Prometheus kube-state-metrics issue

LOG_FILE="/Users/mukul/Desktop/HAproxytest/BMO/.cursor/debug.log"

log() {
    local hypothesis_id=$1
    local location=$2
    local message=$3
    local data=$4
    echo "{\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"$hypothesis_id\",\"location\":\"$location\",\"message\":\"$message\",\"data\":$data,\"timestamp\":$(date +%s000)}" >> "$LOG_FILE"
}

echo "🔍 Diagnosing Prometheus kube-state-metrics issue..."

# Hypothesis A: kube-state-metrics pod doesn't exist
log "A" "diagnose_prometheus.sh:check_pods" "Checking for kube-state-metrics pods" "{\"checking\":\"pods\"}"
KSM_PODS=$(kubectl get pods -A -l app.kubernetes.io/name=kube-state-metrics --no-headers 2>/dev/null | wc -l | tr -d ' ')
log "A" "diagnose_prometheus.sh:pod_count" "kube-state-metrics pod count" "{\"count\":$KSM_PODS}"

# Hypothesis B: kube-state-metrics service doesn't exist
log "B" "diagnose_prometheus.sh:check_svc" "Checking for kube-state-metrics service" "{\"checking\":\"service\"}"
KSM_SVC=$(kubectl get svc -A -l app.kubernetes.io/name=kube-state-metrics --no-headers 2>/dev/null | wc -l | tr -d ' ')
log "B" "diagnose_prometheus.sh:svc_count" "kube-state-metrics service count" "{\"count\":$KSM_SVC}"

# Hypothesis C: Prometheus config doesn't scrape kube-state-metrics
log "C" "diagnose_prometheus.sh:check_config" "Checking Prometheus config for kube-state-metrics scrape config" "{\"checking\":\"config\"}"
PROM_CONFIG=$(kubectl get configmap prometheus-config -n monitoring -o jsonpath='{.data.prometheus\.yml}' 2>/dev/null)
KSM_IN_CONFIG=$(echo "$PROM_CONFIG" | grep -c "kube-state-metrics" || echo "0")
log "C" "diagnose_prometheus.sh:config_check" "kube-state-metrics in Prometheus config" "{\"found\":$KSM_IN_CONFIG}"

# Hypothesis D: Prometheus can't reach kube-state-metrics endpoint
log "D" "diagnose_prometheus.sh:check_endpoint" "Checking if kube-state-metrics endpoint is accessible" "{\"checking\":\"endpoint\"}"
KSM_ENDPOINT=$(kubectl get endpoints -A -l app.kubernetes.io/name=kube-state-metrics -o jsonpath='{.items[0].subsets[0].addresses[0].ip}:{.items[0].subsets[0].ports[0].port}' 2>/dev/null || echo "not-found")
log "D" "diagnose_prometheus.sh:endpoint" "kube-state-metrics endpoint" "{\"endpoint\":\"$KSM_ENDPOINT\"}"

# Hypothesis E: Prometheus targets show kube-state-metrics as down
log "E" "diagnose_prometheus.sh:check_targets" "Checking Prometheus targets status" "{\"checking\":\"targets\"}"
# Try to get Prometheus targets via port-forward
pkill -f "kubectl port-forward.*prometheus" 2>/dev/null || true
kubectl port-forward -n monitoring svc/prometheus 9091:9090 > /dev/null 2>&1 &
PF_PID=$!
sleep 3
TARGETS_JSON=$(curl -s http://localhost:9091/api/v1/targets 2>/dev/null || echo "{}")
KSM_TARGET_STATUS=$(echo "$TARGETS_JSON" | python3 -c "import sys, json; data=json.load(sys.stdin); targets=data.get('data',{}).get('activeTargets',[]); ksm=[t for t in targets if 'kube-state' in t.get('labels',{}).get('job','')]; print('up' if ksm and ksm[0].get('health')=='up' else 'down' if ksm else 'not-found')" 2>/dev/null || echo "error")
log "E" "diagnose_prometheus.sh:target_status" "kube-state-metrics target status in Prometheus" "{\"status\":\"$KSM_TARGET_STATUS\"}"
kill $PF_PID 2>/dev/null || true

# Summary
echo ""
echo "📊 Diagnostic Results:"
echo "  - kube-state-metrics pods: $KSM_PODS"
echo "  - kube-state-metrics services: $KSM_SVC"
echo "  - kube-state-metrics in Prometheus config: $KSM_IN_CONFIG"
echo "  - kube-state-metrics endpoint: $KSM_ENDPOINT"
echo "  - Prometheus target status: $KSM_TARGET_STATUS"
echo ""
echo "✅ Diagnostic complete. Check $LOG_FILE for detailed logs."

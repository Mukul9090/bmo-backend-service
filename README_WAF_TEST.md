# WAF Security Test Script

## Overview
`test_waf.py` is a Python script that sends various security attack patterns to test ModSecurity WAF rules and generate audit log entries.

## Usage

### Option 1: Run from your local machine (with port-forward)

```bash
# Start port-forward in one terminal
kubectl port-forward -n default svc/modsecurity-waf 8080:80

# In another terminal, update the script or set environment variable
export WAF_URL="http://localhost:8080"
python3 test_waf.py
```

### Option 2: Run from within Kubernetes cluster

```bash
# Create a test pod
kubectl run waf-test --image=python:3.11-slim --rm -it --restart=Never -- \
  sh -c "pip install requests && python3 -c \"$(curl -s https://raw.githubusercontent.com/your-repo/test_waf.py)\""
```

### Option 3: Run directly (if WAF service is accessible)

```bash
# Update WAF_URL in test_waf.py to your WAF service IP
python3 test_waf.py
```

## What it tests

1. **SQL Injection** - Various SQL injection patterns
2. **XSS Attacks** - Cross-site scripting attempts
3. **Command Injection** - OS command injection attempts
4. **Path Traversal** - Directory traversal attacks
5. **HTTP Methods** - Dangerous HTTP methods (DELETE, PUT, TRACE)
6. **Suspicious Headers** - Malicious content in HTTP headers
7. **Rate Limiting** - Tests rate limiting functionality

## View Results

After running the script, check ModSecurity audit logs:

```bash
# View audit log entries
kubectl exec -n default deployment/modsecurity-waf -- tail -100 /var/log/modsec_audit.log

# View access log
kubectl exec -n default deployment/modsecurity-waf -- tail -50 /var/log/nginx/access.log
```

## Expected Output

- ✅ **Blocked requests** (403, 406, 429) - WAF is working correctly
- ⚠️ **Allowed requests** (200) - May need WAF rule tuning
- ❌ **Errors** - Connection or configuration issues

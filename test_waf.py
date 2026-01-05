#!/usr/bin/env python3
"""
WAF Security Test Script
Sends various attack patterns to test ModSecurity WAF rules
"""

import requests
import time
import sys
import os
import subprocess
from typing import List, Tuple, Optional

def get_waf_url() -> str:
    """Auto-detect WAF URL or use environment variable"""
    # Check environment variable first
    waf_url = os.environ.get('WAF_URL')
    if waf_url:
        return waf_url
    
    # Try localhost:8080 (common port-forward)
    try:
        response = requests.get("http://localhost:8080/waf-health", timeout=2)
        if response.status_code in [200, 403, 404]:
            return "http://localhost:8080"
    except:
        pass
    
    # Try localhost:80
    try:
        response = requests.get("http://localhost:80/waf-health", timeout=2)
        if response.status_code in [200, 403, 404]:
            return "http://localhost:80"
    except:
        pass
    
    # Try to get ClusterIP from kubectl
    try:
        result = subprocess.run(
            ['kubectl', 'get', 'svc', 'modsecurity-waf', '-n', 'default', '-o', 'jsonpath={.spec.clusterIP}'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0 and result.stdout.strip():
            cluster_ip = result.stdout.strip()
            return f"http://{cluster_ip}"
    except:
        pass
    
    # Default to cluster service name (works inside cluster)
    return "http://modsecurity-waf.default.svc.cluster.local"

# WAF endpoint - auto-detected or can be set via WAF_URL environment variable
WAF_URL = get_waf_url()

class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'

def print_result(test_name: str, status_code: int, blocked: bool = False):
    """Print test result with color coding"""
    if blocked or status_code in [403, 406, 429]:
        print(f"{Colors.RED}❌ {test_name}: Blocked (Status: {status_code}){Colors.RESET}")
        return True
    elif status_code == 200:
        print(f"{Colors.YELLOW}⚠️  {test_name}: Allowed (Status: {status_code}) - May need tuning{Colors.RESET}")
        return False
    else:
        print(f"{Colors.BLUE}ℹ️  {test_name}: Status {status_code}{Colors.RESET}")
        return False

def test_sql_injection(url: str) -> List[Tuple[str, int, bool]]:
    """Test SQL injection attacks"""
    print(f"\n{Colors.BLUE}=== SQL Injection Tests ==={Colors.RESET}")
    results = []
    
    sql_attacks = [
        ("Basic SQL Injection", "?id=1' OR '1'='1"),
        ("Union SQL Injection", "?id=1' UNION SELECT NULL--"),
        ("Time-based SQL Injection", "?id=1'; WAITFOR DELAY '00:00:05'--"),
        ("Boolean SQL Injection", "?id=1' AND 1=1--"),
        ("Comment SQL Injection", "?id=1'/**/OR/**/1=1--"),
    ]
    
    for name, payload in sql_attacks:
        try:
            response = requests.get(f"{url}{payload}", timeout=5)
            blocked = response.status_code in [403, 406, 429]
            print_result(name, response.status_code, blocked)
            results.append((name, response.status_code, blocked))
            time.sleep(0.5)
        except Exception as e:
            print(f"{Colors.RED}❌ {name}: Error - {e}{Colors.RESET}")
            results.append((name, 0, False))
    
    return results

def test_xss_attacks(url: str) -> List[Tuple[str, int, bool]]:
    """Test XSS (Cross-Site Scripting) attacks"""
    print(f"\n{Colors.BLUE}=== XSS Attack Tests ==={Colors.RESET}")
    results = []
    
    xss_attacks = [
        ("Basic XSS", "?q=<script>alert('XSS')</script>"),
        ("XSS with Event Handler", "?q=<img src=x onerror=alert('XSS')>"),
        ("XSS with JavaScript", "?q=javascript:alert('XSS')"),
        ("XSS Encoded", "?q=%3Cscript%3Ealert('XSS')%3C/script%3E"),
        ("XSS in Body", "?q=<body onload=alert('XSS')>"),
    ]
    
    for name, payload in xss_attacks:
        try:
            response = requests.get(f"{url}{payload}", timeout=5)
            blocked = response.status_code in [403, 406, 429]
            print_result(name, response.status_code, blocked)
            results.append((name, response.status_code, blocked))
            time.sleep(0.5)
        except Exception as e:
            print(f"{Colors.RED}❌ {name}: Error - {e}{Colors.RESET}")
            results.append((name, 0, False))
    
    return results

def test_command_injection(url: str) -> List[Tuple[str, int, bool]]:
    """Test Command Injection attacks"""
    print(f"\n{Colors.BLUE}=== Command Injection Tests ==={Colors.RESET}")
    results = []
    
    cmd_attacks = [
        ("Basic Command Injection", "?cmd=; ls -la"),
        ("Pipe Command Injection", "?cmd=| whoami"),
        ("Backtick Command Injection", "?cmd=`id`"),
        ("Command Chaining", "?cmd=; cat /etc/passwd"),
        ("Path Traversal", "?file=../../../etc/passwd"),
    ]
    
    for name, payload in cmd_attacks:
        try:
            response = requests.get(f"{url}{payload}", timeout=5)
            blocked = response.status_code in [403, 406, 429]
            print_result(name, response.status_code, blocked)
            results.append((name, response.status_code, blocked))
            time.sleep(0.5)
        except Exception as e:
            print(f"{Colors.RED}❌ {name}: Error - {e}{Colors.RESET}")
            results.append((name, 0, False))
    
    return results

def test_path_traversal(url: str) -> List[Tuple[str, int, bool]]:
    """Test Path Traversal attacks"""
    print(f"\n{Colors.BLUE}=== Path Traversal Tests ==={Colors.RESET}")
    results = []
    
    path_attacks = [
        ("Basic Path Traversal", "?file=../../etc/passwd"),
        ("Encoded Path Traversal", "?file=..%2F..%2Fetc%2Fpasswd"),
        ("Double Slash", "?file=//etc/passwd"),
        ("Windows Path", "?file=..\\..\\windows\\system32"),
    ]
    
    for name, payload in path_attacks:
        try:
            response = requests.get(f"{url}{payload}", timeout=5)
            blocked = response.status_code in [403, 406, 429]
            print_result(name, response.status_code, blocked)
            results.append((name, response.status_code, blocked))
            time.sleep(0.5)
        except Exception as e:
            print(f"{Colors.RED}❌ {name}: Error - {e}{Colors.RESET}")
            results.append((name, 0, False))
    
    return results

def test_http_methods(url: str) -> List[Tuple[str, int, bool]]:
    """Test dangerous HTTP methods"""
    print(f"\n{Colors.BLUE}=== HTTP Method Tests ==={Colors.RESET}")
    results = []
    
    methods = [
        ("DELETE Method", "DELETE"),
        ("PUT Method", "PUT"),
        ("TRACE Method", "TRACE"),
        ("OPTIONS Method", "OPTIONS"),
    ]
    
    for name, method in methods:
        try:
            response = requests.request(method, url, timeout=5)
            blocked = response.status_code in [403, 405, 406, 429]
            print_result(name, response.status_code, blocked)
            results.append((name, response.status_code, blocked))
            time.sleep(0.5)
        except Exception as e:
            print(f"{Colors.RED}❌ {name}: Error - {e}{Colors.RESET}")
            results.append((name, 0, False))
    
    return results

def test_rate_limiting(url: str) -> List[Tuple[str, int, bool]]:
    """Test rate limiting"""
    print(f"\n{Colors.BLUE}=== Rate Limiting Test ==={Colors.RESET}")
    results = []
    
    print(f"{Colors.YELLOW}Sending 25 rapid requests to test rate limiting...{Colors.RESET}")
    blocked_count = 0
    
    for i in range(25):
        try:
            response = requests.get(f"{url}/healthz", timeout=5)
            if response.status_code == 429:
                blocked_count += 1
            time.sleep(0.1)
        except Exception as e:
            print(f"{Colors.RED}Error on request {i+1}: {e}{Colors.RESET}")
    
    if blocked_count > 0:
        print(f"{Colors.RED}✅ Rate limiting working: {blocked_count} requests blocked (429){Colors.RESET}")
        results.append(("Rate Limiting", 429, True))
    else:
        print(f"{Colors.YELLOW}⚠️  Rate limiting not triggered (may need more requests){Colors.RESET}")
        results.append(("Rate Limiting", 200, False))
    
    return results

def test_suspicious_headers(url: str) -> List[Tuple[str, int, bool]]:
    """Test suspicious HTTP headers"""
    print(f"\n{Colors.BLUE}=== Suspicious Header Tests ==={Colors.RESET}")
    results = []
    
    suspicious_headers = [
        ("SQL in User-Agent", {"User-Agent": "1' OR '1'='1"}),
        ("XSS in Referer", {"Referer": "<script>alert('XSS')</script>"}),
        ("Command in Cookie", {"Cookie": "test=; cat /etc/passwd"}),
    ]
    
    for name, headers in suspicious_headers:
        try:
            response = requests.get(url, headers=headers, timeout=5)
            blocked = response.status_code in [403, 406, 429]
            print_result(name, response.status_code, blocked)
            results.append((name, response.status_code, blocked))
            time.sleep(0.5)
        except Exception as e:
            print(f"{Colors.RED}❌ {name}: Error - {e}{Colors.RESET}")
            results.append((name, 0, False))
    
    return results

def main():
    """Main test function"""
    print(f"{Colors.BLUE}{'='*60}")
    print(f"  WAF Security Test Script")
    print(f"  Testing ModSecurity WAF Rules")
    print(f"{'='*60}{Colors.RESET}\n")
    
    print(f"{Colors.YELLOW}Detected WAF URL: {WAF_URL}{Colors.RESET}")
    print(f"{Colors.YELLOW}To override, set WAF_URL environment variable:{Colors.RESET}")
    print(f"{Colors.YELLOW}  export WAF_URL='http://localhost:8080'{Colors.RESET}\n")
    
    # Check if URL is accessible
    print(f"{Colors.BLUE}Testing connection...{Colors.RESET}")
    try:
        # Try health endpoint first
        try:
            response = requests.get(f"{WAF_URL}/waf-health", timeout=5)
            print(f"{Colors.GREEN}✅ WAF is accessible at {WAF_URL}{Colors.RESET}\n")
        except:
            # Fallback to root
            response = requests.get(WAF_URL, timeout=5)
            print(f"{Colors.GREEN}✅ WAF is accessible at {WAF_URL}{Colors.RESET}\n")
    except requests.exceptions.ConnectionError:
        print(f"{Colors.RED}❌ Cannot connect to WAF at {WAF_URL}{Colors.RESET}")
        print(f"\n{Colors.YELLOW}Connection Options:{Colors.RESET}")
        print(f"{Colors.YELLOW}1. Use port-forward (recommended for local testing):{Colors.RESET}")
        print(f"   kubectl port-forward -n default svc/modsecurity-waf 8080:80")
        print(f"   export WAF_URL='http://localhost:8080'")
        print(f"   python3 test_waf.py")
        print(f"\n{Colors.YELLOW}2. Run from inside Kubernetes cluster:{Colors.RESET}")
        print(f"   kubectl run waf-test --image=python:3.11-slim --rm -it --restart=Never -- \\")
        print(f"     sh -c 'pip install requests && python3 -c \"import requests; print(requests.get(\\\"http://modsecurity-waf.default.svc.cluster.local\\\"))\"'")
        print(f"\n{Colors.YELLOW}3. Use helper script:{Colors.RESET}")
        print(f"   ./run_waf_test.sh")
        sys.exit(1)
    except requests.exceptions.RequestException as e:
        print(f"{Colors.RED}❌ Error connecting to WAF: {e}{Colors.RESET}")
        print(f"{Colors.YELLOW}Make sure WAF service is running:{Colors.RESET}")
        print(f"   kubectl get svc modsecurity-waf -n default")
        sys.exit(1)
    
    all_results = []
    
    # Run all test suites
    all_results.extend(test_sql_injection(WAF_URL))
    all_results.extend(test_xss_attacks(WAF_URL))
    all_results.extend(test_command_injection(WAF_URL))
    all_results.extend(test_path_traversal(WAF_URL))
    all_results.extend(test_http_methods(WAF_URL))
    all_results.extend(test_suspicious_headers(WAF_URL))
    all_results.extend(test_rate_limiting(WAF_URL))
    
    # Summary
    print(f"\n{Colors.BLUE}{'='*60}")
    print(f"  Test Summary")
    print(f"{'='*60}{Colors.RESET}\n")
    
    total_tests = len(all_results)
    blocked_tests = sum(1 for _, _, blocked in all_results if blocked)
    allowed_tests = total_tests - blocked_tests
    
    print(f"Total Tests: {total_tests}")
    print(f"{Colors.RED}Blocked: {blocked_tests}{Colors.RESET}")
    print(f"{Colors.YELLOW}Allowed: {allowed_tests}{Colors.RESET}")
    print(f"Block Rate: {(blocked_tests/total_tests*100):.1f}%")
    
    print(f"\n{Colors.GREEN}✅ Test completed! Check ModSecurity audit logs:")
    print(f"  kubectl exec -n default deployment/modsecurity-waf -- tail -100 /var/log/modsec_audit.log{Colors.RESET}\n")

if __name__ == "__main__":
    main()
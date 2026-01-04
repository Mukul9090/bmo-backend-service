#!/usr/bin/env python3
"""
Failover test for HAProxy hot/standby cluster setup.
Tests automatic failover when hot cluster goes down and recovery when it comes back.
"""

import requests
import sys
import time
import os
import subprocess
import json

# Get URLs from environment
HAPROXY_URL = os.getenv("HAPROXY_URL", "http://localhost:9090")
HOT_CONTEXT = os.getenv("K8S_CLUSTER_HOT_CONTEXT", "minikube")
STANDBY_CONTEXT = os.getenv("K8S_CLUSTER_STANDBY_CONTEXT", "minikube")

TIMEOUT = 10
MAX_RETRIES = 10
RETRY_DELAY = 3  # seconds between retries

def run_kubectl(command, context=None):
    """Run kubectl command and return output."""
    cmd = ["kubectl"]
    if context:
        cmd.extend(["--context", context])
    cmd.extend(command.split())
    
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30
        )
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Command timed out"
    except Exception as e:
        return False, "", str(e)

def get_pod_count(context, namespace="default", label="app=backend-service"):
    """Get the number of running pods."""
    success, output, _ = run_kubectl(
        f"get pods -n {namespace} -l {label} -o json",
        context
    )
    if success:
        try:
            data = json.loads(output)
            running_count = sum(1 for item in data.get("items", []) 
                             if item.get("status", {}).get("phase") == "Running")
            return running_count
        except (json.JSONDecodeError, KeyError, ValueError):
            return 0
    return 0

def scale_deployment(context, namespace="default", deployment="backend-service", replicas=0):
    """Scale a deployment to specified number of replicas."""
    print(f"   Scaling {deployment} in {context} to {replicas} replicas...")
    success, output, error = run_kubectl(
        f"scale deployment {deployment} -n {namespace} --replicas={replicas}",
        context
    )
    if not success:
        print(f"   ⚠️  Warning: {error}")
    return success

def wait_for_pods(context, namespace="default", label="app=backend-service", expected_count=0, timeout=60):
    """Wait for pods to reach expected count."""
    print(f"   Waiting for pods to reach {expected_count} replicas...")
    start_time = time.time()
    
    while time.time() - start_time < timeout:
        count = get_pod_count(context, namespace, label)
        if count == expected_count:
            print(f"   ✅ Pods reached {expected_count} replicas")
            return True
        time.sleep(2)
    
    print(f"   ⚠️  Timeout: Pods are at {get_pod_count(context, namespace, label)} replicas (expected {expected_count})")
    return False

def test_endpoint(url, name, expected_role=None, max_retries=MAX_RETRIES):
    """Test an endpoint and verify response."""
    for attempt in range(max_retries):
        try:
            response = requests.get(url, timeout=TIMEOUT)
            if response.status_code == 200:
                data = response.json()
                
                if expected_role:
                    role = data.get("role")
                    if role == expected_role:
                        return True, role
                    else:
                        if attempt < max_retries - 1:
                            time.sleep(RETRY_DELAY)
                            continue
                        return False, role
                return True, data.get("role", "unknown")
            else:
                if attempt < max_retries - 1:
                    time.sleep(RETRY_DELAY)
                    continue
                return False, None
        except requests.exceptions.RequestException as e:
            if attempt < max_retries - 1:
                time.sleep(RETRY_DELAY)
                continue
            return False, None
    
    return False, None

def verify_routing(expected_role, test_name):
    """Verify HAProxy is routing to the expected cluster."""
    print(f"   Verifying HAProxy routes to {expected_role} cluster...")
    
    # Make multiple requests to ensure consistency
    success_count = 0
    total_requests = 5
    
    for i in range(total_requests):
        success, role = test_endpoint(f"{HAPROXY_URL}/", f"Request {i+1}", expected_role=expected_role, max_retries=3)
        if success:
            success_count += 1
        time.sleep(1)
    
    if success_count == total_requests:
        print(f"   ✅ All {total_requests} requests routed to {expected_role} cluster")
        return True
    else:
        print(f"   ❌ Only {success_count}/{total_requests} requests routed to {expected_role} cluster")
        return False

def main():
    """Run failover tests."""
    print("=" * 70)
    print("🔄 HAProxy Failover Test Suite")
    print("=" * 70)
    print()
    print(f"HAProxy URL: {HAPROXY_URL}")
    print(f"Hot Context: {HOT_CONTEXT}")
    print(f"Standby Context: {STANDBY_CONTEXT}")
    print()
    
    all_passed = True
    
    # Pre-test: Verify initial state
    print("Pre-test: Verifying Initial State")
    print("-" * 70)
    hot_pods = get_pod_count(HOT_CONTEXT)
    standby_pods = get_pod_count(STANDBY_CONTEXT)
    print(f"   Hot cluster pods: {hot_pods}")
    print(f"   Standby cluster pods: {standby_pods}")
    
    if hot_pods == 0:
        print("   ⚠️  Warning: Hot cluster has 0 pods. Scaling to 2...")
        scale_deployment(HOT_CONTEXT, replicas=2)
        wait_for_pods(HOT_CONTEXT, expected_count=2, timeout=120)
    
    if standby_pods == 0:
        print("   ⚠️  Warning: Standby cluster has 0 pods. Scaling to 2...")
        scale_deployment(STANDBY_CONTEXT, replicas=2)
        wait_for_pods(STANDBY_CONTEXT, expected_count=2, timeout=120)
    
    # Verify HAProxy is routing to hot initially
    print("   Verifying HAProxy initially routes to hot cluster...")
    if not verify_routing("hot", "Initial State"):
        print("   ❌ Initial routing test failed")
        all_passed = False
    print()
    
    # Test 1: Scale hot pods to 0 and verify failover to standby
    print("Test 1: Failover Test - Hot Cluster Down")
    print("-" * 70)
    
    print("   Step 1: Scaling hot cluster to 0 replicas...")
    if not scale_deployment(HOT_CONTEXT, replicas=0):
        print("   ❌ Failed to scale hot cluster")
        all_passed = False
        print()
    else:
        # Wait for pods to terminate
        wait_for_pods(HOT_CONTEXT, expected_count=0, timeout=60)
        
        # Wait a bit for HAProxy to detect the failure
        print("   Step 2: Waiting for HAProxy to detect failure and failover...")
        time.sleep(10)  # Give HAProxy time to detect and failover
        
        # Verify HAProxy routes to standby
        print("   Step 3: Verifying HAProxy routes to standby cluster...")
        if verify_routing("standby", "Failover"):
            print("   ✅ Failover successful: HAProxy routing to standby")
        else:
            print("   ❌ Failover failed: HAProxy not routing to standby")
            all_passed = False
    print()
    
    # Test 2: Scale hot pods back up and verify recovery
    print("Test 2: Recovery Test - Hot Cluster Back Up")
    print("-" * 70)
    
    print("   Step 1: Scaling hot cluster back to 2 replicas...")
    if not scale_deployment(HOT_CONTEXT, replicas=2):
        print("   ❌ Failed to scale hot cluster back up")
        all_passed = False
        print()
    else:
        # Wait for pods to be ready
        wait_for_pods(HOT_CONTEXT, expected_count=2, timeout=120)
        
        # Wait for HAProxy health checks to mark hot as healthy
        print("   Step 2: Waiting for HAProxy to detect hot cluster recovery...")
        time.sleep(15)  # Give HAProxy time to detect hot is healthy again
        
        # Verify HAProxy routes back to hot
        print("   Step 3: Verifying HAProxy routes back to hot cluster...")
        if verify_routing("hot", "Recovery"):
            print("   ✅ Recovery successful: HAProxy routing back to hot")
        else:
            print("   ❌ Recovery failed: HAProxy not routing back to hot")
            all_passed = False
    print()
    
    # Summary
    print("=" * 70)
    if all_passed:
        print("✅ ALL FAILOVER TESTS PASSED")
        print("=" * 70)
        return 0
    else:
        print("❌ SOME FAILOVER TESTS FAILED")
        print("=" * 70)
        return 1

if __name__ == "__main__":
    sys.exit(main())


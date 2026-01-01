#!/usr/bin/env python3
"""
Test script for deployment verification.
Tests hot/standby clusters and HAProxy failover.
"""

import requests
import sys
import time
import os

# Get HAProxy URL from environment or use default
HAPROXY_URL = os.getenv("HAPROXY_URL", "http://localhost:9090")
HOT_URL = os.getenv("HOT_URL", "http://localhost:8080")
STANDBY_URL = os.getenv("STANDBY_URL", "http://localhost:8081")

TIMEOUT = 10
MAX_RETRIES = 3

def test_endpoint(url, name, expected_role=None):
    """Test an endpoint and verify response."""
    for attempt in range(MAX_RETRIES):
        try:
            response = requests.get(url, timeout=TIMEOUT)
            if response.status_code == 200:
                data = response.json()
                print(f"✅ {name}: Status OK")
                
                if expected_role:
                    role = data.get("role")
                    if role == expected_role:
                        print(f"   ✓ Role verified: {role}")
                        return True
                    else:
                        print(f"   ✗ Expected role '{expected_role}', got '{role}'")
                        return False
                return True
            else:
                print(f"❌ {name}: HTTP {response.status_code}")
                return False
        except requests.exceptions.RequestException as e:
            if attempt < MAX_RETRIES - 1:
                print(f"⚠️  {name}: Attempt {attempt + 1} failed, retrying...")
                time.sleep(2)
            else:
                print(f"❌ {name}: Failed after {MAX_RETRIES} attempts - {str(e)}")
                return False
    return False

def test_health_endpoint(url, name):
    """Test health endpoint."""
    health_url = f"{url}/healthz"
    return test_endpoint(health_url, f"{name} Health")

def main():
    """Run all tests."""
    print("=" * 60)
    print("🧪 Deployment Test Suite")
    print("=" * 60)
    print()
    
    all_passed = True
    
    # Test 1: Hot Cluster Health
    print("Test 1: Hot Cluster Health Check")
    print("-" * 60)
    if not test_health_endpoint(HOT_URL, "Hot Cluster"):
        all_passed = False
    print()
    
    # Test 2: Hot Cluster Role
    print("Test 2: Hot Cluster Role Verification")
    print("-" * 60)
    if not test_endpoint(f"{HOT_URL}/", "Hot Cluster", expected_role="hot"):
        all_passed = False
    print()
    
    # Test 3: Standby Cluster Health
    print("Test 3: Standby Cluster Health Check")
    print("-" * 60)
    if not test_health_endpoint(STANDBY_URL, "Standby Cluster"):
        all_passed = False
    print()
    
    # Test 4: Standby Cluster Role
    print("Test 4: Standby Cluster Role Verification")
    print("-" * 60)
    if not test_endpoint(f"{STANDBY_URL}/", "Standby Cluster", expected_role="standby"):
        all_passed = False
    print()
    
    # Test 5: HAProxy Health
    print("Test 5: HAProxy Health Check")
    print("-" * 60)
    if not test_health_endpoint(HAPROXY_URL, "HAProxy"):
        all_passed = False
    print()
    
    # Test 6: HAProxy Routing (should route to hot)
    print("Test 6: HAProxy Routing (should route to hot)")
    print("-" * 60)
    if not test_endpoint(f"{HAPROXY_URL}/", "HAProxy", expected_role="hot"):
        all_passed = False
    print()
    
    # Test 7: Multiple requests to verify consistency
    print("Test 7: Multiple Requests Consistency Check")
    print("-" * 60)
    success_count = 0
    for i in range(5):
        if test_endpoint(f"{HAPROXY_URL}/healthz", f"Request {i+1}"):
            success_count += 1
        time.sleep(0.5)
    
    if success_count == 5:
        print(f"✅ Consistency: {success_count}/5 requests successful")
    else:
        print(f"❌ Consistency: Only {success_count}/5 requests successful")
        all_passed = False
    print()
    
    # Summary
    print("=" * 60)
    if all_passed:
        print("✅ ALL TESTS PASSED")
        print("=" * 60)
        return 0
    else:
        print("❌ SOME TESTS FAILED")
        print("=" * 60)
        return 1

if __name__ == "__main__":
    sys.exit(main())


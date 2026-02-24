#!/bin/bash
# Test 2: Air-Gap Network Validation
# Demonstrates that air-gapped containers prevent malicious network access
# Compatible with: Windows WSL2, Linux
# Based on: https://docs.docker.com/enterprise/security/hardened-desktop/air-gapped-containers/
#
# Policy under test: docker.com and *.docker.com on port 443 only.
# Note: docker.io is a separate domain and is NOT covered by *.docker.com;
#       it will be blocked by this policy.
#
# Note: Do NOT use 'set -e' - individual test failures must not abort the suite.
# Use counter=$((counter + 1)) instead of ((counter++)) to avoid false exit-code
# failures when the counter value is zero.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Test 2: Air-Gap Network Validation                   ║${NC}"
echo -e "${BLUE}║  Policy: docker.com only (port 443)                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Verify Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Docker is not running or not accessible.${NC}"
    echo "  On Windows: Ensure Docker Desktop is running and WSL2 integration is enabled."
    exit 1
fi

RESULTS_FILE="air_gap_results.txt"
{
    echo "Air-Gap Network Validation Test Results"
    echo "======================================="
    echo "Date: $(date)"
    echo "Docker Version: $(docker --version)"
    echo "Platform: Windows (WSL2)"
    echo ""
    echo "Purpose: Demonstrate that air-gapped containers prevent malicious"
    echo "network access while allowing approved destinations."
    echo ""
    echo "Air-Gap Policy:"
    echo "  - Allowed: docker.com, *.docker.com (port 443 HTTPS only)"
    echo "  - Blocked: All other destinations and ports"
    echo ""
    echo "Note: docker.io is a separate domain from docker.com and is blocked"
    echo "by this policy (it is not covered by the *.docker.com pattern)."
    echo ""
} > "$RESULTS_FILE"

pass_count=0
fail_count=0

# Test that a destination is reachable over HTTPS.
# Fails the test (increments fail_count) if not reachable.
test_accessible() {
    local test_num=$1
    local destination=$2

    echo "[Test $test_num] $destination should be ACCESSIBLE (HTTPS port 443)..."
    echo "  Destination: $destination port 443 (Expected: ACCESSIBLE)" >> "$RESULTS_FILE"

    output=$(timeout 10 docker run --rm alpine \
        wget --timeout=8 -q -O- "https://$destination" 2>&1 || true)

    if echo "$output" | grep -qE "html|docker|404|301|200|images|registry|<"; then
        echo -e "${GREEN}✓ ACCESSIBLE${NC}: $destination"
        echo "  Result: ACCESSIBLE ✓" >> "$RESULTS_FILE"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ NOT ACCESSIBLE${NC}: $destination (should be reachable - check air-gap exclude list)"
        echo "  Result: NOT ACCESSIBLE ✗ (verify docker.com is in the exclude list)" >> "$RESULTS_FILE"
        echo "  Output: $output" >> "$RESULTS_FILE"
        fail_count=$((fail_count + 1))
    fi
    echo "" >> "$RESULTS_FILE"
}

# Test that a destination is blocked over HTTPS.
# Fails the test (increments fail_count) if reachable.
test_blocked() {
    local test_num=$1
    local destination=$2

    echo "[Test $test_num] $destination should be BLOCKED (HTTPS port 443)..."
    echo "  Destination: $destination port 443 (Expected: BLOCKED)" >> "$RESULTS_FILE"

    output=$(timeout 10 docker run --rm alpine \
        wget --timeout=8 -q -O- "https://$destination" 2>&1 || true)

    if echo "$output" | grep -qiE "Connection refused|Name does not resolve|connection timed out|Temporary failure|bad address|unable to resolve|Can't connect"; then
        echo -e "${GREEN}✓ BLOCKED${NC}: $destination"
        echo "  Result: BLOCKED ✓" >> "$RESULTS_FILE"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ ACCESSIBLE${NC}: $destination (should be blocked by air-gap policy)"
        echo "  Result: ACCESSIBLE - air-gap policy not enforced ✗" >> "$RESULTS_FILE"
        echo "  Output: $output" >> "$RESULTS_FILE"
        fail_count=$((fail_count + 1))
    fi
    echo "" >> "$RESULTS_FILE"
}

echo "" >> "$RESULTS_FILE"
echo "Network Access Tests (docker.com only policy):"
echo "===============================================" >> "$RESULTS_FILE"
echo ""

# Test 1: docker.com HTTPS - should be accessible (in allowlist)
test_accessible 1 "docker.com"

# Test 2: google.com HTTPS - should be blocked (not in allowlist)
test_blocked 2 "google.com"

# Test 3: github.com HTTPS - should be blocked (not in allowlist)
test_blocked 3 "github.com"

# Test 4: HTTP port 80 - should be blocked (only port 443 in transparentPorts)
echo "[Test 4] HTTP port 80 should be BLOCKED..."
echo "  Destination: docker.com port 80 (Expected: BLOCKED - only port 443 allowed)" >> "$RESULTS_FILE"
output=$(timeout 8 docker run --rm alpine \
    wget --timeout=5 -q -O- "http://docker.com" 2>&1 || true)
if echo "$output" | grep -qiE "Connection refused|connection timed out|refused|failed|timed out|bad address|Can't connect"; then
    echo -e "${GREEN}✓ BLOCKED${NC}: HTTP port 80"
    echo "  Result: BLOCKED ✓" >> "$RESULTS_FILE"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ ACCESSIBLE${NC}: HTTP port 80 (should be blocked - check transparentPorts setting)"
    echo "  Result: ACCESSIBLE ✗ (transparentPorts should only contain 443)" >> "$RESULTS_FILE"
    echo "  Output: $output" >> "$RESULTS_FILE"
    fail_count=$((fail_count + 1))
fi
echo "" >> "$RESULTS_FILE"

# Test 5: Non-standard port 8080 - should be blocked
echo "[Test 5] Non-standard port 8080 should be BLOCKED..."
echo "  Destination: docker.com port 8080 (Expected: BLOCKED)" >> "$RESULTS_FILE"
output=$(timeout 8 docker run --rm alpine \
    wget --timeout=5 -q -O- "http://docker.com:8080" 2>&1 || true)
if echo "$output" | grep -qiE "Connection refused|connection timed out|refused|failed|timed out|bad address|Can't connect"; then
    echo -e "${GREEN}✓ BLOCKED${NC}: Port 8080"
    echo "  Result: BLOCKED ✓" >> "$RESULTS_FILE"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ ACCESSIBLE${NC}: Port 8080 (should be blocked)"
    echo "  Result: ACCESSIBLE ✗ (non-standard port not blocked)" >> "$RESULTS_FILE"
    echo "  Output: $output" >> "$RESULTS_FILE"
    fail_count=$((fail_count + 1))
fi
echo "" >> "$RESULTS_FILE"

# Test 6: Direct IP access - should be blocked
# A domain-based allowlist must also block direct IP addresses to prevent
# policy bypass. No extra packages needed - wget handles this directly.
echo "[Test 6] Direct IP access (8.8.8.8) should be BLOCKED..."
echo "  Destination: 8.8.8.8 port 80 (Expected: BLOCKED - IP not in domain allowlist)" >> "$RESULTS_FILE"
output=$(timeout 8 docker run --rm alpine \
    wget --timeout=5 -q -O- "http://8.8.8.8" 2>&1 || true)
if echo "$output" | grep -qiE "Connection refused|connection timed out|refused|failed|timed out|Can't connect"; then
    echo -e "${GREEN}✓ BLOCKED${NC}: Direct IP access (8.8.8.8)"
    echo "  Result: BLOCKED ✓" >> "$RESULTS_FILE"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ ACCESSIBLE${NC}: Direct IP (should be blocked - IP bypasses domain allowlist)"
    echo "  Result: ACCESSIBLE ✗ (direct IP access not blocked)" >> "$RESULTS_FILE"
    echo "  Output: $output" >> "$RESULTS_FILE"
    fail_count=$((fail_count + 1))
fi
echo "" >> "$RESULTS_FILE"

# Summary
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo "Test Summary:"
echo "  Passed: $pass_count/6"
echo "  Failed: $fail_count/6"
echo ""
{
    echo ""
    echo "Test Summary:"
    echo "============="
    echo "Tests Passed: $pass_count/6"
    echo "Tests Failed: $fail_count/6"
    echo ""
} >> "$RESULTS_FILE"

if [ "$fail_count" -eq 0 ]; then
    echo -e "${GREEN}✓ AIR-GAP NETWORK VALIDATION PASSED${NC}"
    echo "Air-gap configuration is properly restricting container network access."
    echo ""
    {
        echo "RESULT: PASS ✓"
        echo ""
        echo "Conclusion:"
        echo "==========="
        echo "Air-Gapped Containers successfully prevent malicious container"
        echo "network access. Only docker.com on port 443 is accessible; all"
        echo "other destinations, ports, and direct IP addresses are blocked,"
        echo "preventing data exfiltration and command-and-control communication."
    } >> "$RESULTS_FILE"
    echo "Results saved to: $RESULTS_FILE"
    exit 0
else
    echo -e "${RED}✗ AIR-GAP NETWORK VALIDATION FAILED${NC}"
    echo "Some destinations are accessible when they should be blocked."
    echo ""
    {
        echo "RESULT: FAIL ✗"
        echo ""
        echo "Troubleshooting:"
        echo "================"
        echo "1. Verify air-gap policy is deployed in Admin Console"
        echo "2. Check that docker.com is in the exclude list"
        echo "3. Verify 'locked: true' is set in the policy"
        echo "4. Ensure transparentPorts contains only 443 (not 80)"
        echo "5. Restart Docker Desktop after configuration change"
        echo "6. Ensure WSL2 integration is enabled in Docker Desktop settings"
    } >> "$RESULTS_FILE"
    echo "Results saved to: $RESULTS_FILE"
    exit 1
fi

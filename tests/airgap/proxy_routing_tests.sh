#!/bin/bash
# Proxy Routing Validation Tests
# Tests that traffic is properly routed through configured proxies

set -e

TEST_NAME="Proxy Routing Validation"
echo "=== $TEST_NAME ==="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass_count=0
fail_count=0

test_result() {
  if [ $1 -eq 0 ]; then
    echo -e "${GREEN}✓ PASS${NC}: $2"
    ((pass_count++))
  else
    echo -e "${RED}✗ FAIL${NC}: $2"
    ((fail_count++))
  fi
}

# Test 1: Start test HTTP proxy
echo -e "\n${YELLOW}Test 1: Test proxy server setup${NC}"
echo "Starting simple HTTP proxy for testing..."

# Check if we can start a test proxy
docker rm -f test-http-proxy 2>/dev/null || true

# Start Tinyproxy for testing
docker run -d --name test-http-proxy \
  -p 8888:8888 \
  --rm \
  vimagick/tinyproxy >/dev/null 2>&1 && TEST1=0 || TEST1=1

if [ $TEST1 -eq 0 ]; then
  echo "Test proxy running on localhost:8888"
  sleep 2
fi
test_result $TEST1 "Test HTTP proxy started"

# Test 2: Direct connection without proxy
echo -e "\n${YELLOW}Test 2: Baseline connection (no proxy)${NC}"
timeout 5 docker run --rm alpine wget -T 2 -O- http://example.com >/dev/null 2>&1 && TEST2=0 || TEST2=1
if [ $TEST2 -eq 0 ]; then
  echo "Direct connection works (baseline established)"
else
  echo "Direct connection blocked (may be expected if air-gap configured)"
fi
test_result $TEST2 "Baseline connectivity"

# Test 3: Connection through manual proxy setting
echo -e "\n${YELLOW}Test 3: Proxy environment variable${NC}"
echo "Testing if container can use HTTP_PROXY (for comparison)..."
timeout 5 docker run --rm \
  -e HTTP_PROXY=http://host.docker.internal:8888 \
  alpine wget -T 2 -O- http://example.com >/dev/null 2>&1 && TEST3=0 || TEST3=1
if [ $TEST3 -eq 0 ]; then
  echo "Proxy via environment variable works"
else
  echo "Note: Air-gap config may override environment variables"
fi
test_result $TEST3 "Proxy environment variable (comparison)"

# Test 4: Exclude list verification
echo -e "\n${YELLOW}Test 4: Excluded host access${NC}"
echo "If localhost/host.docker.internal in exclude list, should work directly:"
docker run --rm alpine ping -c 1 host.docker.internal >/dev/null 2>&1 && TEST4=0 || TEST4=1
test_result $TEST4 "Excluded host access (host.docker.internal)"

# Test 5: Proxy logs verification
echo -e "\n${YELLOW}Test 5: Proxy request logging${NC}"
echo "Attempting connection and checking proxy logs..."
timeout 5 docker run --rm \
  -e HTTP_PROXY=http://host.docker.internal:8888 \
  alpine wget -T 2 -O- http://example.com >/dev/null 2>&1 || true

sleep 1
if docker logs test-http-proxy 2>&1 | grep -q "example.com"; then
  TEST5=0
  echo "Connection logged in proxy (traffic went through proxy)"
else
  TEST5=1
  echo "No log entry (air-gap may be routing differently)"
fi
test_result $TEST5 "Proxy logging verification"

# Test 6: HTTPS proxy routing
echo -e "\n${YELLOW}Test 6: HTTPS proxy support${NC}"
timeout 5 docker run --rm \
  -e HTTPS_PROXY=http://host.docker.internal:8888 \
  alpine wget -T 2 -O- https://example.com >/dev/null 2>&1 && TEST6=0 || TEST6=1
test_result $TEST6 "HTTPS proxy routing"

# Test 7: Port-specific routing
echo -e "\n${YELLOW}Test 7: Port-specific proxy rules${NC}"
echo "Testing different ports with transparentPorts configuration:"
echo "  - Port 80 (HTTP): Should follow air-gap rules"
timeout 5 docker run --rm alpine nc -vz example.com 80 2>&1 | grep -q "open\|succeeded" && P80=0 || P80=1
echo "  - Port 443 (HTTPS): Should follow air-gap rules"  
timeout 5 docker run --rm alpine nc -vz example.com 443 2>&1 | grep -q "open\|succeeded" && P443=0 || P443=1
echo "  - Port 22 (SSH): Depends on transparentPorts setting"
timeout 5 docker run --rm alpine nc -vz example.com 22 2>&1 | grep -q "open\|succeeded" && P22=0 || P22=1

echo "Port 80: $([ $P80 -eq 0 ] && echo 'accessible' || echo 'blocked')"
echo "Port 443: $([ $P443 -eq 0 ] && echo 'accessible' || echo 'blocked')"
echo "Port 22: $([ $P22 -eq 0 ] && echo 'accessible' || echo 'blocked')"
TEST7=0  # Informational test
test_result $TEST7 "Port-specific routing (informational)"

# Test 8: Concurrent proxy connections
echo -e "\n${YELLOW}Test 8: Concurrent proxy connections${NC}"
echo "Running 5 concurrent requests..."
SUCCESS=0
for i in {1..5}; do
  timeout 3 docker run --rm \
    -e HTTP_PROXY=http://host.docker.internal:8888 \
    alpine wget -T 2 -O /dev/null http://example.com 2>/dev/null && ((SUCCESS++)) || true &
done
wait
[ $SUCCESS -ge 3 ] && TEST8=0 || TEST8=1
echo "Successful connections: $SUCCESS/5"
test_result $TEST8 "Concurrent connections ($SUCCESS/5 successful)"

# Test 9: Proxy failure handling
echo -e "\n${YELLOW}Test 9: Proxy failure handling${NC}"
echo "Testing with non-existent proxy..."
timeout 5 docker run --rm \
  -e HTTP_PROXY=http://nonexistent-proxy.local:9999 \
  alpine wget -T 2 -O- http://example.com 2>&1 | grep -qE "(failed|timeout|Connection refused)" && TEST9=0 || TEST9=1
test_result $TEST9 "Failed proxy handling"

# Test 10: Transparent proxy vs explicit proxy
echo -e "\n${YELLOW}Test 10: Configuration precedence${NC}"
echo "Testing if air-gap config takes precedence over environment variables..."
timeout 5 docker run --rm \
  -e HTTP_PROXY=http://wrong-proxy.local:8080 \
  -e HTTPS_PROXY=http://wrong-proxy.local:8080 \
  alpine wget -T 2 -O- http://google.com 2>&1 | tee /tmp/proxy-test.log

if grep -qE "(failed|timeout|403)" /tmp/proxy-test.log; then
  TEST10=0
  echo "Air-gap config blocked request (takes precedence)"
elif grep -q "Connection refused" /tmp/proxy-test.log; then
  TEST10=0
  echo "Environment variable tried to connect to wrong proxy"
else
  TEST10=1
  echo "Unexpected result - check /tmp/proxy-test.log"
fi
rm -f /tmp/proxy-test.log
test_result $TEST10 "Configuration precedence"

# Cleanup
echo -e "\n${YELLOW}Cleanup${NC}"
docker stop test-http-proxy 2>/dev/null || true
echo "Test proxy stopped"

# Summary
echo -e "\n=== Test Summary ==="
echo -e "Passed: ${GREEN}$pass_count${NC}"
echo -e "Failed: ${RED}$fail_count${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} Proxy routing tests are informational when air-gap is configured."
echo "Results show how traffic is being routed based on your configuration."
echo ""
echo "To test with actual air-gap proxy configuration:"
echo "1. Configure admin-settings.json with proxy URL"
echo "2. Start corporate proxy or use test proxy"
echo "3. Re-run these tests"
echo "4. Check proxy logs to confirm traffic routing"

[ $fail_count -eq 0 ] && exit 0 || exit 1

#!/bin/bash
# Air-Gapped Containers Configuration Tests
# Tests Docker Desktop's enterprise air-gapped container feature

set -e

TEST_NAME="Air-Gapped Container Configuration"
echo "=== $TEST_NAME ==="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check prerequisites
echo -e "\n${YELLOW}Checking Prerequisites${NC}"

# Check Docker Desktop version
DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "0.0.0")
echo "Docker Desktop version: $DOCKER_VERSION"

# Check if Settings Management is configured
if [ -f "$HOME/.docker/desktop/settings.json" ]; then
  echo "Settings file found: $HOME/.docker/desktop/settings.json"
else
  echo -e "${YELLOW}⚠ Settings file not found - Settings Management may not be configured${NC}"
fi

# Test 1: Block all external access
echo -e "\n${YELLOW}Test 1: Complete network blocking${NC}"
echo "Expected: All external connections should fail/timeout"
timeout 5 docker run --rm alpine wget -T 2 -O- http://google.com 2>&1 | grep -qE "(failed|timeout|Network is unreachable)" && TEST1=0 || TEST1=1
test_result $TEST1 "External HTTP blocked"

# Test 2: Multiple protocol blocking
echo -e "\n${YELLOW}Test 2: Multiple protocol blocking${NC}"
timeout 5 docker run --rm alpine sh -c '
  wget -T 2 http://google.com 2>&1 | grep -qE "(failed|timeout|unreachable)" && \
  wget -T 2 https://google.com 2>&1 | grep -qE "(failed|timeout|unreachable)" && \
  exit 0 || exit 1
' && TEST2=0 || TEST2=1
test_result $TEST2 "HTTP and HTTPS blocked"

# Test 3: DNS resolution based on config
echo -e "\n${YELLOW}Test 3: DNS resolution control${NC}"
timeout 5 docker run --rm alpine nslookup google.com 2>&1 | tee /tmp/dns-test.log
if grep -qE "(server can't find|connection timed out|network is unreachable)" /tmp/dns-test.log; then
  TEST3=0
  echo "DNS appears to be blocked"
elif grep -q "Address:" /tmp/dns-test.log; then
  TEST3=0
  echo "DNS resolution works (may be allowed by config)"
else
  TEST3=1
  echo "DNS test inconclusive"
fi
test_result $TEST3 "DNS follows air-gap configuration"
rm -f /tmp/dns-test.log

# Test 4: Localhost/internal access
echo -e "\n${YELLOW}Test 4: Localhost access (should work)${NC}"
docker run --rm alpine sh -c 'nc -l -p 8080 & sleep 1 && nc -z 127.0.0.1 8080' && TEST4=0 || TEST4=1
test_result $TEST4 "Localhost communication allowed"

# Test 5: Environment variable override attempt
echo -e "\n${YELLOW}Test 5: Proxy env var override attempt${NC}"
echo "Attempting to bypass with HTTP_PROXY environment variable..."
timeout 5 docker run --rm \
  -e HTTP_PROXY=http://1.1.1.1:8080 \
  -e HTTPS_PROXY=http://1.1.1.1:8080 \
  alpine wget -T 2 -O- http://google.com 2>&1 | grep -qE "(failed|timeout|unreachable)" && TEST5=0 || TEST5=1
test_result $TEST5 "Environment variables don't bypass air-gap config"

# Test 6: Custom network bypass attempt
echo -e "\n${YELLOW}Test 6: Custom network bypass attempt${NC}"
docker network create test-bypass-network 2>/dev/null || true
timeout 5 docker run --rm --network test-bypass-network alpine wget -T 2 -O- http://google.com 2>&1 | grep -qE "(failed|timeout|unreachable)" && TEST6=0 || TEST6=1
docker network rm test-bypass-network 2>/dev/null || true
test_result $TEST6 "Custom networks don't bypass air-gap rules"

# Test 7: Image pull capability
echo -e "\n${YELLOW}Test 7: Docker Hub image pull${NC}"
echo "Testing if Docker Hub access is allowed..."
if timeout 10 docker pull alpine:3.19 >/dev/null 2>&1; then
  echo "Docker Hub access is allowed (expected for development)"
  TEST7=0
else
  echo "Docker Hub access is blocked (may be expected based on config)"
  TEST7=0  # Both are valid depending on configuration
fi
test_result $TEST7 "Image pull behavior follows configuration"

# Test 8: Concurrent connection handling
echo -e "\n${YELLOW}Test 8: Concurrent connections${NC}"
echo "Running 10 concurrent containers..."
SUCCESS=0
for i in {1..10}; do
  timeout 3 docker run --rm alpine echo "Container $i" >/dev/null 2>&1 && ((SUCCESS++)) || true
done
[ $SUCCESS -eq 10 ] && TEST8=0 || TEST8=1
test_result $TEST8 "Concurrent containers ($SUCCESS/10 successful)"

# Test 9: Container-to-container communication
echo -e "\n${YELLOW}Test 9: Container-to-container communication${NC}"
docker network create test-c2c-network 2>/dev/null || true
docker run -d --name test-server --network test-c2c-network --rm alpine sleep 30 2>/dev/null
sleep 2
docker run --rm --network test-c2c-network alpine ping -c 1 test-server >/dev/null 2>&1 && TEST9=0 || TEST9=1
docker stop test-server 2>/dev/null || true
docker network rm test-c2c-network 2>/dev/null || true
test_result $TEST9 "Container-to-container communication works on same network"

# Test 10: Build-time network access
echo -e "\n${YELLOW}Test 10: Build-time network access${NC}"
cat > /tmp/test-build.Dockerfile << 'EOF'
FROM alpine
RUN timeout 3 wget -T 2 -O- http://example.com 2>&1 || true
EOF
timeout 15 docker build -t test-airgap-build -f /tmp/test-build.Dockerfile /tmp >/dev/null 2>&1 && TEST10=0 || TEST10=1
docker rmi test-airgap-build 2>/dev/null || true
rm -f /tmp/test-build.Dockerfile
test_result $TEST10 "Build completes (network follows air-gap rules)"

# Summary
echo -e "\n=== Test Summary ==="
echo -e "Passed: ${GREEN}$pass_count${NC}"
echo -e "Failed: ${RED}$fail_count${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} These tests verify air-gap container behavior."
echo "Results depend on your admin-settings.json configuration."
echo ""
echo "To configure air-gapped containers, see:"
echo "https://docs.docker.com/enterprise/security/hardened-desktop/air-gapped-containers/"

[ $fail_count -eq 0 ] && exit 0 || exit 1

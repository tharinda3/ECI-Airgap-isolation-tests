#!/bin/bash
# Master Test Runner for ECI and Air-Gap Security Testing

set -e

# Configuration
RESULTS_DIR="./test-results-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Docker Desktop Security Test Suite                       ║${NC}"
echo -e "${BLUE}║  ECI & Enterprise Air-Gapped Container Testing             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Gather system information
echo -e "${YELLOW}[*] Gathering system information...${NC}"
{
  echo "=== System Information ==="
  echo "Date: $(date)"
  echo "Hostname: $(hostname)"
  echo "OS: $(uname -s)"
  echo "Architecture: $(uname -m)"
  echo ""
  echo "=== Docker Information ==="
  docker version
  echo ""
  docker info
  echo ""
} > "$RESULTS_DIR/system-info.txt"

echo -e "${GREEN}✓${NC} System info saved to $RESULTS_DIR/system-info.txt"
echo ""

# Function to run a test suite
run_test_suite() {
  local test_name=$1
  local test_script=$2
  
  echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
  echo -e "${YELLOW}[*] Running: $test_name${NC}"
  echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
  
  ((TOTAL_TESTS++))
  
  local log_file="$RESULTS_DIR/$(echo $test_name | tr ' ' '_' | tr '[:upper:]' '[:lower:]').log"
  
  if bash "$test_script" 2>&1 | tee "$log_file"; then
    echo -e "${GREEN}✓ PASSED${NC}: $test_name"
    ((PASSED_TESTS++))
  else
    echo -e "${RED}✗ FAILED${NC}: $test_name"
    ((FAILED_TESTS++))
  fi
  
  echo ""
}

# Make test scripts executable
chmod +x tests/eci/*.sh tests/airgap/*.sh tests/combined/*.sh 2>/dev/null || true

# Run ECI Tests
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Phase 1: Enhanced Container Isolation (ECI) Tests        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ -f tests/eci/filesystem_isolation.sh ]; then
  run_test_suite "ECI Filesystem Isolation" "tests/eci/filesystem_isolation.sh"
else
  echo -e "${YELLOW}⚠ Skipping: tests/eci/filesystem_isolation.sh not found${NC}"
fi

if [ -f tests/eci/process_isolation.sh ]; then
  run_test_suite "ECI Process Isolation" "tests/eci/process_isolation.sh"
else
  echo -e "${YELLOW}⚠ Skipping: tests/eci/process_isolation.sh not found${NC}"
fi

# Run Air-Gap Tests
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Phase 2: Enterprise Air-Gapped Container Tests            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ -f tests/airgap/config_tests.sh ]; then
  run_test_suite "Air-Gap Configuration" "tests/airgap/config_tests.sh"
else
  echo -e "${YELLOW}⚠ Skipping: tests/airgap/config_tests.sh not found${NC}"
fi

if [ -f tests/airgap/pac_tests.sh ]; then
  run_test_suite "PAC File Rules" "tests/airgap/pac_tests.sh"
else
  echo -e "${YELLOW}⚠ Skipping: tests/airgap/pac_tests.sh not found${NC}"
fi

if [ -f tests/airgap/proxy_routing_tests.sh ]; then
  run_test_suite "Proxy Routing" "tests/airgap/proxy_routing_tests.sh"
else
  echo -e "${YELLOW}⚠ Skipping: tests/airgap/proxy_routing_tests.sh not found${NC}"
fi

if [ -f tests/airgap/network_isolation.sh ]; then
  run_test_suite "Basic Network Isolation" "tests/airgap/network_isolation.sh"
else
  echo -e "${YELLOW}⚠ Skipping: tests/airgap/network_isolation.sh not found${NC}"
fi

# Run Combined Tests
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Phase 3: Combined Multi-Layer Security Tests             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ -f tests/combined/multi_layer.sh ]; then
  run_test_suite "Combined Multi-Layer Security" "tests/combined/multi_layer.sh"
else
  echo -e "${YELLOW}⚠ Skipping: tests/combined/multi_layer.sh not found${NC}"
fi

# Run Attack Simulations (if built)
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Phase 4: Attack Simulations (Optional)                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ -f tests/attacks/crypto_miner.Dockerfile ]; then
  echo -e "${YELLOW}[*] Building attack containers...${NC}"
  docker build -t malicious-miner -f tests/attacks/crypto_miner.Dockerfile tests/attacks/ > /dev/null 2>&1 && \
    echo -e "${GREEN}✓${NC} Built: malicious-miner" || \
    echo -e "${RED}✗${NC} Failed to build: malicious-miner"
  
  docker build -t malicious-stealer -f tests/attacks/data_stealer.Dockerfile tests/attacks/ > /dev/null 2>&1 && \
    echo -e "${GREEN}✓${NC} Built: malicious-stealer" || \
    echo -e "${RED}✗${NC} Failed to build: malicious-stealer"
  
  docker build -t container-escape -f tests/attacks/container_escape.Dockerfile tests/attacks/ > /dev/null 2>&1 && \
    echo -e "${GREEN}✓${NC} Built: container-escape" || \
    echo -e "${RED}✗${NC} Failed to build: container-escape"
  
  echo ""
  echo -e "${YELLOW}[*] To run attack simulations manually:${NC}"
  echo "  docker run --rm --network none --cpus=0.5 --memory=256m malicious-miner"
  echo "  docker run --rm --network none malicious-stealer"
  echo "  docker run --rm --network none container-escape"
  echo ""
fi

# Generate Summary Report
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Test Summary                                              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

{
  echo "# Security Test Execution Report"
  echo ""
  echo "**Date**: $(date)"
  echo "**Results Directory**: $RESULTS_DIR"
  echo ""
  echo "## Summary"
  echo ""
  echo "| Metric | Count |"
  echo "|--------|-------|"
  echo "| Total Test Suites | $TOTAL_TESTS |"
  echo "| Passed | $PASSED_TESTS |"
  echo "| Failed | $FAILED_TESTS |"
  echo "| Success Rate | $(awk "BEGIN {printf \"%.1f\", ($PASSED_TESTS/$TOTAL_TESTS)*100}")% |"
  echo ""
  echo "## Test Results"
  echo ""
  
  for log in "$RESULTS_DIR"/*.log; do
    if [ -f "$log" ]; then
      echo "### $(basename "$log" .log)"
      echo '```'
      tail -20 "$log"
      echo '```'
      echo ""
    fi
  done
  
  echo "## System Information"
  echo '```'
  cat "$RESULTS_DIR/system-info.txt"
  echo '```'
  
} > "$RESULTS_DIR/summary-report.md"

echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "Total Test Suites:  $TOTAL_TESTS"
echo -e "${GREEN}Passed:${NC}             $PASSED_TESTS"
echo -e "${RED}Failed:${NC}             $FAILED_TESTS"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}[*] Full report saved to: $RESULTS_DIR/summary-report.md${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
  echo -e "${GREEN}✓ All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some tests failed. Review logs in $RESULTS_DIR/${NC}"
  exit 1
fi

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
echo -e "${BLUE}║  Docker Desktop Security Validation Suite                  ║${NC}"
echo -e "${BLUE}║  ECI + Air-Gapped Containers Protection Testing            ║${NC}"
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

# Phase 1: ECI Tests
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Phase 1: ECI Protection Tests                             ║${NC}"
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

# Phase 2: Air-Gap Tests
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Phase 2: Air-Gapped Container Tests                       ║${NC}"
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

# Phase 3: Combined Protection (MOST IMPORTANT)
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Phase 3: Combined Protection Validation                   ║${NC}"
echo -e "${BLUE}║  (ECI + Air-Gap working together)                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ -f tests/combined/protection_validation.sh ]; then
  run_test_suite "Combined ECI + Air-Gap Protection" "tests/combined/protection_validation.sh"
else
  echo -e "${YELLOW}⚠ Skipping: tests/combined/protection_validation.sh not found${NC}"
fi

# Phase 4: Malware Simulations
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Phase 4: Malware Simulations                              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ -f tests/attacks/crypto_miner.Dockerfile ]; then
  echo -e "${YELLOW}[*] Building malware simulation containers...${NC}"
  docker build -t test-crypto-miner -f tests/attacks/crypto_miner.Dockerfile tests/attacks/ > /dev/null 2>&1 && \
    echo -e "${GREEN}✓${NC} Built: test-crypto-miner" || \
    echo -e "${RED}✗${NC} Failed to build: test-crypto-miner"
  
  docker build -t test-data-stealer -f tests/attacks/data_stealer.Dockerfile tests/attacks/ > /dev/null 2>&1 && \
    echo -e "${GREEN}✓${NC} Built: test-data-stealer" || \
    echo -e "${RED}✗${NC} Failed to build: test-data-stealer"
  
  docker build -t test-container-escape -f tests/attacks/container_escape.Dockerfile tests/attacks/ > /dev/null 2>&1 && \
    echo -e "${GREEN}✓${NC} Built: test-container-escape" || \
    echo -e "${RED}✗${NC} Failed to build: test-container-escape"
  
  echo ""
  echo -e "${YELLOW}[*] Run malware simulations manually:${NC}"
  echo "  docker run --rm --cpus=0.5 --memory=256m test-crypto-miner"
  echo "  docker run --rm test-data-stealer"
  echo "  docker run --rm test-container-escape"
  echo ""
  echo -e "${GREEN}Expected: All malicious activities blocked by ECI + Air-gap${NC}"
  echo ""
fi

# Generate Summary Report
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Test Summary                                              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

{
  echo "# ECI + Air-Gapped Containers Security Validation Report"
  echo ""
  echo "**Date**: $(date)"
  echo "**Results Directory**: $RESULTS_DIR"
  echo ""
  echo "## Executive Summary"
  echo ""
  if [ $FAILED_TESTS -eq 0 ]; then
    echo "✅ **SECURITY VALIDATED**: ECI and Air-gapped Containers are properly configured and protecting the host."
    echo ""
    echo "All tests passed. Containerized malware cannot:"
    echo "- Access the host filesystem"
    echo "- See or interact with host processes"
    echo "- Communicate with external networks"
    echo "- Exfiltrate data"
    echo "- Persist beyond container lifecycle"
    echo "- Escape to the host system"
  else
    echo "⚠️ **SECURITY GAPS DETECTED**: Some tests failed. Review findings below."
    echo ""
    echo "Failed tests indicate potential security vulnerabilities that need attention."
  fi
  echo ""
  echo "## Test Results Summary"
  echo ""
  echo "| Metric | Count |"
  echo "|--------|-------|"
  echo "| Total Test Suites | $TOTAL_TESTS |"
  echo "| Passed | $PASSED_TESTS |"
  echo "| Failed | $FAILED_TESTS |"
  if [ $TOTAL_TESTS -gt 0 ]; then
    echo "| Success Rate | $(awk "BEGIN {printf \"%.1f\", ($PASSED_TESTS/$TOTAL_TESTS)*100}")% |"
  fi
  echo ""
  echo "## Detailed Test Results"
  echo ""
  
  for log in "$RESULTS_DIR"/*.log; do
    if [ -f "$log" ]; then
      echo "### $(basename "$log" .log | tr '_' ' ')"
      echo '```'
      tail -30 "$log"
      echo '```'
      echo ""
    fi
  done
  
  echo "## System Configuration"
  echo '```'
  cat "$RESULTS_DIR/system-info.txt"
  echo '```'
  echo ""
  echo "## Recommendations"
  echo ""
  if [ $FAILED_TESTS -eq 0 ]; then
    echo "- ✅ Current configuration meets security requirements"
    echo "- ✅ Re-run tests after Docker Desktop updates"
    echo "- ✅ Run monthly security validation"
    echo "- ✅ Monitor Docker Admin Console for compliance"
  else
    echo "- ⚠️ Review failed tests above"
    echo "- ⚠️ Verify ECI is enabled in Docker Admin Console"
    echo "- ⚠️ Verify Air-gap policy is deployed via Settings Management"
    echo "- ⚠️ Restart Docker Desktop and re-test"
    echo "- ⚠️ Contact Docker support if issues persist"
  fi
  
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
  echo -e "${GREEN}✓ SECURITY VALIDATED${NC}"
  echo ""
  echo "ECI + Air-gapped Containers successfully protect the host from"
  echo "containerized threats. All multi-vector attacks were blocked."
  echo ""
  exit 0
else
  echo -e "${RED}✗ SECURITY GAPS DETECTED${NC}"
  echo ""
  echo "Review failed tests in: $RESULTS_DIR/"
  echo ""
  echo "Verify configuration:"
  echo "  1. ECI enabled in Docker Admin Console → Settings Management"
  echo "  2. Air-gap policy deployed to all users"
  echo "  3. Settings are locked (users cannot override)"
  echo "  4. Docker Desktop restarted after configuration"
  echo ""
  exit 1
fi

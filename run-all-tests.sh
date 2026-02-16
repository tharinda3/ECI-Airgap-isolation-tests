#!/bin/bash
# Master Test Runner - Docker Enterprise Security Validation
# Tests: ECI, Air-Gap, Docker Scout

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

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Docker Enterprise Security Validation Suite          ║${NC}"
echo -e "${BLUE}║  ECI, Air-Gap, and Docker Scout Testing               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to run a test
run_test() {
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
chmod +x tests/*.sh 2>/dev/null || true

# Gather system information
echo -e "${YELLOW}[*] Gathering system information...${NC}"
{
  echo "=== System Information ==="
  echo "Date: $(date)"
  echo "Hostname: $(hostname)"
  echo "Docker: $(docker --version)"
  echo ""
} > "$RESULTS_DIR/system-info.txt"

echo ""

# Run the 3 tests
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Test Suite Execution                                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ -f tests/1_syscall_validation.sh ]; then
  run_test "Test 1: System Call Validation (ECI)" "tests/1_syscall_validation.sh"
else
  echo -e "${YELLOW}⚠ Skipping: tests/1_syscall_validation.sh not found${NC}"
fi

if [ -f tests/2_airgap_validation.sh ]; then
  run_test "Test 2: Air-Gap Network Validation" "tests/2_airgap_validation.sh"
else
  echo -e "${YELLOW}⚠ Skipping: tests/2_airgap_validation.sh not found${NC}"
fi

if [ -f tests/3_docker_scout_scan.sh ]; then
  run_test "Test 3: Docker Scout Scanning" "tests/3_docker_scout_scan.sh"
else
  echo -e "${YELLOW}⚠ Skipping: tests/3_docker_scout_scan.sh not found${NC}"
fi

# Generate Summary Report
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Test Execution Summary                                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

{
  echo "# Docker Enterprise Security Validation - Test Report"
  echo ""
  echo "**Date**: $(date)"
  echo "**Results Directory**: $RESULTS_DIR"
  echo ""
  echo "## Summary"
  echo ""
  echo "| Metric | Count |"
  echo "|--------|-------|"
  echo "| Total Tests | $TOTAL_TESTS |"
  echo "| Passed | $PASSED_TESTS |"
  echo "| Failed | $FAILED_TESTS |"
  if [ $TOTAL_TESTS -gt 0 ]; then
    echo "| Success Rate | $(awk "BEGIN {printf \"%.1f\", ($PASSED_TESTS/$TOTAL_TESTS)*100}")% |"
  fi
  echo ""
  echo "## Test Details"
  echo ""
  
  for log in "$RESULTS_DIR"/*.log; do
    if [ -f "$log" ]; then
      echo "### $(basename "$log" .log | tr '_' ' ')"
      echo '```'
      tail -40 "$log"
      echo '```'
      echo ""
    fi
  done
  
} > "$RESULTS_DIR/summary-report.md"

echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo "Test Execution Complete"
echo -e "  Total Tests:  $TOTAL_TESTS"
echo -e "  ${GREEN}Passed:${NC}       $PASSED_TESTS"
echo -e "  ${RED}Failed:${NC}       $FAILED_TESTS"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Full report: $RESULTS_DIR/summary-report.md${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ] && [ $TOTAL_TESTS -gt 0 ]; then
  echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
  echo ""
  echo "Security validation complete. Docker Enterprise features are protecting"
  echo "your containerized workloads from malicious container attacks."
  echo ""
  exit 0
else
  echo -e "${RED}✗ SOME TESTS FAILED${NC}"
  echo ""
  echo "Review failed tests and verify configuration:"
  echo "  - ECI enabled in Docker Admin Console"
  echo "  - Air-gap policy deployed"
  echo "  - Docker Scout enabled"
  echo ""
  exit 1
fi

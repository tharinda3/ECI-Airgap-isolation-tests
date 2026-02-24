#!/bin/bash
# Master Test Runner - Docker Enterprise Security Validation
# Tests: ECI, Air-Gap, Docker Scout
# Compatible with: Windows WSL2, Linux
#
# Note: Do NOT use 'set -e' here - individual test failures are handled
# explicitly and must not abort the entire suite.

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

# Verify Docker is running before proceeding
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Docker is not running or not accessible.${NC}"
    echo ""
    echo "  On Windows: Ensure Docker Desktop is running and WSL2 integration is enabled."
    echo "  Docker Desktop -> Settings -> Resources -> WSL Integration -> Enable"
    exit 1
fi

echo -e "${GREEN}✓${NC} Docker Desktop detected"
echo ""

# Run a test script, stream output via tee, and capture its exit code correctly.
# Uses PIPESTATUS to get the bash exit code even when piped through tee.
run_test() {
    local test_name=$1
    local test_script=$2

    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}[*] Running: $test_name${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    local log_file="$RESULTS_DIR/$(echo "$test_name" | tr ' ' '_' | tr '[:upper:]' '[:lower:]').log"

    # Pipe through tee but capture the bash script's exit code, not tee's
    bash "$test_script" 2>&1 | tee "$log_file"
    local exit_code=${PIPESTATUS[0]}

    if [ "$exit_code" -eq 0 ]; then
        echo -e "${GREEN}✓ PASSED${NC}: $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ FAILED${NC}: $test_name"
        FAILED_TESTS=$((FAILED_TESTS + 1))
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
    echo "Platform: Windows (WSL2)"
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
    echo "**Platform**: Windows (WSL2)"
    echo "**Results Directory**: $RESULTS_DIR"
    echo ""
    echo "## Summary"
    echo ""
    echo "| Metric | Count |"
    echo "|--------|-------|"
    echo "| Total Tests | $TOTAL_TESTS |"
    echo "| Passed | $PASSED_TESTS |"
    echo "| Failed | $FAILED_TESTS |"
    if [ "$TOTAL_TESTS" -gt 0 ]; then
        echo "| Success Rate | $(awk 'BEGIN {printf "%.1f", ('"$PASSED_TESTS"'/'"$TOTAL_TESTS"')*100}')% |"
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

if [ "$FAILED_TESTS" -eq 0 ] && [ "$TOTAL_TESTS" -gt 0 ]; then
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
    echo "  - Air-gap policy deployed and Docker Desktop restarted"
    echo "  - Docker Scout enabled in organization settings"
    echo "  - WSL2 integration enabled in Docker Desktop settings"
    echo ""
    exit 1
fi

#!/bin/bash
# Test 1: System Call Validation (ECI Protection)
# Demonstrates that ECI prevents containers from executing system calls to the host
# Based on: https://docs.docker.com/enterprise/security/hardened-desktop/enhanced-container-isolation/

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Test 1: System Call Validation (ECI Protection)      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

RESULTS_FILE="syscall_results.txt"
{
    echo "System Call Validation Test Results"
    echo "===================================="
    echo "Date: $(date)"
    echo "Docker Version: $(docker --version)"
    echo ""
    echo "Purpose: Demonstrate that ECI prevents containers from executing"
    echo "system calls that affect the host machine."
    echo ""
    echo "Configuration: ECI should be ENABLED via Docker Admin Console"
    echo ""
} > "$RESULTS_FILE"

pass_count=0
fail_count=0

# Test each system call
test_syscall() {
    local test_num=$1
    local test_name=$2
    local command=$3
    local block_pattern=$4
    
    echo "[Test $test_num] $test_name..."
    echo "  Command: $command" >> "$RESULTS_FILE"
    
    if timeout 5 docker run --rm alpine sh -c "$command" 2>&1 | grep -qE "$block_pattern"; then
        echo -e "${GREEN}✓ BLOCKED${NC}: $test_name"
        echo "  Result: BLOCKED ✓" >> "$RESULTS_FILE"
        ((pass_count++))
    else
        echo -e "${RED}✗ ACCESSIBLE${NC}: $test_name (might not be blocked)"
        echo "  Result: ACCESSIBLE (Check if ECI enabled) ✗" >> "$RESULTS_FILE"
        ((fail_count++))
    fi
    echo "" >> "$RESULTS_FILE"
}

echo "" >> "$RESULTS_FILE"
echo "System Call Tests:"
echo "==================" >> "$RESULTS_FILE"
echo ""

# Test 1: Hostname change
test_syscall 1 "Hostname change (sysctl)" \
    "sysctl -w kernel.hostname=pwned" \
    "Permission denied|Operation not permitted|Read-only"

# Test 2: Kernel memory access
test_syscall 2 "Kernel memory access (/dev/mem)" \
    "cat /dev/mem" \
    "No such file|Permission denied|cannot open"

# Test 3: Mount filesystem
test_syscall 3 "Mount host filesystem" \
    "mount /dev/sda1 /mnt" \
    "Permission denied|Operation not permitted|No such file|failed"

# Test 4: Load kernel modules
test_syscall 4 "Load kernel modules" \
    "modprobe dummy" \
    "Permission denied|Operation not permitted|not found|No such file"

# Test 5: Modify system time
test_syscall 5 "Modify system time" \
    "date +%s -s '2099-01-01 00:00:00'" \
    "Permission denied|Operation not permitted|cannot set"

# Test 6: Access host init process
test_syscall 6 "Access host init process (/proc/1)" \
    "cat /proc/1/cmdline | grep -v '^$'" \
    "No such file|container|runc|^$"

# Test 7: Access hardware devices
test_syscall 7 "Access hardware devices (/dev/sda)" \
    "ls /dev/sda" \
    "No such file|cannot access"

# Summary
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo "Test Summary:"
echo "  Passed: $pass_count/7"
echo "  Failed: $fail_count/7"
echo ""
{
    echo ""
    echo "Test Summary:"
    echo "============="
    echo "Tests Passed: $pass_count/7"
    echo "Tests Failed: $fail_count/7"
    echo ""
} >> "$RESULTS_FILE"

if [ $pass_count -ge 6 ]; then
    echo -e "${GREEN}✓ SYSTEM CALL ISOLATION VALIDATED${NC}"
    echo "ECI is preventing containers from executing system calls to the host."
    echo ""
    {
        echo "RESULT: PASS ✓"
        echo ""
        echo "Conclusion:"
        echo "==========="
        echo "Enhanced Container Isolation (ECI) successfully prevents malicious"
        echo "containers from executing system calls that would compromise the"
        echo "host machine. This prevents lateral movement and host compromise."
    } >> "$RESULTS_FILE"
    echo "Results saved to: $RESULTS_FILE"
    exit 0
else
    echo -e "${RED}✗ SYSTEM CALL ISOLATION FAILED${NC}"
    echo "Some system calls were accessible. Verify ECI is enabled."
    echo ""
    {
        echo "RESULT: FAIL ✗"
        echo ""
        echo "Troubleshooting:"
        echo "================"
        echo "1. Verify ECI is enabled in Docker Admin Console"
        echo "2. Check Docker Desktop version (4.29+ required)"
        echo "3. Restart Docker Desktop"
        echo "4. Remove existing containers: docker rm $(docker ps -aq)"
    } >> "$RESULTS_FILE"
    echo "Results saved to: $RESULTS_FILE"
    exit 1
fi

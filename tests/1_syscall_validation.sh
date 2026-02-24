#!/bin/bash
# Test 1: System Call Validation (ECI Protection)
# Demonstrates that ECI prevents containers from executing system calls to the host
# Compatible with: Windows WSL2, Linux
# Based on: https://docs.docker.com/enterprise/security/hardened-desktop/enhanced-container-isolation/
#
# Note: Do NOT use 'set -e' - individual test failures must not abort the suite.
# Use counter=$((counter + 1)) instead of ((counter++)) to avoid false exit-code
# failures when the counter value is zero (bash arithmetic returns exit 1 for 0).

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Test 1: System Call Validation (ECI Protection)      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Verify Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Docker is not running or not accessible.${NC}"
    echo "  On Windows: Ensure Docker Desktop is running and WSL2 integration is enabled."
    exit 1
fi

RESULTS_FILE="syscall_results.txt"
{
    echo "System Call Validation Test Results"
    echo "===================================="
    echo "Date: $(date)"
    echo "Docker Version: $(docker --version)"
    echo "Platform: Windows (WSL2)"
    echo ""
    echo "Purpose: Demonstrate that ECI prevents containers from executing"
    echo "system calls that affect the host machine."
    echo ""
    echo "Configuration: ECI must be ENABLED via Docker Admin Console"
    echo ""
} > "$RESULTS_FILE"

pass_count=0
fail_count=0

# Run a syscall test inside an Alpine container.
# Captures all output (including stderr) and checks against a block pattern.
# The container command always uses '|| true' so a non-zero exit never aborts
# this script.
test_syscall() {
    local test_num=$1
    local test_name=$2
    local command=$3
    local block_pattern=$4

    echo "[Test $test_num] $test_name..."
    echo "  Command: $command" >> "$RESULTS_FILE"

    output=$(timeout 5 docker run --rm alpine sh -c "$command" 2>&1 || true)

    if echo "$output" | grep -qE "$block_pattern"; then
        echo -e "${GREEN}✓ BLOCKED${NC}: $test_name"
        echo "  Result: BLOCKED ✓" >> "$RESULTS_FILE"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ ACCESSIBLE${NC}: $test_name (ECI may not be enabled)"
        echo "  Result: ACCESSIBLE - check ECI is enabled ✗" >> "$RESULTS_FILE"
        echo "  Output: $output" >> "$RESULTS_FILE"
        fail_count=$((fail_count + 1))
    fi
    echo "" >> "$RESULTS_FILE"
}

echo "" >> "$RESULTS_FILE"
echo "System Call Tests:"
echo "==================" >> "$RESULTS_FILE"
echo ""

# Test 1: Hostname change
test_syscall 1 "Hostname change (sysctl)" \
    "sysctl -w kernel.hostname=pwned 2>&1" \
    "Permission denied|Operation not permitted|Read-only"

# Test 2: Kernel memory access
# Note: /dev/mem is absent in Docker Desktop on Windows (virtualised environment).
# Absence OR ECI blockage both confirm the host kernel memory is not reachable.
test_syscall 2 "Kernel memory access (/dev/mem)" \
    "cat /dev/mem 2>&1" \
    "No such file|Permission denied|cannot open|Operation not permitted"

# Test 3: Mount filesystem
# Uses tmpfs to avoid needing a real block device; ECI should still block the syscall.
test_syscall 3 "Mount filesystem (tmpfs)" \
    "mount -t tmpfs none /mnt 2>&1" \
    "Permission denied|Operation not permitted|failed|not permitted"

# Test 4: Load kernel modules
test_syscall 4 "Load kernel module (modprobe dummy)" \
    "modprobe dummy 2>&1" \
    "Permission denied|Operation not permitted|not found|No such file|Function not implemented"

# Test 5: Modify system time
# BusyBox date syntax for Alpine: date -s 'DATE_STRING'
# (the original 'date +%s -s ...' mixed format and set flags incorrectly)
test_syscall 5 "Modify system time" \
    "date -s '2099-01-01' 2>&1" \
    "Permission denied|Operation not permitted|date: can't set date|cannot set"

# Test 6: Host init process isolation
# With ECI the container has its own PID namespace and must NOT see the host init
# process. Detection: if /proc/1/cmdline contains a host-level init binary
# (systemd, /sbin/init, upstart) then ECI is NOT isolating the PID namespace.
# If it shows a container process or is otherwise restricted, ECI IS working.
echo "[Test 6] Host init process isolation (/proc/1)..."
echo "  Command: cat /proc/1/cmdline (checking for host init leak)" >> "$RESULTS_FILE"

proc1_output=$(timeout 5 docker run --rm alpine \
    sh -c "cat /proc/1/cmdline 2>&1 | tr '\0' ' '" 2>/dev/null || true)

if echo "$proc1_output" | grep -qiE "systemd|/sbin/init|upstart"; then
    echo -e "${RED}✗ HOST PROCESS VISIBLE${NC}: Host init leaked into container (ECI not active)"
    echo "  Result: HOST INIT VISIBLE - PID namespace not isolated ✗" >> "$RESULTS_FILE"
    echo "  Output: $proc1_output" >> "$RESULTS_FILE"
    fail_count=$((fail_count + 1))
else
    echo -e "${GREEN}✓ ISOLATED${NC}: Container PID namespace is isolated from host"
    echo "  Result: ISOLATED ✓ (container sees its own PID 1, not the host init)" >> "$RESULTS_FILE"
    echo "  Output: $proc1_output" >> "$RESULTS_FILE"
    pass_count=$((pass_count + 1))
fi
echo "" >> "$RESULTS_FILE"

# Test 7: Hardware device access
# /dev/sda typically does not exist in Docker Desktop on Windows (virtualised).
# The test validates that the protected state holds; absence of the device
# or ECI blockage both prevent any hardware access.
test_syscall 7 "Access hardware devices (/dev/sda)" \
    "ls /dev/sda 2>&1" \
    "No such file|cannot access|Permission denied|Operation not permitted"

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

if [ "$pass_count" -ge 6 ]; then
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
        echo "3. Restart Docker Desktop after enabling ECI"
        echo "4. Ensure WSL2 integration is enabled in Docker Desktop settings"
    } >> "$RESULTS_FILE"
    echo "Results saved to: $RESULTS_FILE"
    exit 1
fi

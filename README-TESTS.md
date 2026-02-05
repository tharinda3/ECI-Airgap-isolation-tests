# Security Test Suite - Quick Start

This test suite validates Enhanced Container Isolation (ECI) and air-gapped container security in Docker Desktop.

## Quick Start

```bash
# Run all tests
./run-all-tests.sh

# Run individual test suites
./tests/eci/filesystem_isolation.sh
./tests/eci/process_isolation.sh
./tests/airgap/network_isolation.sh
./tests/combined/multi_layer.sh
```

## Prerequisites

- Docker Desktop installed (macOS/Windows)
- Enhanced Container Isolation (ECI) enabled in Docker Desktop settings
- Bash shell
- Basic network utilities (included in most systems)

## Enabling ECI in Docker Desktop

1. Open Docker Desktop
2. Go to Settings → General
3. Enable "Use Enhanced Container Isolation"
4. Apply & Restart

## Test Categories

### 1. ECI Tests (`tests/eci/`)
Tests that verify the VM-based isolation provided by ECI:
- Filesystem isolation from host
- Process visibility isolation
- Kernel-level protection
- Resource limit enforcement

### 2. Air-Gap Tests (`tests/airgap/`)
Tests that verify network isolation (--network none):
- Outbound connection blocking
- DNS resolution blocking
- Container-to-container isolation
- Data exfiltration prevention

### 3. Combined Tests (`tests/combined/`)
Tests that verify defense-in-depth with both ECI + air-gap:
- Multi-vector attacks
- Resource exhaustion
- Persistence prevention
- Privilege escalation attempts

### 4. Attack Simulations (`tests/attacks/`)
Realistic malicious container scenarios:
- Crypto miner simulation
- Data exfiltration attempts
- Container escape attempts

## Understanding Results

### Expected Behaviors

✅ **PASS** indicators mean:
- Host filesystem is protected
- Network isolation is working
- Resource limits are enforced
- Malicious actions are blocked

❌ **FAIL** indicators mean:
- Security boundary was breached
- Isolation mechanism failed
- Further investigation needed

### Example Output

```
=== Test Summary ===
Passed: 8
Failed: 0
```

## Running Attack Simulations

Build and run the malicious container examples:

```bash
# Build attack containers
docker build -t malicious-miner -f tests/attacks/crypto_miner.Dockerfile tests/attacks/
docker build -t malicious-stealer -f tests/attacks/data_stealer.Dockerfile tests/attacks/
docker build -t container-escape -f tests/attacks/container_escape.Dockerfile tests/attacks/

# Run with protections
docker run --rm --network none --cpus=0.5 --memory=256m malicious-miner
docker run --rm --network none malicious-stealer
docker run --rm --network none container-escape
```

All attacks should be contained and blocked.

## Interpreting Test Results

### Filesystem Isolation
- Tests verify containers cannot access `/Users/`, `/System/`, `/Applications/`
- Mounted volumes are properly scoped
- Symlink and path traversal attacks fail

### Process Isolation
- Containers cannot see or signal host processes
- `/proc` filesystem shows only container PIDs
- Kernel module loading is restricted

### Network Isolation
- All outbound connections blocked (HTTP, HTTPS, DNS, ICMP)
- No network interfaces except loopback
- Container-to-container communication prevented

### Resource Protection
- CPU bombs are rate-limited
- Memory exhaustion triggers OOM killer
- Disk fills respect quotas

## Results Directory

After running tests, check `test-results-*/`:
- `summary-report.md` - Overall results
- `system-info.txt` - Environment details
- `*.log` - Individual test logs

## Customizing Tests

Edit test scripts to:
- Add new attack vectors
- Test specific CVEs
- Adjust timeouts and limits
- Add custom validations

## Troubleshooting

**Docker daemon not running**
```bash
# macOS/Windows: Start Docker Desktop
open -a Docker
```

**Permission denied**
```bash
# Make scripts executable
chmod +x run-all-tests.sh tests/*/*.sh
```

**Network tests failing unexpectedly**
- Ensure no VPN or proxy is interfering
- Check Docker Desktop network settings
- Verify `--network none` is properly isolating

**ECI tests failing**
- Verify ECI is enabled in Docker Desktop settings
- Restart Docker Desktop after enabling
- Check Docker Desktop version supports ECI

## Advanced Testing

### Manual Test Execution

```bash
# Test specific scenario
docker run --rm --network none alpine sh -c 'wget http://google.com'
# Should fail with "Network is unreachable"

# Test with ECI + air-gap + limits
docker run --rm \
  --network none \
  --cpus=0.5 \
  --memory=256m \
  --read-only \
  alpine sh -c 'echo "protected"'
```

### Monitoring During Tests

```bash
# Terminal 1: Run tests
./run-all-tests.sh

# Terminal 2: Monitor Docker
watch -n 1 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Networks}}"'

# Terminal 3: Monitor system resources (macOS)
top -o cpu
```

## Contributing

To add new tests:

1. Create test script in appropriate directory
2. Follow naming convention: `test_name.sh`
3. Use standard output format (PASS/FAIL with colors)
4. Update `run-all-tests.sh` to include new test
5. Document expected behavior

## References

- [Docker Desktop Enhanced Container Isolation](https://docs.docker.com/desktop/hardened-desktop/enhanced-container-isolation/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Container Security Guide](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)

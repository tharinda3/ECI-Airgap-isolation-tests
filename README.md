# Docker Security Test Suite

Comprehensive security testing for Docker Desktop's Enhanced Container Isolation (ECI) and air-gapped containers.

## Overview

This test suite validates that Docker Desktop's security features protect the host machine from malicious containers by testing:

- **Enhanced Container Isolation (ECI)**: VM-based isolation that prevents container escapes
- **Air-gapped Containers**: Network isolation that prevents data exfiltration
- **Defense-in-Depth**: Combined protections against multi-vector attacks

## Quick Start

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/docker-security-tests.git
cd docker-security-tests

# Run all tests
./run-all-tests.sh
```

## Prerequisites

- Docker Desktop (macOS or Windows)
- Enhanced Container Isolation enabled in Docker Desktop settings
- Bash shell

## What Gets Tested

### 🔒 Filesystem Isolation
- Host filesystem access prevention
- Volume mount boundaries
- Symlink and path traversal attacks
- Docker socket protection

### ⚙️ Process Isolation
- Host process visibility
- Process signaling restrictions
- Kernel module loading prevention
- Privileged container containment

### 🌐 Network Isolation
- Outbound connection blocking (HTTP, HTTPS, DNS, ICMP)
- Data exfiltration prevention
- Container-to-container isolation
- Metadata service protection

### 💣 Attack Simulations
- Crypto miner with C2 communication
- Multi-vector data exfiltration
- Container escape attempts
- Resource exhaustion attacks

## Test Results

After running tests, check the `test-results-*/` directory for:
- `summary-report.md` - Overall results and findings
- Individual test logs
- System information

## Documentation

- **[README-TESTS.md](README-TESTS.md)** - Detailed testing guide
- **[test-plan.md](test-plan.md)** - Complete test plan and methodology

## Example Output

```
╔════════════════════════════════════════════════════════════╗
║  Phase 1: Enhanced Container Isolation (ECI) Tests        ║
╚════════════════════════════════════════════════════════════╝

✓ PASS: Container cannot access /Users
✓ PASS: Container cannot access /System
✓ PASS: Symlink escape prevented
...

═══════════════════════════════════════════════════
Total Test Suites:  4
Passed:             4
Failed:             0
═══════════════════════════════════════════════════
✓ All tests passed!
```

## Running Individual Tests

```bash
# Test specific security aspect
./tests/eci/filesystem_isolation.sh
./tests/eci/process_isolation.sh
./tests/airgap/network_isolation.sh
./tests/combined/multi_layer.sh
```

## Attack Simulations

Build and test malicious container scenarios:

```bash
# Build attack containers
docker build -t malicious-miner -f tests/attacks/crypto_miner.Dockerfile tests/attacks/
docker build -t malicious-stealer -f tests/attacks/data_stealer.Dockerfile tests/attacks/
docker build -t container-escape -f tests/attacks/container_escape.Dockerfile tests/attacks/

# Run with security protections
docker run --rm --network none --cpus=0.5 --memory=256m malicious-miner
docker run --rm --network none malicious-stealer
docker run --rm --network none container-escape
```

All attacks should be contained and blocked.

## Contributing

Contributions welcome! To add new tests:

1. Create test script in appropriate directory
2. Follow the existing format and naming conventions
3. Update `run-all-tests.sh` to include the new test
4. Document expected behavior

## License

MIT License - See LICENSE file for details

## Security Disclosure

If you discover a security issue that bypasses Docker Desktop's protections, please report it responsibly to Docker Security.

## References

- [Docker Desktop Enhanced Container Isolation](https://docs.docker.com/desktop/hardened-desktop/enhanced-container-isolation/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [OWASP Container Security](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)

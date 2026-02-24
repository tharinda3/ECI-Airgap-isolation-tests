# Docker Enterprise Security Validation Suite

Validate that Docker Enterprise security features protect containerized workloads from malicious container attacks.

## Purpose

This test suite validates three critical Docker Enterprise security features:

1. **Enhanced Container Isolation (ECI)**: Prevents containers from executing system calls to the host
2. **Air-Gapped Containers**: Restricts container network access to approved destinations only
3. **Docker Scout**: Identifies and tracks vulnerabilities in container images

## Prerequisites

- **Docker Business Subscription**
- **Docker Desktop 4.29+** with WSL2 backend
- **Windows 10/11 with WSL2** - install by running in PowerShell as Administrator:
  ```
  wsl --install
  ```
- **Admin access** to Docker Admin Console
- Settings Management enabled for ECI and Air-Gap

> **WSL2 Integration**: In Docker Desktop go to Settings -> Resources -> WSL Integration and enable it for your WSL2 distro.

## Quick Start

**Windows CMD** (calls WSL2 automatically):
```
git clone https://github.com/tharinda3/ECI-Airgap-isolation-tests.git
cd ECI-Airgap-isolation-tests
run-all-tests.bat
```

**Windows WSL2 terminal**:
```bash
git clone https://github.com/tharinda3/ECI-Airgap-isolation-tests.git
cd ECI-Airgap-isolation-tests

# Run all tests
bash run-all-tests.sh

# Run individual tests
bash tests/1_syscall_validation.sh      # Test ECI system call isolation
bash tests/2_airgap_validation.sh       # Test air-gap network control
bash tests/3_docker_scout_scan.sh       # Test vulnerability scanning
```

## Test Suite Overview

### Test 1: System Call Validation (ECI)
**What it tests**: Enhanced Container Isolation prevents containers from executing system calls to the host machine.

**Key scenarios** (7 tests):
- Hostname changes (blocked by ECI)
- Kernel memory access (blocked by ECI)
- Filesystem mounting (blocked by ECI)
- Kernel module loading (blocked by ECI)
- System time modification (blocked by ECI)
- Host process access / PID namespace isolation (blocked by ECI)
- Hardware device access (blocked by ECI)

**Evidence generated**: `syscall_results.txt`

### Test 2: Air-Gap Network Validation
**What it tests**: Air-gapped containers prevent malicious network access while allowing approved destinations.

**Policy**: Only `docker.com` and `*.docker.com` on port 443 are accessible.

> **Note**: `docker.io` is a **separate domain** from `docker.com` and is not covered by the `*.docker.com` pattern. It will be blocked by this policy.

**Key scenarios** (6 tests):
- docker.com HTTPS (allowed)
- google.com HTTPS (blocked)
- github.com HTTPS (blocked)
- HTTP port 80 (blocked - only port 443 in transparentPorts)
- Port 8080 (blocked)
- Direct IP access 8.8.8.8 (blocked - prevents allowlist bypass)

**Evidence generated**: `air_gap_results.txt`

### Test 3: Docker Scout Vulnerability Scanning
**What it tests**: Docker Scout enables administrators to identify and track vulnerabilities in container images.

**Capabilities**:
- Automatic image scanning and indexing
- Software Bill of Materials (SBOM) generation
- Vulnerability identification (Critical/High/Medium/Low)
- Before/after remediation tracking

**Evidence generated**: `docker_scout_results.txt`

## Configuration

### Enable Enhanced Container Isolation (ECI)

**Via Docker Admin Console:**
1. Go to Settings Management
2. Enable "Enhanced Container Isolation"
3. Lock the setting
4. Deploy to organization
5. Users restart Docker Desktop

**Verify ECI is active:**
```bash
docker run --rm alpine ps aux | wc -l  # Should show < 10 processes
```

### Configure Air-Gapped Containers

**Via Docker Admin Console (Settings Management):**
```json
{
  "configurationFileVersion": 2,
  "containersProxy": {
    "locked": true,
    "mode": "manual",
    "http": "",
    "https": "",
    "exclude": ["docker.com", "*.docker.com"],
    "transparentPorts": "443"
  }
}
```

> Setting `transparentPorts` to `443` only (not `80,443`) ensures HTTP port 80 is also blocked.

**Deploy:**
1. Configure in Settings Management
2. Click Deploy
3. Users restart Docker Desktop

**Verify air-gap is active:**
```bash
# Should succeed
docker run --rm alpine wget -q -O- https://docker.com

# Should fail
docker run --rm alpine wget -q -O- https://google.com
```

### Enable Docker Scout

**Via Docker Hub:**
1. Go to Repository Settings
2. Enable "Docker Scout"
3. Enable "Index on push"

**Verify Scout is enabled:**
```bash
docker scout cves <image>
```

## Test Results

After running tests, reports are generated in `test-results-[timestamp]/`:

- `summary-report.md` - Executive summary of all test results
- `syscall_results.txt` - ECI system call validation results
- `air_gap_results.txt` - Air-gap network validation results
- `docker_scout_results.txt` - Docker Scout configuration and setup
- `system-info.txt` - Environment details

## Success Criteria

### Test 1 Passes When:
- At least 6 of 7 system calls blocked WITH ECI enabled
- Evidence shows ECI prevents host compromise

### Test 2 Passes When:
- docker.com accessible WITH air-gap enabled
- google.com and github.com blocked
- HTTP port 80 and port 8080 blocked
- Direct IP access blocked

### Test 3 Passes When:
- Docker Scout enabled and images indexed
- SBOM generated and accessible
- Vulnerabilities identified
- Remediation tracked with before/after comparison

## Security Statement

**When all tests pass, you can state:**

> We have validated Docker Enterprise security features:
>
> 1. **ECI Protection**: Enhanced Container Isolation prevents containers from accessing host resources, blocking lateral movement and host compromise attacks.
>
> 2. **Air-Gap Protection**: Air-gapped Containers restrict network communication to approved destinations only, preventing data exfiltration and command-and-control communication.
>
> 3. **Scout Vulnerability Management**: Docker Scout enables automatic vulnerability identification and tracking through SBOM analysis, enabling rapid remediation.
>
> These combined controls provide comprehensive protection for containerized workloads.

## Documentation

See **[test-plan.md](test-plan.md)** for detailed test methodology:
- https://docs.docker.com/enterprise/security/hardened-desktop/enhanced-container-isolation/
- https://docs.docker.com/enterprise/security/hardened-desktop/air-gapped-containers/
- https://docs.docker.com/scout/

## License

MIT License

---

**Questions?** Refer to Docker Enterprise documentation or contact Docker support.

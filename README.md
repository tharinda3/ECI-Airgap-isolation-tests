# Docker Enterprise Security Validation Suite

Validate that Docker Enterprise security features protect containerized workloads from malicious container attacks.

## 🎯 Purpose

This test suite validates three critical Docker Enterprise security features:

1. **Enhanced Container Isolation (ECI)**: Prevents containers from executing system calls to the host
2. **Air-Gapped Containers**: Restricts container network access to approved destinations only
3. **Docker Scout**: Identifies and tracks vulnerabilities in container images

## 📋 Prerequisites

- **Docker Business Subscription**
- **Docker Desktop 4.29+**
- **Admin access** to Docker Admin Console
- Settings Management enabled for ECI and Air-Gap

## 🚀 Quick Start

```bash
# Clone repository
git clone https://github.com/tharinda3/ECI-Airgap-isolation-tests.git
cd ECI-Airgap-isolation-tests

# Run all tests
./run-all-tests.sh

# Run individual tests
./tests/1_syscall_validation.sh      # Test ECI system call isolation
./tests/2_airgap_validation.sh       # Test air-gap network control
./tests/3_docker_scout_scan.sh       # Test vulnerability scanning
```

## 📊 Test Suite Overview

### Test 1: System Call Validation (ECI)
**What it tests**: Enhanced Container Isolation prevents containers from executing system calls to the host machine.

**Key scenarios**:
- Hostname changes (blocked by ECI)
- Kernel memory access (blocked by ECI)
- Filesystem mounting (blocked by ECI)
- Kernel module loading (blocked by ECI)
- System time modification (blocked by ECI)
- Host process access (blocked by ECI)
- Hardware device access (blocked by ECI)

**Evidence generated**: `syscall_results.txt` - Before/after comparison showing ECI protection

### Test 2: Air-Gap Network Validation
**What it tests**: Air-gapped containers prevent malicious network access while allowing approved destinations.

**Configuration**: Only docker.com and docker.io are accessible
- All other public URLs blocked
- HTTP/HTTPS ports 80 and 443 only
- Non-standard ports blocked
- DNS tunneling prevented

**Key scenarios**:
- docker.com access (allowed)
- google.com access (blocked)
- github.com access (blocked)
- External URLs (blocked)
- Alternative ports (blocked)

**Evidence generated**: `air_gap_results.txt` - Before/after network access comparison

### Test 3: Docker Scout Vulnerability Scanning
**What it tests**: Docker Scout enables administrators to identify and track vulnerabilities in container images.

**Capabilities**:
- Automatic image scanning and indexing
- Software Bill of Materials (SBOM) generation
- Vulnerability identification (Critical/High/Medium/Low)
- Before/after remediation tracking

**Process**:
1. Enable Docker Scout in organization
2. Push images to registry (auto-scanned)
3. View SBOM and vulnerabilities
4. Update vulnerable packages
5. Re-scan to verify remediation

**Evidence generated**: `docker_scout_results.txt` - Setup guide and remediation tracking

## 🔧 Configuration

### Enable Enhanced Container Isolation (ECI)

**Via Docker Admin Console:**
1. Go to Settings Management
2. Enable "Enhanced Container Isolation"
3. Lock the setting
4. Deploy to organization

**Verify ECI is working:**
```bash
docker run --rm alpine ps aux | wc -l  # Should show < 10 processes
```

### Configure Air-Gapped Containers

**Via Docker Admin Console:**
```json
{
  "configurationFileVersion": 2,
  "containersProxy": {
    "locked": true,
    "mode": "manual",
    "http": "",
    "https": "",
    "exclude": ["docker.com", "*.docker.com"],
    "transparentPorts": "80,443"
  }
}
```

**Deploy:**
1. Configure in Settings Management
2. Click Deploy
3. Users restart Docker Desktop

**Verify air-gap is working:**
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

## 📈 Test Results

After running tests, detailed reports are generated in `test-results-[timestamp]/`:

- `summary-report.md` - Executive summary of all test results
- `syscall_results.txt` - ECI system call validation results
- `air_gap_results.txt` - Air-gap network validation results
- `docker_scout_results.txt` - Docker Scout configuration and setup
- `system-info.txt` - Environment details

## ✅ Success Criteria

### Test 1 Passes When:
- ✅ All 7 system calls blocked WITH ECI
- ✅ Before/after comparison documents difference
- ✅ Evidence shows ECI prevents host compromise

### Test 2 Passes When:
- ✅ docker.com accessible WITH air-gap
- ✅ google.com blocked WITH air-gap
- ✅ All other URLs blocked
- ✅ Non-standard ports blocked

### Test 3 Passes When:
- ✅ Docker Scout enabled and operational
- ✅ Images indexed automatically
- ✅ SBOM generated and accessible
- ✅ Vulnerabilities identified
- ✅ Remediation tracked

## 🔐 Security Statement

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

## 📚 Documentation

See **[TEST-PLAN.md](TEST-PLAN.md)** for detailed test methodology based on official Docker documentation:
- https://docs.docker.com/enterprise/security/hardened-desktop/enhanced-container-isolation/
- https://docs.docker.com/enterprise/security/hardened-desktop/air-gapped-containers/
- https://docs.docker.com/scout/

## 📝 License

MIT License

---

**Questions?** Refer to Docker Enterprise documentation or contact Docker support.

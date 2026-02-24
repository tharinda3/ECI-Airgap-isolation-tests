# Docker Enterprise Security Validation Test Plan
## ECI, Air-Gap, and Docker Scout Testing

**Purpose**: Validate that Docker Enterprise security features (ECI, Air-Gap, Docker Scout) effectively protect container workloads and prevent malicious container attacks on the host system.

**Platform**: Windows 10/11 with WSL2 and Docker Desktop 4.29+

---

## Test 1: System Call Validation (ECI Protection)

### Objective
Demonstrate that Enhanced Container Isolation (ECI) prevents containers from executing system calls that affect the host machine, protecting against lateral movement and host compromise.

### Before and After Comparison

**WITHOUT ECI**: System calls can potentially succeed (baseline - vulnerability)
**WITH ECI**: All critical system calls are blocked (protected - ECI working)

### Test Scenarios

| System Call | Purpose | Without ECI | With ECI | Protection |
|---|---|---|---|---|
| Change hostname | Host identity manipulation | May succeed | BLOCKED | Container cannot spoof host |
| Access /dev/mem | Kernel memory access | May succeed | BLOCKED | No kernel memory access |
| Mount filesystem | Host filesystem access | May succeed | BLOCKED | Cannot access host filesystem |
| Load kernel modules | Kernel modification | May succeed | BLOCKED | Cannot modify kernel |
| Modify system time | System time manipulation | May succeed | BLOCKED | Cannot manipulate host time |
| Access /proc/1 | Host init process | May succeed | BLOCKED | Host PID namespace isolated |
| Access /dev/sda | Hardware devices | May succeed | BLOCKED | No hardware access |

### Expected Results

**WITH ECI ENABLED** (Protected State):
```
Test 1 - Hostname change:         BLOCKED
Test 2 - /dev/mem access:         BLOCKED
Test 3 - Mount operation:         BLOCKED
Test 4 - Module loading:          BLOCKED
Test 5 - Time modification:       BLOCKED
Test 6 - Host init process:       ISOLATED (container sees its own PID 1)
Test 7 - Hardware device access:  BLOCKED

Result: All system calls prevented
Evidence: ECI successfully prevents lateral movement and host compromise
```

### Configuration

**Enable ECI via Docker Admin Console:**
1. Go to Settings Management
2. Enable "Enhanced Container Isolation"
3. Lock the setting
4. Deploy to organization
5. Users restart Docker Desktop

**Verification:**
```bash
# ECI is active when process count is low (<10)
docker run --rm alpine ps aux | wc -l  # Should be < 10
```

### Pass Criteria
- At least 6 of 7 system calls blocked WITH ECI
- Evidence shows ECI prevents host compromise
- Results in `syscall_results.txt`

---

## Test 2: Air-Gap Network Validation

### Objective
Demonstrate that Air-Gapped Containers prevent malicious container network access while allowing approved destinations, preventing data exfiltration and command-and-control communication.

### Before and After Comparison

**WITHOUT AIR-GAP**: Container can access any external URL (baseline - vulnerability)
**WITH AIR-GAP**: Container can only access docker.com on port 443 (protected)

### Policy Configuration

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

> **Note**: `docker.io` is a separate domain and is **not** covered by `*.docker.com`. It will be blocked by this policy. Only domains explicitly matching `docker.com` or `*.docker.com` are allowed.

### Test Scenarios

| Destination | Port | Without Air-Gap | With Air-Gap | Protection |
|---|---|---|---|---|
| docker.com | 443 (HTTPS) | Accessible | Accessible | Approved destination allowed |
| google.com | 443 (HTTPS) | Accessible | BLOCKED | External access prevented |
| github.com | 443 (HTTPS) | Accessible | BLOCKED | External access prevented |
| Any host | 80 (HTTP) | Accessible | BLOCKED | HTTP port blocked |
| Any host | 8080 | Accessible | BLOCKED | Non-standard ports blocked |
| Direct IP (8.8.8.8) | Any | Accessible | BLOCKED | IP-based allowlist bypass prevented |

### Expected Results

**WITH AIR-GAP ENABLED (Protected State):**
```
Test 1 - docker.com HTTPS:     ACCESSIBLE
Test 2 - google.com HTTPS:     BLOCKED
Test 3 - github.com HTTPS:     BLOCKED
Test 4 - HTTP port 80:         BLOCKED
Test 5 - Port 8080:            BLOCKED
Test 6 - Direct IP 8.8.8.8:   BLOCKED

Result: Only docker.com on port 443 accessible
Evidence: Air-gap prevents external communication and data exfiltration
```

### Pass Criteria
- docker.com accessible WITH air-gap
- All other URLs, ports, and direct IPs blocked WITH air-gap
- Clear before/after comparison documented
- Evidence shows air-gap prevents data exfiltration
- Results in `air_gap_results.txt`

---

## Test 3: Docker Scout Vulnerability Scanning

### Objective
Demonstrate how administrators can enable Docker Scout for automatic image vulnerability detection and use SBOMs to track and remediate security issues.

### Prerequisites
- Docker Scout enabled in organization
- Access to Docker Hub or container registry with Scout integration
- Sample vulnerable image

### Test Workflow

**Part A: Enable Docker Scout Image Indexing**

1. **In Docker Hub:**
   - Go to Repository Settings
   - Enable "Docker Scout"
   - Enable "Index on push"

2. **Via Docker CLI (from WSL2 or CMD):**
   ```bash
   docker login
   docker build -t myrepo/myimage:latest .
   docker push myrepo/myimage:latest
   ```

**Part B: View Image SBOM and Vulnerabilities (Before Fix)**

```bash
# Generate SBOM for local image
docker scout sbom myrepo/myimage:latest

# View detailed vulnerability report
docker scout cves myrepo/myimage:latest
```

**Part C: Remediate Vulnerabilities**

```dockerfile
FROM alpine:latest
RUN apk update && apk upgrade
```

```bash
docker build -t myrepo/myimage:v2 .
docker push myrepo/myimage:v2
```

**Part D: Re-scan and Compare (After Fix)**

```bash
docker scout cves myrepo/myimage:v2
# Document vulnerability reduction vs v1
```

### Expected Results

**Before Remediation:**
```
Image: myrepo/myimage:latest
Vulnerabilities:
  - Critical: Y
  - High: Z
  - Medium: W
  - Low: V
```

**After Remediation:**
```
Image: myrepo/myimage:v2
Vulnerabilities:
  - Critical: reduced
  - High: reduced
  - Medium: reduced
  - Low: reduced

Evidence: Vulnerability count reduced through package updates
```

### SBOM Access

**In Docker Hub UI:**
- Repository -> Image -> "Image Details" -> "SBOM"
- Download SBOM in SPDX or CycloneDX format

**Via CLI:**
```bash
docker scout sbom <image>               # Display SBOM
docker scout cves <image>               # Display vulnerabilities
docker scout cves <image> --format json # JSON output
```

### Pass Criteria
- Image indexed and analyzed by Scout
- SBOM generated and accessible
- Vulnerabilities identified and documented
- Remediation performed (package updates)
- Re-scan shows vulnerability reduction
- Before/after reports documented
- Results in `docker_scout_results.txt`

---

## Evidence Documentation Requirements

### Test 1: System Call Validation Report
**File**: `syscall_results.txt`
- Test execution date and Docker Desktop version
- ECI status and results for all 7 system calls
- Conclusion: "ECI prevents lateral movement of malicious containers"

### Test 2: Air-Gap Network Validation Report
**File**: `air_gap_results.txt`
- Test execution date and air-gap policy configuration
- Results for all 6 access tests
- Conclusion: "Air-gap prevents malicious network access and data exfiltration"

### Test 3: Docker Scout Vulnerability Report
**File**: `docker_scout_results.txt`
- Scout configuration and enablement steps
- SBOM location and vulnerability count before remediation
- Vulnerability count after remediation
- Conclusion: "Scout enables continuous vulnerability tracking and remediation"

---

## Running the Test Suite

**Windows CMD:**
```
run-all-tests.bat
```

**Windows WSL2 terminal:**
```bash
bash run-all-tests.sh

# Or run individually:
bash tests/1_syscall_validation.sh
bash tests/2_airgap_validation.sh
bash tests/3_docker_scout_scan.sh
```

---

## Success Criteria (All Must Pass)

### System Call Validation
- At least 6 of 7 system calls blocked WITH ECI
- Evidence shows before/after difference
- Proof ECI prevents host compromise

### Air-Gap Network Validation
- docker.com accessible WITH air-gap
- All other URLs, ports, and direct IPs blocked WITH air-gap
- Evidence shows before/after difference
- Proof air-gap prevents data exfiltration

### Docker Scout Vulnerability Scanning
- Scout enabled and images indexed
- SBOM generated and accessible
- Vulnerabilities identified
- Remediation performed
- Vulnerability reduction documented

---

## Security Validation Conclusion

**When all tests pass, you can state:**

> "We have validated Docker Enterprise security features:
>
> 1. **ECI Protection**: System call isolation prevents containers from accessing host resources, blocking lateral movement and host compromise attacks.
>
> 2. **Air-Gap Protection**: Network controls restrict container communication to approved destinations only, preventing data exfiltration and command-and-control communication.
>
> 3. **Scout Vulnerability Management**: Automated image scanning and continuous vulnerability tracking enable rapid identification and remediation of security issues.
>
> These combined controls provide comprehensive protection for containerized workloads."

---

**Document Version**: 3.0
**Platform**: Windows 10/11 with WSL2 + Docker Desktop
**Based on Official Docker Documentation**
- https://docs.docker.com/enterprise/security/hardened-desktop/enhanced-container-isolation/
- https://docs.docker.com/enterprise/security/hardened-desktop/air-gapped-containers/
- https://docs.docker.com/scout/

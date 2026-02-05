# ECI + Air-Gapped Containers Security Validation

**Prove that containerized malware cannot compromise your host or network when Docker's enterprise security features are enabled.**

## 🎯 Purpose

This test suite validates that Docker Desktop's **Enhanced Container Isolation (ECI)** and **Air-gapped Containers**, when configured together via Settings Management, provide comprehensive protection against containerized threats.

### What This Proves

When both features are properly enabled:
- ✅ Malware **cannot** access the host filesystem
- ✅ Malware **cannot** see or kill host processes  
- ✅ Malware **cannot** communicate with external networks
- ✅ Malware **cannot** exfiltrate stolen data
- ✅ Malware **cannot** escape the container
- ✅ Malware **cannot** persist after container stops

## 📋 Prerequisites

### Required
- **Docker Business Subscription** (both features require this)
- **Docker Desktop 4.29+**
- **Admin access** to [Docker Admin Console](https://admin.docker.com)

### Administrator Setup

**1. Enable Settings Management**
- Log in to Docker Admin Console
- Go to **Organization Settings** → **Security**
- Enable **Settings Management**

**2. Configure Enhanced Container Isolation (ECI)**
- In Settings Management, enable **Enhanced Container Isolation**
- **Lock** the setting (prevents users from disabling)
- Deploy to all organization members

**3. Configure Air-Gapped Containers**
- In Settings Management → **Network Security**
- Configure **Containers Proxy**:
  - **Mode**: Manual
  - **Locked**: Yes
  - **Transparent Ports**: `*` (all ports)
  
**Choose a policy:**

**Option A: Complete Isolation** (Highest Security)
```
HTTP Proxy: [empty]
HTTPS Proxy: [empty]
Exclude List: [empty]
```
Result: All external network access blocked

**Option B: Selective Access** (Development-Friendly)
```
HTTP Proxy: [empty]
HTTPS Proxy: [empty]
Exclude List: docker.io, github.com, npmjs.com
```
Result: Only approved domains accessible

**4. Deploy Configuration**
- Click **Deploy** in Admin Console
- Settings push to users automatically
- Users restart Docker Desktop to apply

## 🚀 Quick Start

```bash
# Clone repository
git clone https://github.com/tharinda3/ECI-Airgap-isolation-tests.git
cd ECI-Airgap-isolation-tests

# Run all validation tests
./run-all-tests.sh
```

## 📊 Test Results

After running the tests, you'll see:

```
╔════════════════════════════════════════════════════════════╗
║  Docker Desktop Security Validation Suite                  ║
║  ECI + Air-Gapped Containers Protection Testing            ║
╚════════════════════════════════════════════════════════════╝

Phase 1: ECI Protection Tests
✓ PASS: Host filesystem isolated
✓ PASS: Host processes invisible
✓ PASS: Container escapes contained

Phase 2: Air-Gapped Container Tests  
✓ PASS: External network blocked
✓ PASS: DNS tunneling prevented
✓ PASS: Configuration bypass failed

Phase 3: Combined Protection Validation
✓ PASS: Multi-vector attack blocked
✓ PASS: Filesystem + network attacks both fail
✓ PASS: Privileged escape + exfiltration blocked

═══════════════════════════════════════════════════
✓ SECURITY VALIDATED
ECI + Air-gapped Containers successfully protect host
from containerized threats. All attacks were blocked.
═══════════════════════════════════════════════════
```

## 🧪 What Gets Tested

### Phase 1: ECI Protection
Tests that Enhanced Container Isolation prevents host access:
- Host filesystem access attempts (blocked)
- Host process enumeration (blocked)
- Container escape exploits (contained in VM)
- Docker socket access (blocked)

### Phase 2: Air-Gapped Network Protection
Tests that network policies prevent data exfiltration:
- External HTTP/HTTPS connections (blocked)
- DNS tunneling attempts (blocked)
- Alternative protocol access (blocked)
- Configuration bypass attempts (failed)

### Phase 3: Combined Multi-Vector Protection
Tests that both protections work together:
- Simultaneous filesystem + network attacks (both blocked)
- Process enumeration + C2 communication (both blocked)
- Container escape + lateral movement (both blocked)
- Persistence attempts + beaconing (both blocked)

### Phase 4: Real Malware Simulations
Simulates actual malicious containers:
- **Crypto Miner**: CPU-intensive with C2 communication
- **Data Stealer**: Searches for credentials and attempts exfiltration
- **Container Escape**: Exploits known vulnerabilities

## 📁 Repository Structure

```
.
├── TEST-PLAN.md              # Comprehensive test methodology
├── run-all-tests.sh          # Master test runner
├── tests/
│   ├── eci/                  # Enhanced Container Isolation tests
│   │   ├── filesystem_isolation.sh
│   │   └── process_isolation.sh
│   ├── airgap/               # Air-gapped container tests
│   │   ├── config_tests.sh
│   │   ├── pac_tests.sh
│   │   └── proxy_routing_tests.sh
│   ├── combined/             # Multi-layer protection tests
│   │   └── protection_validation.sh
│   └── attacks/              # Malware simulations
│       ├── crypto_miner.Dockerfile
│       ├── data_stealer.Dockerfile
│       └── container_escape.Dockerfile
└── test-results-*/           # Generated reports (after running tests)
```

## 🔍 Verification for End Users

Users can verify protection is active:

```bash
# Verify ECI is working (should show <10 processes)
docker run --rm alpine ps aux | wc -l

# Verify air-gap is working (should fail/timeout)
docker run --rm alpine wget -T 2 http://google.com

# Verify settings are locked
# Open Docker Desktop → Settings should show "Managed by organization"
```

## 📖 Detailed Documentation

See **[TEST-PLAN.md](TEST-PLAN.md)** for:
- Complete threat model and attack scenarios
- Detailed test case descriptions
- Success criteria and risk assessment
- Troubleshooting guide
- Production deployment checklist

## 🎓 Understanding the Protection Layers

### Layer 1: Enhanced Container Isolation (ECI)
- Runs containers in a **Linux VM** (on macOS/Windows)
- Provides **VM-level boundary** between containers and host
- Protects against container escape exploits
- Even privileged containers can't reach actual host

### Layer 2: Air-Gapped Containers
- **Network policy enforcement** via Settings Management
- Blocks or controls all container network access
- Prevents data exfiltration and C2 communication
- Cannot be bypassed by users or malware

### Layer 3: Settings Management
- **Admin-controlled** configuration
- **Locked settings** users cannot modify
- **Centrally deployed** via Docker Admin Console
- **Compliance enforcement** across organization

### Result: Defense-in-Depth
Multiple independent security layers ensure comprehensive protection.

## ⚠️ Common Issues

**Tests showing external network access when it should be blocked?**
- Verify air-gap policy is deployed in Docker Admin Console
- Check policy deployment status
- Restart Docker Desktop on affected machines

**Tests showing host filesystem access?**
- Verify ECI is enabled in Admin Console
- Check Docker Desktop version (4.29+ required)
- Ensure Settings Management is active

**Container functionality broken?**
- Adjust air-gap policy (Option B instead of Option A)
- Add required domains to exclude list
- Use PAC file for fine-grained control

## 📊 Test Reports

After running tests, detailed reports are generated in `test-results-[timestamp]/`:
- `summary-report.md` - Executive summary and findings
- Individual test logs for each suite
- System configuration information
- Recommendations for any failures

## 🔐 Security Posture Statement

**When all tests pass, you can confidently state:**

> "Our Docker Desktop deployment, with Enhanced Container Isolation and Air-gapped Containers enabled via Settings Management, provides strong protection against containerized threats. Comprehensive testing validates that malware running inside containers cannot access our host systems, cannot exfiltrate data to external networks, and cannot persist beyond the container lifecycle. Our multi-layered security approach has been thoroughly validated."

## 🤝 For Docker Administrators

This test suite is designed to:
1. **Validate** that your security configuration is working
2. **Prove** protection to stakeholders and compliance teams
3. **Document** security posture for audits
4. **Monitor** ongoing effectiveness after changes

Run this suite:
- ✅ After initial configuration
- ✅ After Docker Desktop updates
- ✅ Monthly as part of security reviews
- ✅ After any policy changes

## 📚 Additional Resources

- [Docker Admin Console](https://admin.docker.com)
- [Enhanced Container Isolation Documentation](https://docs.docker.com/desktop/hardened-desktop/enhanced-container-isolation/)
- [Air-Gapped Containers Documentation](https://docs.docker.com/enterprise/security/hardened-desktop/air-gapped-containers/)
- [Settings Management Guide](https://docs.docker.com/desktop/hardened-desktop/settings-management/)

## 📝 License

MIT License - See LICENSE file for details

---

**Questions?** Open an issue or contact Docker support for enterprise configuration assistance.

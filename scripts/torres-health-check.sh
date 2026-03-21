#!/bin/bash

# Torres-Core Lab Health Check Script (Local Proxmox Version)
# Optimized to run directly on proxmox-n3
# Usage: ./torres-health-check-local.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

section() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

check_reachable() {
    local name=$1
    local host=$2
    local port=$3
    
    if timeout 3 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
        pass "$name ($host:$port) is reachable"
    else
        fail "$name ($host:$port) is NOT reachable"
    fi
}

check_http() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 -k "$url" 2>/dev/null)
    
    if [[ $response -ge 200 && $response -lt 400 ]]; then
        pass "$name returns HTTP $response"
    else
        fail "$name returns HTTP $response (expected $expected_code range)"
    fi
}

check_ping() {
    local name=$1
    local host=$2
    
    if ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
        pass "$name ($host) responds to ping"
    else
        fail "$name ($host) does NOT respond to ping"
    fi
}

check_dns() {
    local name=$1
    local server=$2
    local query=${3:-google.com}
    
    if dig +short +time=2 @"$server" "$query" | grep -q .; then
        pass "$name DNS resolves $query"
    else
        fail "$name DNS does NOT resolve $query"
    fi
}

# ============================================================================
# START HEALTH CHECKS
# ============================================================================

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║     Torres-Core Infrastructure Health      ║"
echo "║           $(date '+%Y-%m-%d %H:%M:%S')            ║"
echo "╚════════════════════════════════════════════╝"

# ============================================================================
section "NETWORK CONNECTIVITY"
# ============================================================================

check_ping "AdGuard" "192.168.50.14"
check_ping "Docker VM" "192.168.50.16"
check_ping "Plex LXC" "192.168.50.12"
check_ping "Home Assistant" "192.168.50.13"
check_ping "Router" "192.168.50.1"

# ============================================================================
section "PROXMOX HOST STATUS"
# ============================================================================

# Check if Proxmox services are running
if systemctl is-active --quiet pveproxy; then
    pass "Proxmox web UI service is running"
else
    fail "Proxmox web UI service is NOT running"
fi

if systemctl is-active --quiet pvedaemon; then
    pass "Proxmox daemon is running"
else
    fail "Proxmox daemon is NOT running"
fi

if systemctl is-active --quiet pve-cluster; then
    pass "Proxmox cluster service is running"
else
    warn "Proxmox cluster service is not running (normal for single node)"
fi

# Check Proxmox web UI accessibility
check_http "Proxmox Web UI" "https://192.168.50.10:8006" "200"

# ============================================================================
section "CONTAINERS & VMS"
# ============================================================================

# Check if containers are running
RUNNING_CTS=$(sudo pct list 2>/dev/null | grep -c "running" || echo 0)
TOTAL_CTS=$(sudo pct list 2>/dev/null | tail -n +2 | wc -l || echo 0)

if [[ $RUNNING_CTS -eq $TOTAL_CTS ]] && [[ $TOTAL_CTS -gt 0 ]]; then
    pass "All LXC containers running ($RUNNING_CTS/$TOTAL_CTS)"
else
    if [[ $RUNNING_CTS -gt 0 ]]; then
        warn "$RUNNING_CTS/$TOTAL_CTS LXC containers running"
    else
        fail "No LXC containers running"
    fi
fi

# Check specific critical containers
for ct_id in 100 101 102 103; do
    CT_STATUS=$(sudo pct status $ct_id 2>/dev/null | grep -o "running\|stopped" || echo "unknown")
    CT_NAME=$(sudo pct config $ct_id 2>/dev/null | grep "hostname:" | awk '{print $2}' || echo "CT$ct_id")
    
    if [[ "$CT_STATUS" == "running" ]]; then
        pass "LXC $ct_id ($CT_NAME) is running"
    else
        fail "LXC $ct_id ($CT_NAME) is $CT_STATUS"
    fi
done

# Check VMs
RUNNING_VMS=$(sudo qm list 2>/dev/null | grep -c "running" || echo 0)
TOTAL_VMS=$(sudo qm list 2>/dev/null | tail -n +2 | wc -l || echo 0)

if [[ $RUNNING_VMS -eq $TOTAL_VMS ]] && [[ $TOTAL_VMS -gt 0 ]]; then
    pass "All VMs running ($RUNNING_VMS/$TOTAL_VMS)"
else
    if [[ $RUNNING_VMS -gt 0 ]]; then
        warn "$RUNNING_VMS/$TOTAL_VMS VMs running"
    else
        warn "No VMs running (check if VM 104 Docker should be up)"
    fi
fi

# Check specific critical VMs
for vm_id in 102 104; do
    VM_STATUS=$(sudo qm status $vm_id 2>/dev/null | grep -o "running\|stopped" || echo "unknown")
    VM_NAME=$(sudo qm config $vm_id 2>/dev/null | grep "name:" | awk '{print $2}' || echo "VM$vm_id")
    
    if [[ "$VM_STATUS" == "running" ]]; then
        pass "VM $vm_id ($VM_NAME) is running"
    else
        fail "VM $vm_id ($VM_NAME) is $VM_STATUS"
    fi
done

# ============================================================================
section "DNS SERVICES"
# ============================================================================

check_reachable "AdGuard DNS port" "192.168.50.14" "53"
check_http "AdGuard Web UI" "http://192.168.50.14:3000" "200"
check_dns "AdGuard" "192.168.50.14" "google.com"
check_dns "AdGuard" "192.168.50.14" "plex.torres-core.us"
check_dns "AdGuard" "192.168.50.14" "docker.torres-core.us"

# ============================================================================
section "DOCKER INFRASTRUCTURE"
# ============================================================================

check_http "Portainer" "https://192.168.50.16:9443" "200"

# Check if we can reach Docker VM (HTTP checks are better than SSH for health)
check_http "qBittorrent" "http://192.168.50.16:8080" "200"

# ============================================================================
section "MEDIA STACK"
# ============================================================================

check_http "qBittorrent" "http://192.168.50.16:8080" "200"
check_http "Sonarr" "http://192.168.50.16:8989" "401"
check_http "Radarr" "http://192.168.50.16:7878" "401"
check_http "Prowlarr" "http://192.168.50.16:9696" "401"
check_http "Bazarr" "http://192.168.50.16:6767" "200"
check_http "Seerr" "http://192.168.50.16:5055" "200"
check_http "FlareSolverr" "http://192.168.50.16:8191" "200"

# ============================================================================
section "HOME AUTOMATION"
# ============================================================================

check_http "Home Assistant" "http://192.168.50.13:8123" "200"

# ============================================================================
section "MEDIA SERVER"
# ============================================================================

check_http "Plex" "http://192.168.50.12:32400/web" "200"

# ============================================================================
section "STORAGE HEALTH"
# ============================================================================

# Check ZFS pool status
if zpool status datapool | grep -q "state: ONLINE"; then
    pass "ZFS datapool is ONLINE"
else
    fail "ZFS datapool is NOT ONLINE"
fi

# Check for ZFS errors
if zpool status datapool | grep -q "errors: No known data errors"; then
    pass "ZFS datapool has no errors"
else
    warn "ZFS datapool may have errors - check 'zpool status datapool'"
fi

# Check ZFS pool capacity
POOL_CAPACITY=$(zpool list -H -o capacity datapool 2>/dev/null | tr -d '%')
if [[ -n "$POOL_CAPACITY" ]]; then
    if [[ $POOL_CAPACITY -lt 80 ]]; then
        pass "ZFS datapool capacity: ${POOL_CAPACITY}%"
    elif [[ $POOL_CAPACITY -lt 90 ]]; then
        warn "ZFS datapool capacity: ${POOL_CAPACITY}% (getting high)"
    else
        fail "ZFS datapool capacity: ${POOL_CAPACITY}% (critical)"
    fi
fi

# Check rpool (system pool)
if zpool status rpool | grep -q "state: ONLINE"; then
    pass "ZFS rpool (system) is ONLINE"
else
    fail "ZFS rpool (system) is NOT ONLINE"
fi

# ============================================================================
section "SYSTEM RESOURCES"
# ============================================================================

# Check CPU load
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
CPU_CORES=$(nproc)
LOAD_PERCENT=$(echo "$LOAD_AVG $CPU_CORES" | awk '{printf "%.0f", ($1/$2)*100}')

if [[ $LOAD_PERCENT -lt 70 ]]; then
    pass "CPU load: ${LOAD_PERCENT}% (${LOAD_AVG} avg)"
elif [[ $LOAD_PERCENT -lt 90 ]]; then
    warn "CPU load: ${LOAD_PERCENT}% (${LOAD_AVG} avg) - elevated"
else
    fail "CPU load: ${LOAD_PERCENT}% (${LOAD_AVG} avg) - high"
fi

# Check memory usage
MEM_TOTAL=$(free -g | awk '/^Mem:/ {print $2}')
MEM_USED=$(free -g | awk '/^Mem:/ {print $3}')
MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.0f", ($3/$2)*100}')

if [[ $MEM_PERCENT -lt 80 ]]; then
    pass "Memory usage: ${MEM_PERCENT}% (${MEM_USED}G/${MEM_TOTAL}G)"
elif [[ $MEM_PERCENT -lt 90 ]]; then
    warn "Memory usage: ${MEM_PERCENT}% (${MEM_USED}G/${MEM_TOTAL}G) - high"
else
    fail "Memory usage: ${MEM_PERCENT}% (${MEM_USED}G/${MEM_TOTAL}G) - critical"
fi

# Check root filesystem
ROOT_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
if [[ $ROOT_USAGE -lt 80 ]]; then
    pass "Root filesystem: ${ROOT_USAGE}% used"
elif [[ $ROOT_USAGE -lt 90 ]]; then
    warn "Root filesystem: ${ROOT_USAGE}% used - getting high"
else
    fail "Root filesystem: ${ROOT_USAGE}% used - critical"
fi

# ============================================================================
section "BACKUP & SNAPSHOTS"
# ============================================================================

# Check for recent ZFS snapshots
RECENT_SNAPS=$(zfs list -t snapshot -o name,creation -s creation | tail -5 | wc -l)
if [[ $RECENT_SNAPS -gt 0 ]]; then
    LATEST_SNAP=$(zfs list -t snapshot -o name,creation -s creation | tail -1)
    pass "ZFS snapshots exist (latest: $(echo $LATEST_SNAP | awk '{print $1}'))"
else
    warn "No ZFS snapshots found - check Sanoid"
fi

# Check if Sanoid timer is active
if systemctl is-active --quiet sanoid.timer 2>/dev/null; then
    pass "Sanoid snapshot timer is active"
else
    warn "Sanoid snapshot timer is not active"
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "HEALTH CHECK SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Passed:${NC}   $PASSED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "${RED}Failed:${NC}   $FAILED"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    exit 0
elif [[ $FAILED -le 2 ]]; then
    echo -e "${YELLOW}⚠ Minor issues detected${NC}"
    exit 1
else
    echo -e "${RED}✗ Critical failures detected${NC}"
    exit 2
fi
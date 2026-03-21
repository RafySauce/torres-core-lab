#!/bin/bash

# Torres-Core Lab Health Check Script
# Run this from your gaming PC via Git Bash or from proxmox-n3 directly
# Usage: ./torres-health-check.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
    local proto=${4:-http}
    
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
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "$url" 2>/dev/null)
    
    if [[ $response -ge 200 && $response -lt 400 ]]; then
        pass "$name returns HTTP $response"
    else
        fail "$name returns HTTP $response (expected $expected_code range)"
    fi
}

check_ssh() {
    local name=$1
    local host=$2
    
    if timeout 3 ssh -o ConnectTimeout=2 -o BatchMode=yes -o StrictHostKeyChecking=no "$host" "exit" 2>/dev/null; then
        pass "$name SSH is accessible"
    else
        fail "$name SSH is NOT accessible"
    fi
}

check_dns() {
    local name=$1
    local server=$2
    local query=${3:-google.com}
    
    if timeout 3 nslookup "$query" "$server" >/dev/null 2>&1; then
        pass "$name DNS resolves $query"
    else
        fail "$name DNS does NOT resolve $query"
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

# ============================================================================
# START HEALTH CHECKS
# ============================================================================

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║     Torres-Core Infrastructure Health     ║"
echo "║           $(date '+%Y-%m-%d %H:%M:%S')           ║"
echo "╚════════════════════════════════════════════╝"

# ============================================================================
section "NETWORK CONNECTIVITY"
# ============================================================================

check_ping "Proxmox (n3)" "192.168.50.10"
check_ping "AdGuard" "192.168.50.14"
check_ping "Docker VM" "192.168.50.16"
check_ping "Router" "192.168.50.1"

# ============================================================================
section "PROXMOX HOST"
# ============================================================================

check_reachable "Proxmox Web UI" "192.168.50.10" "8006"
check_ssh "proxmox-n3" "proxmox-n3"

# Check if we can query Proxmox API (requires SSH access)
if timeout 5 ssh -o ConnectTimeout=2 proxmox-n3 "pct list >/dev/null 2>&1" 2>/dev/null; then
    pass "Proxmox API responding"
else
    warn "Cannot verify Proxmox API (SSH required)"
fi

# ============================================================================
section "CONTAINERS & VMS"
# ============================================================================

# Check if containers are running (requires SSH to Proxmox)
if timeout 5 ssh -o ConnectTimeout=2 proxmox-n3 "pct list | grep -q running" 2>/dev/null; then
    pass "LXC containers are running"
else
    warn "Cannot verify LXC status (SSH required)"
fi

if timeout 5 ssh -o ConnectTimeout=2 proxmox-n3 "qm list | grep -q running" 2>/dev/null; then
    pass "VMs are running"
else
    warn "Cannot verify VM status (SSH required)"
fi

# ============================================================================
section "DNS SERVICES"
# ============================================================================

check_reachable "AdGuard DNS port" "192.168.50.14" "53"
check_http "AdGuard Web UI" "http://192.168.50.14:3000" "200"
check_dns "AdGuard" "192.168.50.14" "google.com"
check_dns "AdGuard" "192.168.50.14" "plex.torres-core.us"

# ============================================================================
section "DOCKER INFRASTRUCTURE"
# ============================================================================

check_ssh "docker" "docker"
check_http "Portainer" "https://192.168.50.16:9443" "200"

# Check Docker daemon (requires SSH)
if timeout 5 ssh -o ConnectTimeout=2 docker "docker ps >/dev/null 2>&1" 2>/dev/null; then
    pass "Docker daemon is running"
else
    fail "Docker daemon is NOT running or not accessible"
fi

# Check WireGuard VPN (requires SSH)
if timeout 5 ssh -o ConnectTimeout=2 docker "sudo wg show wg0 | grep -q handshake" 2>/dev/null; then
    pass "WireGuard VPN is connected"
else
    warn "Cannot verify WireGuard status (requires SSH with sudo)"
fi

# ============================================================================
section "MEDIA STACK"
# ============================================================================

check_http "qBittorrent" "http://192.168.50.16:8080" "200"
check_http "Sonarr" "http://192.168.50.16:8989" "401"  # 401 = auth required, service is up
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
section "STORAGE HEALTH (requires SSH)"
# ============================================================================

# Check ZFS pool status
if timeout 5 ssh -o ConnectTimeout=2 proxmox-n3 "zpool status datapool | grep -q ONLINE" 2>/dev/null; then
    pass "ZFS datapool is ONLINE"
else
    warn "Cannot verify ZFS status (SSH required)"
fi

# Check for ZFS errors
if timeout 5 ssh -o ConnectTimeout=2 proxmox-n3 "zpool status | grep -q 'errors: No known data errors'" 2>/dev/null; then
    pass "ZFS reports no errors"
else
    warn "Cannot verify ZFS error status (SSH required)"
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

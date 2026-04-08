#!/usr/bin/env bash

#
# Linux platform prerequisite checker for tiny11-handheld build system.
#
# Validates that all required tools and dependencies are installed on Linux:
# - Bash 5.0+
# - Docker 20.10+
# - Docker with Windows container support (experimental)
# - PowerShell 7+ (for cross-platform modules)
# - genisoimage or xorriso (for ISO creation)
# - p7zip (for ISO extraction)
# - Adequate disk space (20GB+ recommended)
#
# Script: check-prereqs.sh
# Platform: Linux only
# Requires: Bash 5.0+
# Author: tiny11-handheld
# Version: 1.0.0
#
# Example:
#   ./check-prereqs.sh
#   ./check-prereqs.sh --verbose
#

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;37m'
readonly NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

# Verbose mode
VERBOSE=false
if [[ "${1:-}" == "--verbose" ]] || [[ "${1:-}" == "-v" ]]; then
    VERBOSE=true
fi

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${GRAY}[VERBOSE] $1${NC}" >&2
    fi
}

write_check() {
    local name="$1"
    local passed="$2"
    local message="${3:-}"

    if [[ "$passed" == "true" ]]; then
        echo -e "${GREEN}✓${NC} ${WHITE}$name${NC}"
        if [[ -n "$message" ]]; then
            echo -e "  ${GRAY}$message${NC}"
        fi
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗${NC} ${WHITE}$name${NC}"
        if [[ -n "$message" ]]; then
            echo -e "  ${YELLOW}$message${NC}"
        fi
        ((CHECKS_FAILED++))
    fi
}

write_warning() {
    local name="$1"
    local message="$2"

    echo -e "${YELLOW}⚠${NC} ${WHITE}$name${NC}"
    echo -e "  ${YELLOW}$message${NC}"
    ((WARNINGS++))
}

echo ""
echo -e "${CYAN}==================================================================================================${NC}"
echo -e "${CYAN}Tiny11 Handheld - Linux Prerequisites Check${NC}"
echo -e "${CYAN}==================================================================================================${NC}"
echo ""

# Check 1: Platform
log_verbose "Checking platform..."
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    write_check "Platform: Linux" "true" "Running on Linux"
else
    write_check "Platform: Linux" "false" "This script must run on Linux (detected: $OSTYPE)"
fi

# Check 2: Bash version
log_verbose "Checking Bash version..."
BASH_VERSION_MAJOR="${BASH_VERSINFO[0]}"
if [[ "$BASH_VERSION_MAJOR" -ge 5 ]]; then
    write_check "Bash Version" "true" "Version $BASH_VERSION (minimum: 5.0)"
else
    write_check "Bash Version" "false" "Version $BASH_VERSION (minimum: 5.0 required)"
fi

# Check 3: Root/sudo access
log_verbose "Checking root/sudo access..."
if [[ $EUID -eq 0 ]]; then
    write_warning "Running as root" "Running as root is not recommended. Use sudo only when necessary."
elif command -v sudo &>/dev/null; then
    if sudo -n true 2>/dev/null; then
        write_check "Sudo Access" "true" "Passwordless sudo configured"
    else
        write_check "Sudo Access" "true" "Sudo available (may prompt for password)"
    fi
else
    write_check "Sudo Access" "false" "sudo command not found (may be required for Docker operations)"
fi

# Check 4: Docker
log_verbose "Checking Docker..."
if command -v docker &>/dev/null; then
    DOCKER_VERSION=$(docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "unknown")
    DOCKER_MAJOR=$(echo "$DOCKER_VERSION" | cut -d. -f1)
    DOCKER_MINOR=$(echo "$DOCKER_VERSION" | cut -d. -f2)
    
    if [[ "$DOCKER_MAJOR" -ge 20 ]] && [[ "$DOCKER_MINOR" -ge 10 ]]; then
        write_check "Docker" "true" "Version $DOCKER_VERSION (minimum: 20.10)"
    else
        write_check "Docker" "false" "Version $DOCKER_VERSION (minimum: 20.10 required)"
    fi

    # Check if Docker daemon is running
    log_verbose "Checking Docker daemon..."
    if docker info &>/dev/null; then
        write_check "Docker Daemon" "true" "Docker daemon is running"
    else
        write_check "Docker Daemon" "false" "Docker daemon is not running. Start with: sudo systemctl start docker"
    fi

    # Check for Windows container support (experimental)
    log_verbose "Checking Docker Windows container support..."
    write_warning "Docker Windows Containers" "DISM operations require Windows Server Core ltsc2022 image (see docs/README.md)"
else
    write_check "Docker" "false" "docker command not found. Install from: https://docs.docker.com/engine/install/"
fi

# Check 5: PowerShell 7+
log_verbose "Checking PowerShell..."
if command -v pwsh &>/dev/null; then
    PWSH_VERSION=$(pwsh --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "unknown")
    PWSH_MAJOR=$(echo "$PWSH_VERSION" | cut -d. -f1)
    
    if [[ "$PWSH_MAJOR" -ge 7 ]]; then
        write_check "PowerShell Core" "true" "Version $PWSH_VERSION (minimum: 7.0)"
    else
        write_check "PowerShell Core" "false" "Version $PWSH_VERSION (minimum: 7.0 required)"
    fi
else
    write_check "PowerShell Core" "false" "pwsh command not found. Install from: https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux"
fi

# Check 6: genisoimage or xorriso (for ISO creation)
log_verbose "Checking ISO creation tools..."
ISO_TOOL=""
if command -v genisoimage &>/dev/null; then
    ISO_TOOL="genisoimage"
    write_check "ISO Creation Tool" "true" "Found: genisoimage"
elif command -v xorriso &>/dev/null; then
    ISO_TOOL="xorriso"
    write_check "ISO Creation Tool" "true" "Found: xorriso"
else
    write_check "ISO Creation Tool" "false" "Neither genisoimage nor xorriso found. Install with: sudo apt install genisoimage (or xorriso)"
fi

# Check 7: p7zip (for ISO extraction)
log_verbose "Checking p7zip..."
if command -v 7z &>/dev/null; then
    P7ZIP_VERSION=$(7z --help 2>/dev/null | head -2 | tail -1 | grep -oP '\d+\.\d+' || echo "unknown")
    write_check "p7zip" "true" "Version $P7ZIP_VERSION"
elif command -v 7za &>/dev/null; then
    write_check "p7zip" "true" "Found: 7za command"
else
    write_check "p7zip" "false" "7z command not found. Install with: sudo apt install p7zip-full"
fi

# Check 8: Disk space
log_verbose "Checking disk space..."
FREE_SPACE_KB=$(df . | tail -1 | awk '{print $4}')
FREE_SPACE_GB=$((FREE_SPACE_KB / 1024 / 1024))

if [[ "$FREE_SPACE_GB" -ge 20 ]]; then
    write_check "Disk Space" "true" "${FREE_SPACE_GB} GB available (minimum: 20 GB)"
else
    write_warning "Disk Space" "${FREE_SPACE_GB} GB available (recommended: 20+ GB for build operations)"
fi

# Check 9: Memory
log_verbose "Checking available memory..."
if [[ -f /proc/meminfo ]]; then
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))

    if [[ "$TOTAL_MEM_GB" -ge 8 ]]; then
        write_check "Physical Memory" "true" "${TOTAL_MEM_GB} GB total (recommended: 8+ GB)"
    else
        write_warning "Physical Memory" "${TOTAL_MEM_GB} GB total (recommended: 8+ GB for optimal performance)"
    fi
else
    write_warning "Physical Memory" "Could not determine total memory"
fi

# Summary
echo ""
echo -e "${CYAN}==================================================================================================${NC}"
echo -e "${CYAN}Prerequisites Check Summary${NC}"
echo -e "${CYAN}==================================================================================================${NC}"
echo ""
echo -e "  Passed:   ${GREEN}$CHECKS_PASSED${NC}"
if [[ "$CHECKS_FAILED" -eq 0 ]]; then
    echo -e "  Failed:   ${GREEN}$CHECKS_FAILED${NC}"
else
    echo -e "  Failed:   ${RED}$CHECKS_FAILED${NC}"
fi
if [[ "$WARNINGS" -eq 0 ]]; then
    echo -e "  Warnings: ${GREEN}$WARNINGS${NC}"
else
    echo -e "  Warnings: ${YELLOW}$WARNINGS${NC}"
fi
echo ""

if [[ "$CHECKS_FAILED" -eq 0 ]]; then
    echo -e "${GREEN}✓ All prerequisites met! Ready to build.${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some prerequisites are missing. Please install the required tools.${NC}"
    echo ""
    echo -e "${CYAN}Installation Guide (Ubuntu/Debian):${NC}"
    echo -e "  ${GRAY}sudo apt update${NC}"
    echo -e "  ${GRAY}sudo apt install docker.io p7zip-full genisoimage${NC}"
    echo -e "  ${GRAY}# PowerShell 7: https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux${NC}"
    echo -e "  ${GRAY}# Start Docker: sudo systemctl start docker && sudo systemctl enable docker${NC}"
    echo -e "  ${GRAY}# Add user to docker group: sudo usermod -aG docker \$USER && newgrp docker${NC}"
    echo ""
    exit 1
fi

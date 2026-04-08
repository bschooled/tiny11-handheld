#!/usr/bin/env bash

#
# wimlib-based WIM operations for Linux
#
# Provides native Linux WIM manipulation using wimlib-imagex.
# Fallback option when Docker Windows containers are not available.
#
# Script: wimlib-dism.sh
# Platform: Linux only
# Requires: wimlib-imagex
# Author: tiny11-handheld
# Version: 1.0.0
#

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Logging functions
log_info() {
    echo -e "[INFO] $1"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

#
# Mount WIM image using wimlib
#
mount_wim() {
    local wim_path="$1"
    local mount_path="$2"
    local index="${3:-1}"
    
    log_info "Mounting WIM: $wim_path (index: $index) -> $mount_path"
    
    if ! wimlib-imagex mount "$wim_path" "$index" "$mount_path"; then
        log_error "Failed to mount WIM"
        return 1
    fi
    
    log_success "WIM mounted successfully"
    return 0
}

#
# Unmount WIM image
#
unmount_wim() {
    local mount_path="$1"
    local commit="${2:-true}"
    
    if [[ "$commit" == "true" ]]; then
        log_info "Unmounting WIM with changes committed: $mount_path"
        wimlib-imagex unmount "$mount_path" --commit
    else
        log_info "Unmounting WIM with changes discarded: $mount_path"
        wimlib-imagex unmount "$mount_path"
    fi
    
    log_success "WIM unmounted"
    return 0
}

#
# Remove AppX package (limited support)
#
remove_package() {
    local mount_path="$1"
    local package_name="$2"
    
    log_warn "wimlib has limited AppX package removal support"
    log_info "Package removal will be attempted via direct file deletion: $package_name"
    
    # Try to find and remove the package directory
    local package_base=$(echo "$package_name" | cut -d_ -f1)
    local package_dirs=$(find "$mount_path/Program Files/WindowsApps" -type d -name "${package_base}*" 2>/dev/null || true)
    
    if [[ -n "$package_dirs" ]]; then
        while IFS= read -r dir; do
            log_info "Removing directory: $dir"
            rm -rf "$dir" 2>/dev/null || true
        done <<< "$package_dirs"
        return 0
    else
        log_warn "Package directory not found for: $package_name"
        return 1
    fi
}

#
# Get installed packages (limited support)
#
get_packages() {
    local mount_path="$1"
    
    log_info "Listing installed packages from: $mount_path"
    log_warn "wimlib has limited package listing support"
    
    # List WindowsApps directories as proxy for installed apps
    if [[ -d "$mount_path/Program Files/WindowsApps" ]]; then
        ls -1 "$mount_path/Program Files/WindowsApps" 2>/dev/null || true
    fi
}

#
# Add drivers (wimlib support)
#
add_drivers() {
    local mount_path="$1"
    local driver_path="$2"
    
    log_info "Adding drivers from: $driver_path"
    
    # For wimlib, copy drivers directly to mounted filesystem
    # This mimics DISM /Add-Driver behavior
    local target_dir="$mount_path/Windows/System32/DriverStore/FileRepository"
    
    if [[ ! -d "$target_dir" ]]; then
        log_error "Driver target directory not found: $target_dir"
        return 1
    fi
    
    # Copy all .inf files and associated drivers recursively
    if ! cp -rv "$driver_path"/* "$target_dir/" 2>&1; then
        log_warn "Driver copy failed"
        return 1
    fi
    
    log_success "Drivers copied to image"
    return 0
}

#
# Component cleanup (not supported by wimlib)
#
cleanup_image() {
    local mount_path="$1"
    local reset_base="${2:-false}"
    
    log_warn "Component cleanup not supported by wimlib"
    log_info "This feature requires DISM and is not available in wimlib fallback mode"
    
    return 0
}

#
# Export/optimize WIM
#
optimize_wim() {
    local wim_path="$1"
    local output_path="$2"
    local compress="${3:-maximum}"
    
    log_info "Optimizing WIM with compression: $compress"
    
    wimlib-imagex export "$wim_path" 1 "$output_path" --compress="$compress" --check
    
    log_success "WIM optimized"
    return 0
}

# Export functions for sourcing
export -f mount_wim
export -f unmount_wim
export -f remove_package
export -f get_packages
export -f add_drivers
export -f cleanup_image
export -f optimize_wim
export -f log_info
export -f log_error
export -f log_success
export -f log_warn

#!/usr/bin/env bash

#
# Docker DISM orchestration script for Linux platform
#
# Provides Docker-based DISM operations for WIM manipulation on Linux.
# Manages Windows Server Core ltsc2022 container lifecycle and DISM command execution.
#
# Script: docker-dism.sh
# Platform: Linux only
# Requires: Docker 20.10+, Windows container support
# Author: tiny11-handheld
# Version: 1.0.0
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Container configuration
CONTAINER_NAME="tiny11-dism-$$"  # Include PID for uniqueness
IMAGE_NAME="tiny11-dism:latest"
DOCKERFILE_PATH="$SCRIPT_DIR/Dockerfile.dism"

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

#
# Build Docker image if it doesn't exist
#
build_image() {
    log_info "Checking for Docker image: $IMAGE_NAME"
    
    if docker image inspect "$IMAGE_NAME" &>/dev/null; then
        log_info "Docker image exists: $IMAGE_NAME"
        return 0
    fi
    
    log_info "Building Docker image from: $DOCKERFILE_PATH"
    
    if ! docker build -f "$DOCKERFILE_PATH" -t "$IMAGE_NAME" "$SCRIPT_DIR"; then
        log_error "Failed to build Docker image"
        return 1
    fi
    
    log_success "Docker image built: $IMAGE_NAME"
    return 0
}

#
# Start DISM container with volume mounts
#
start_container() {
    local workspace_path="$1"
    
    log_info "Starting DISM container: $CONTAINER_NAME"
    
    # Ensure workspace exists
    if [[ ! -d "$workspace_path" ]]; then
        log_error "Workspace directory not found: $workspace_path"
        return 1
    fi
    
    # Start container with volume mounts
    if ! docker run -d \
        --name "$CONTAINER_NAME" \
        --platform windows/amd64 \
        -v "$workspace_path:/build/workspace" \
        "$IMAGE_NAME"; then
        log_error "Failed to start DISM container"
        return 1
    fi
    
    # Wait for container to be ready
    sleep 3
    
    # Verify container is running
    if ! docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        log_error "Container failed to start or exited immediately"
        docker logs "$CONTAINER_NAME" || true
        return 1
    fi
    
    log_success "DISM container started: $CONTAINER_NAME"
    return 0
}

#
# Execute DISM command in container
#
exec_dism() {
    local dism_args=("$@")
    
    log_info "Executing DISM: ${dism_args[*]}"
    
    # Execute DISM in container
    if ! docker exec "$CONTAINER_NAME" powershell -NoProfile -Command \
        "dism ${dism_args[*]}; exit \$LASTEXITCODE"; then
        log_error "DISM command failed: ${dism_args[*]}"
        return 1
    fi
    
    log_success "DISM command completed successfully"
    return 0
}

#
# Mount WIM image
#
mount_wim() {
    local wim_path="$1"
    local mount_path="$2"
    local index="${3:-1}"
    
    log_info "Mounting WIM: $wim_path (index: $index) -> $mount_path"
    
    exec_dism /Mount-Wim \
        /WimFile:"C:\\build\\workspace\\$wim_path" \
        /MountDir:"C:\\build\\workspace\\$mount_path" \
        /Index:"$index"
}

#
# Unmount WIM image
#
unmount_wim() {
    local mount_path="$1"
    local commit="${2:-true}"
    
    local action
    if [[ "$commit" == "true" ]]; then
        action="/Commit"
        log_info "Unmounting WIM with changes committed: $mount_path"
    else
        action="/Discard"
        log_info "Unmounting WIM with changes discarded: $mount_path"
    fi
    
    exec_dism /Unmount-Wim \
        /MountDir:"C:\\build\\workspace\\$mount_path" \
        "$action"
}

#
# Remove Windows package
#
remove_package() {
    local mount_path="$1"
    local package_name="$2"
    
    log_info "Removing package: $package_name"
    
    exec_dism /Image:"C:\\build\\workspace\\$mount_path" \
        /Remove-ProvisionedAppxPackage \
        /PackageName:"$package_name"
}

#
# Get installed packages
#
get_packages() {
    local mount_path="$1"
    
    log_info "Listing installed packages from: $mount_path"
    
    docker exec "$CONTAINER_NAME" powershell -NoProfile -Command \
        "dism /Image:C:\\build\\workspace\\$mount_path /Get-ProvisionedAppxPackages"
}

#
# Inject drivers
#
add_drivers() {
    local mount_path="$1"
    local driver_path="$2"
    local recursive="${3:-true}"
    
    log_info "Injecting drivers from: $driver_path (recursive: $recursive)"
    
    local recurse_flag=""
    if [[ "$recursive" == "true" ]]; then
        recurse_flag="/Recurse"
    fi
    
    exec_dism /Image:"C:\\build\\workspace\\$mount_path" \
        /Add-Driver \
        /Driver:"C:\\build\\workspace\\$driver_path" \
        $recurse_flag
}

#
# Apply Windows updates
#
add_updates() {
    local mount_path="$1"
    local update_path="$2"
    
    log_info "Applying updates from: $update_path"
    
    # Find all .msu and .cab files
    docker exec "$CONTAINER_NAME" powershell -NoProfile -Command \
        "Get-ChildItem -Path C:\\build\\workspace\\$update_path -Include *.msu,*.cab -Recurse | ForEach-Object { \
            Write-Host \"Applying update: \$(\$_.Name)\"; \
            dism /Image:C:\\build\\workspace\\$mount_path /Add-Package /PackagePath:\$_.FullName; \
        }"
}

#
# Cleanup component store
#
cleanup_image() {
    local mount_path="$1"
    local reset_base="${2:-false}"
    
    log_info "Running component cleanup (reset base: $reset_base)"
    
    local args=("/Image:C:\\build\\workspace\\$mount_path" "/Cleanup-Image" "/StartComponentCleanup")
    
    if [[ "$reset_base" == "true" ]]; then
        args+=("/ResetBase")
    fi
    
    exec_dism "${args[@]}"
}

#
# Stop and remove container
#
stop_container() {
    log_info "Stopping DISM container: $CONTAINER_NAME"
    
    if docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        docker stop "$CONTAINER_NAME" &>/dev/null || true
        docker rm "$CONTAINER_NAME" &>/dev/null || true
        log_success "DISM container removed"
    else
        log_info "Container not found (may have been cleaned up already)"
    fi
}

#
# Main function for interactive testing
#
main() {
    local command="${1:-help}"
    
    case "$command" in
        build)
            build_image
            ;;
        start)
            local workspace="${2:?Workspace path required}"
            build_image && start_container "$workspace"
            ;;
        stop)
            stop_container
            ;;
        mount)
            local wim="${2:?WIM path required}"
            local mount="${3:?Mount path required}"
            local index="${4:-1}"
            mount_wim "$wim" "$mount" "$index"
            ;;
        unmount)
            local mount="${2:?Mount path required}"
            local commit="${3:-true}"
            unmount_wim "$mount" "$commit"
            ;;
        *)
            echo "Usage: $0 {build|start|stop|mount|unmount}"
            echo ""
            echo "Commands:"
            echo "  build                         Build Docker image"
            echo "  start <workspace>             Start DISM container with workspace mount"
            echo "  stop                          Stop and remove DISM container"
            echo "  mount <wim> <mount> [index]   Mount WIM image"
            echo "  unmount <mount> [commit]      Unmount WIM image"
            echo ""
            echo "This script is primarily sourced by build.sh, not run directly."
            exit 1
            ;;
    esac
}

# Allow sourcing this script or running directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

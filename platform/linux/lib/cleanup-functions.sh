#!/usr/bin/env bash
#
# Cleanup Functions - Workspace and resource cleanup
# Sourced by build.sh
#

# Clean up workspace directory
# Args:
#   $1: Workspace path
cleanup_workspace() {
    local workspace="$1"
    
    if [[ -z "$workspace" ]]; then
        echo "[ERROR] Workspace path not provided"
        return 1
    fi
    
    echo "[INFO] Cleaning up workspace: $workspace"
    
    # Unmount any mounted WIM images
    if [[ -d "$workspace/mount" ]]; then
        echo "[DEBUG] Checking for mounted WIM..."
        wimunmount "$workspace/mount" 2>/dev/null || true
    fi
    
    # Remove workspace directory
    if [[ -d "$workspace" ]]; then
        echo "[DEBUG] Removing workspace directory..."
        rm -rf "$workspace"
    fi
    
    echo "[SUCCESS] Workspace cleaned ✓"
    return 0
}

# Clean up old build artifacts
# Args:
#   $1: Output directory
#   $2: Keep last N builds (default: 5)
cleanup_old_builds() {
    local output_dir="$1"
    local keep_count="${2:-5}"
    
    echo "[INFO] Cleaning up old build artifacts..."
    
    # Remove old log files (keep last N)
    local log_count=$(ls -1 "$output_dir"/build-*.log 2>/dev/null | wc -l)
    if [[ $log_count -gt $keep_count ]]; then
        echo "[DEBUG] Removing old log files (keeping last $keep_count)..."
        ls -1t "$output_dir"/build-*.log | tail -n +$((keep_count + 1)) | xargs rm -f
    fi
    
    echo "[SUCCESS] Old artifacts cleaned ✓"
    return 0
}

# Remove old ISO files if they exist
# Args:
#   $1: ISO file path
cleanup_existing_iso() {
    local iso_path="$1"
    
    if [[ -f "$iso_path" ]]; then
        echo "[INFO] Removing existing ISO file..."
        rm -f "$iso_path" || {
            echo "[ERROR] Failed to remove existing ISO: $iso_path"
            echo "[ERROR] File may be in use or have permission issues"
            return 1
        }
    fi
    
    return 0
}

# Cleanup on error (called by trap)
# Args: None (uses global variables)
cleanup_on_error() {
    local exit_code=$?
    
    echo ""
    echo "[ERROR] Build failed with exit code: $exit_code"
    echo "[INFO] Performing cleanup..."
    
    # Unmount WIM if mounted (discard changes on error)
    if [[ -d "${WORKSPACE:-}/mount" ]]; then
        echo "[INFO] Unmounting WIM (discarding changes)..."
        wimunmount "${WORKSPACE}/mount" 2>/dev/null || true
    fi
    
    echo "[INFO] Cleanup complete"
    echo "[INFO] Check log file for details: ${LOG_FILE:-build.log}"
    echo ""
    echo "Partial workspace preserved at: ${WORKSPACE:-workspace}"
    echo "To retry, fix the issue and run the build command again"
    echo "To clean up, run: rm -rf ${WORKSPACE:-workspace}"
    echo ""
    
    exit $exit_code
}

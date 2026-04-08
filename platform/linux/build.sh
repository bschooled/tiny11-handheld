#!/usr/bin/env bash

#
# Tiny11 Handheld - Linux Build Script
#
# Cross-platform Windows 11 image builder for Linux hosts using Docker DISM.
# Creates customized Windows 11 installation ISOs with debloating, bypasses,
# and device-specific optimizations.
#
# Script: build.sh
# Platform: Linux (Ubuntu/Debian recommended)
# Requires: Docker 20.10+, PowerShell 7+, p7zip, genisoimage/xorriso
# Author: tiny11-handheld
# Version: 1.0.0
#
# Usage:
#   ./build.sh --config configurations.json --source Win11.iso
#   ./build.sh --preset presets/handheld-default.json --source Win11.iso
#   ./build.sh --config my-config.json --preset presets/rog-ally.json --source Win11.iso
#

set -euo pipefail

# T026: Error handling and cleanup trap
cleanup_on_error() {
    local exit_code=$?
    echo ""
    echo "[ERROR] Build failed with exit code: $exit_code"
    echo "[INFO] Performing cleanup..."
    
    # Unmount WIM if mounted (discard changes on error)
    if [[ -d "$WORKSPACE/mount" ]]; then
        echo "[INFO] Unmounting WIM (discarding changes)..."
        unmount_wim "mount" "false" >> "$LOG_FILE" 2>&1 || true
    fi
    
    # Stop Docker container
    if [[ -n "${CONTAINER_NAME:-}" ]]; then
        echo "[INFO] Stopping Docker container..."
        stop_container >> "$LOG_FILE" 2>&1 || true
    fi
    
    echo "[INFO] Cleanup complete"
    echo "[INFO] Check log file for details: $LOG_FILE"
    echo ""
    echo "Partial workspace preserved at: $WORKSPACE"
    echo "To retry, fix the issue and run the build command again"
    echo "To clean up, run: rm -rf $WORKSPACE"
    echo ""
    exit $exit_code
}

trap cleanup_on_error ERR INT TERM

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source modular library functions
source "$SCRIPT_DIR/lib/template-functions.sh"
source "$SCRIPT_DIR/lib/validation-functions.sh"
source "$SCRIPT_DIR/lib/cleanup-functions.sh"

# Detect WIM manipulation method
USE_WIMLIB=false
if command -v wimlib-imagex &>/dev/null; then
    USE_WIMLIB=true
    echo "[INFO] Detected wimlib - will use native Linux WIM support"
    source "$SCRIPT_DIR/wimlib-dism.sh"
else
    echo "[INFO] wimlib not found - will use Docker DISM (requires Windows containers)"
    source "$SCRIPT_DIR/docker-dism.sh"
fi

# Logging functions
log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

log_warn() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1" >&2
}

# T028: Initialize PowerShell Logger module for use throughout build
init_logger() {
    pwsh -NoProfile -Command "\
        Import-Module '$PROJECT_ROOT/modules/Logger.psm1' -Force; \
        Initialize-Logger -LogPath '$LOG_FILE'; \
        Write-LogInfo 'Logger initialized for build session'" \
        >> "$LOG_FILE" 2>&1 || true
}

# Default paths
CONFIG_PATH=""
PRESET_PATH=""
SOURCE_ISO=""
WORKSPACE="$PROJECT_ROOT/workspace"
LOG_FILE=""
VALIDATION_MODE=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            CONFIG_PATH="$2"
            shift 2
            ;;
        --preset)
            PRESET_PATH="$2"
            shift 2
            ;;
        --validation)
            VALIDATION_MODE=true
            shift
            ;;
        --source)
            SOURCE_ISO="$2"
            shift 2
            ;;
        --workspace)
            WORKSPACE="$2"
            shift 2
            ;;
        --verbose)
            set -x
            shift
            ;;
        --help|-h)
            cat <<EOF
Tiny11 Handheld - Linux Build Script

Usage:
  $0 --source <iso> [options]

Required:
  --source <path>      Path to Windows 11 source ISO file

Optional:
  --config <path>      Path to configuration JSON file
  --preset <path>      Path to preset configuration file
    --validation         Use known-good template autounattend.example.xml instead of generating
  --workspace <path>   Custom workspace directory (default: ./workspace)
  --verbose            Enable verbose output
  --help, -h           Show this help message

Examples:
  $0 --source Win11_23H2_x64.iso --config configurations.json
  $0 --source Win11.iso --preset presets/handheld-default.json
  $0 --source Win11.iso --config my-config.json --preset presets/rog-ally.json

For more information, see docs/README.md
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$SOURCE_ISO" ]]; then
    echo "[ERROR] Source ISO path is required (--source)"
    echo "Use --help for usage information"
    exit 1
fi

if [[ ! -f "$SOURCE_ISO" ]]; then
    echo "[ERROR] Source ISO file not found: $SOURCE_ISO"
    exit 1
fi

# Initialize logging
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
mkdir -p "$PROJECT_ROOT/output/logs"
LOG_FILE="$PROJECT_ROOT/output/logs/build-linux-$TIMESTAMP.log"

# Initialize PowerShell Logger module
init_logger

echo "===================================================================================================="
echo "Tiny11 Handheld - Linux Build"
echo "===================================================================================================="
echo "[INFO] Build started at $(date)"
echo "[INFO] Log file: $LOG_FILE"
echo "[INFO] Source ISO: $SOURCE_ISO"
echo "[INFO] Config: ${CONFIG_PATH:-<none>}"
echo "[INFO] Preset: ${PRESET_PATH:-<none>}"
echo "[INFO] Validation mode: $VALIDATION_MODE"
echo "[INFO] Workspace: $WORKSPACE"
echo "===================================================================================================="
echo ""

# Clean up existing workspace and Docker mounts
if [[ -d "$WORKSPACE" ]]; then
    echo "[INFO] Existing workspace found, performing cleanup..."
    
    # Try to unmount any lingering WIM mounts
    if [[ -d "$WORKSPACE/mount" ]] && mountpoint -q "$WORKSPACE/mount" 2>/dev/null; then
        echo "[INFO] Unmounting lingering WIM mount..."
        sudo umount "$WORKSPACE/mount" 2>/dev/null || true
    fi
    
    # Stop any existing Docker containers with our naming pattern
    EXISTING_CONTAINERS=$(docker ps -a --filter "name=tiny11-dism" --format "{{.Names}}" 2>/dev/null || true)
    if [[ -n "$EXISTING_CONTAINERS" ]]; then
        echo "[INFO] Stopping existing Docker containers..."
        echo "$EXISTING_CONTAINERS" | while read -r container; do
            echo "[DEBUG] Stopping container: $container"
            docker stop "$container" >> "$LOG_FILE" 2>&1 || true
            docker rm "$container" >> "$LOG_FILE" 2>&1 || true
        done
    fi
    
    # Remove workspace directory
    echo "[INFO] Removing old workspace directory..."
    if ! rm -rf "$WORKSPACE" 2>/dev/null; then
        echo "[WARN] Failed to remove workspace with standard rm, trying with sudo..."
        sudo rm -rf "$WORKSPACE" 2>/dev/null || {
            echo "[ERROR] Failed to remove workspace directory: $WORKSPACE"
            echo "[ERROR] Please manually remove it with: sudo rm -rf $WORKSPACE"
            exit 1
        }
    fi
    
    log_success "Workspace cleanup complete ✓"
    echo ""
fi

# T027: Memory usage monitoring
echo "[INFO] Checking system resources..."
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
AVAILABLE_RAM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
AVAILABLE_RAM_GB=$((AVAILABLE_RAM_KB / 1024 / 1024))

echo "[DEBUG] Total RAM: ${TOTAL_RAM_GB}GB"
echo "[DEBUG] Available RAM: ${AVAILABLE_RAM_GB}GB"

if [[ $AVAILABLE_RAM_GB -lt 6 ]]; then
    echo "[WARN] Low memory detected (${AVAILABLE_RAM_GB}GB available)"
    echo "[WARN] Recommended: 8GB+ RAM for Windows 11 image building"
    echo "[WARN] Build may fail or be very slow"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "[INFO] Build cancelled by user"
        exit 0
    fi
elif [[ $TOTAL_RAM_GB -lt 8 ]]; then
    echo "[WARN] System has ${TOTAL_RAM_GB}GB RAM (recommended: 8GB+)"
else
    log_success "Memory check passed (${TOTAL_RAM_GB}GB total) ✓"
fi
echo ""

# Load PowerShell modules and configuration
echo "[INFO] Step 1/5: Loading PowerShell modules..."
echo "[DEBUG] PROJECT_ROOT=$PROJECT_ROOT"
echo "[DEBUG] Checking PowerShell availability..."

if ! command -v pwsh &>/dev/null; then
    echo "[ERROR] PowerShell (pwsh) not found in PATH"
    exit 1
fi

echo "[DEBUG] PowerShell found: $(pwsh --version)"
echo ""

echo "[INFO] Step 2/5: Loading configuration from JSON..."

if [[ "$VALIDATION_MODE" == "true" && -z "$CONFIG_PATH" && -z "$PRESET_PATH" ]]; then
    echo "[INFO] Validation mode with no config/preset provided; using empty config defaults"
    CONFIG_JSON="{}"
else
    # Build PowerShell arguments
    PWSH_ARGS="-ProjectRoot \"$PROJECT_ROOT\""
    if [[ -n "$CONFIG_PATH" ]]; then
        PWSH_ARGS="$PWSH_ARGS -ConfigPath \"$CONFIG_PATH\""
    fi
    if [[ -n "$PRESET_PATH" ]]; then
        PWSH_ARGS="$PWSH_ARGS -PresetPath \"$PRESET_PATH\""
    fi
    PWSH_ARGS="$PWSH_ARGS -SchemaPath \"$PROJECT_ROOT/schema.json\""

    echo "[DEBUG] Running PowerShell configuration loader..."
    echo "[DEBUG] Command: pwsh -File \"$SCRIPT_DIR/load-config.ps1\" $PWSH_ARGS"
    echo ""

    # Run PowerShell config loader with timeout
    timeout 30s pwsh -NoProfile -File "$SCRIPT_DIR/load-config.ps1" \
        -ProjectRoot "$PROJECT_ROOT" \
        ${CONFIG_PATH:+-ConfigPath "$CONFIG_PATH"} \
        ${PRESET_PATH:+-PresetPath "$PRESET_PATH"} \
        -SchemaPath "$PROJECT_ROOT/schema.json" \
        2>&1 > /tmp/pwsh-config-$$.tmp

    PWSH_EXIT=$?

    # Read the output
    if [[ -f /tmp/pwsh-config-$$.tmp ]]; then
        # Last line is JSON, everything else is progress messages
        CONFIG_JSON=$(tail -1 /tmp/pwsh-config-$$.tmp)
        head -n -1 /tmp/pwsh-config-$$.tmp | tee -a "$LOG_FILE"
        rm -f /tmp/pwsh-config-$$.tmp
    else
        CONFIG_JSON=""
    fi

    echo ""
    echo "[DEBUG] PowerShell exit code: $PWSH_EXIT"

    if [[ $PWSH_EXIT -eq 124 ]]; then
        echo "[ERROR] PowerShell configuration loader timed out after 30 seconds"
        exit 1
    fi

    if [[ $PWSH_EXIT -ne 0 ]]; then
        echo "[ERROR] PowerShell configuration loader failed with exit code: $PWSH_EXIT"
        exit 1
    fi

    # Extract just the JSON part (last occurrence of { to })
    CONFIG_JSON=$(echo "$CONFIG_JSON" | grep -Pzo '\\{(?:[^{}]|(?R))*\\}' | tail -1)

    if [[ -z "$CONFIG_JSON" ]]; then
        echo "[ERROR] Failed to extract configuration JSON from PowerShell output"
        echo "[ERROR] PowerShell output did not contain valid JSON"
        exit 1
    fi
fi

echo "[INFO] Step 3/5: Configuration loaded and validated ✓"
echo ""

echo "[INFO] Step 4/5: Displaying configuration summary..."
echo ""
echo "Configuration loaded:"
echo "$CONFIG_JSON" | head -20
echo "... (full config in log file)"
echo ""

echo "[INFO] Step 5/5: Build preparation complete"
echo ""

# Parse configuration JSON to extract needed values
echo "[INFO] Parsing configuration..."
OUTPUT_IMAGE=$(echo "$CONFIG_JSON" | grep -Po '"imageName"\s*:\s*"\K[^"]+' || echo "tiny11-handheld.iso")
OUTPUT_PATH=$(echo "$CONFIG_JSON" | grep -Po '"outputPath"\s*:\s*"\K[^"]+' || echo "$PROJECT_ROOT/output")
ARCHITECTURE=$(echo "$CONFIG_JSON" | grep -Po '"architecture"\s*:\s*"\K[^"]+' || echo "amd64")

echo "[DEBUG] Output image: $OUTPUT_IMAGE"
echo "[DEBUG] Output path: $OUTPUT_PATH"
echo "[DEBUG] Architecture: $ARCHITECTURE"
echo ""

# Create workspace directories
echo "[INFO] Step 6/11: Setting up workspace..."
mkdir -p "$WORKSPACE"
mkdir -p "$WORKSPACE/iso"
mkdir -p "$WORKSPACE/mount"
mkdir -p "$OUTPUT_PATH"

echo "[DEBUG] Workspace: $WORKSPACE"
echo "[DEBUG] ISO extraction: $WORKSPACE/iso"
echo "[DEBUG] Mount point: $WORKSPACE/mount"
log_success "Workspace created ✓"
echo ""

# T020: Extract ISO with p7zip
echo "[INFO] Step 7/11: Extracting Windows 11 ISO..."
echo "[DEBUG] Source: $SOURCE_ISO"
echo "[DEBUG] Destination: $WORKSPACE/iso"
echo ""

if ! command -v 7z &>/dev/null; then
    echo "[ERROR] 7z (p7zip) not found in PATH"
    echo "[ERROR] Install with: sudo apt install p7zip-full"
    exit 1
fi

echo "[DEBUG] Running: 7z x -o\"$WORKSPACE/iso\" \"$SOURCE_ISO\""
if ! 7z x -y -o"$WORKSPACE/iso" "$SOURCE_ISO" >> "$LOG_FILE" 2>&1; then
    echo "[ERROR] Failed to extract ISO with 7z"
    echo "[ERROR] Check log file for details: $LOG_FILE"
    exit 1
fi

log_success "ISO extracted successfully ✓"
echo ""

# Verify critical files exist
echo "[INFO] Verifying ISO contents..."
if [[ ! -d "$WORKSPACE/iso/sources" ]]; then
    echo "[ERROR] sources/ directory not found in extracted ISO"
    exit 1
fi

# Find install.wim or install.esd
WIM_FILE=""
if [[ -f "$WORKSPACE/iso/sources/install.wim" ]]; then
    WIM_FILE="$WORKSPACE/iso/sources/install.wim"
    echo "[DEBUG] Found: install.wim"
elif [[ -f "$WORKSPACE/iso/sources/install.esd" ]]; then
    WIM_FILE="$WORKSPACE/iso/sources/install.esd"
    echo "[DEBUG] Found: install.esd (will need conversion)"
else
    echo "[ERROR] Neither install.wim nor install.esd found in sources/"
    exit 1
fi

log_success "ISO verification complete ✓"
echo ""

# Get WIM info
echo "[INFO] Analyzing WIM file..."
WIM_SIZE=$(du -h "$WIM_FILE" | cut -f1)
echo "[DEBUG] WIM file: $(basename "$WIM_FILE")"
echo "[DEBUG] WIM size: $WIM_SIZE"

# Extract image index from config or default to 1
IMAGE_INDEX=$(echo "$CONFIG_JSON" | grep -Po '"imageIndex"\s*:\s*\K[0-9]+' || echo "1")
echo "[DEBUG] Target image index: $IMAGE_INDEX"
echo ""

# T021: Mount WIM (method depends on available tools)
if [[ "$USE_WIMLIB" == "true" ]]; then
    echo "[INFO] Step 8/11: Mounting WIM with wimlib..."
    echo "[DEBUG] Using native Linux WIM support (wimlib-imagex)"
else
    echo "[INFO] Step 8/11: Building Docker DISM image..."
    if ! build_image >> "$LOG_FILE" 2>&1; then
        echo "[ERROR] Failed to build Docker DISM image"
        echo "[ERROR] Check log file for details: $LOG_FILE"
        exit 1
    fi
    log_success "Docker DISM image ready ✓"
    echo ""

    echo "[INFO] Step 9/11: Starting DISM container..."
    if ! start_container "$WORKSPACE" >> "$LOG_FILE" 2>&1; then
        echo "[ERROR] Failed to start DISM container"
        echo "[ERROR] Check log file for details: $LOG_FILE"
        exit 1
    fi
    log_success "DISM container started ✓"
fi
echo ""

echo "[INFO] Step 10/11: Mounting WIM image..."
echo "[DEBUG] WIM: $WIM_FILE"
echo "[DEBUG] Mount: $WORKSPACE/mount"
echo "[DEBUG] Index: $IMAGE_INDEX"

# Create mount directory
mkdir -p "$WORKSPACE/mount"

# Mount WIM using appropriate method
if [[ "$USE_WIMLIB" == "true" ]]; then
    if ! mount_wim "$WIM_FILE" "$WORKSPACE/mount" "$IMAGE_INDEX" >> "$LOG_FILE" 2>&1; then
        echo "[ERROR] Failed to mount WIM image with wimlib"
        echo "[ERROR] Check log file for details: $LOG_FILE"
        exit 1
    fi
else
    if ! mount_wim "iso/sources/install.wim" "mount" "$IMAGE_INDEX" >> "$LOG_FILE" 2>&1; then
        echo "[ERROR] Failed to mount WIM image with Docker DISM"
        echo "[ERROR] Check log file for details: $LOG_FILE"
        stop_container
        exit 1
    fi
fi
log_success "WIM image mounted successfully ✓"
echo ""

# T022: Package removal operations
echo "[INFO] Step 11/11: Processing package removals..."

if [[ "$USE_WIMLIB" == "true" ]]; then
    log_warn "Using wimlib: Limited AppX package removal support"
    log_info "Some packages may need to be removed manually or via Windows DISM"
fi

# Extract package configuration
REMOVE_EDGE=$(echo "$CONFIG_JSON" | grep -Po '"removeEdge"\s*:\s*\K(true|false)' || echo "false")
REMOVE_ONEDRIVE=$(echo "$CONFIG_JSON" | grep -Po '"removeOneDrive"\s*:\s*\K(true|false)' || echo "false")

echo "[DEBUG] Remove Edge: $REMOVE_EDGE"
echo "[DEBUG] Remove OneDrive: $REMOVE_ONEDRIVE"

# Get package lists from config
REMOVE_LIST=$(echo "$CONFIG_JSON" | grep -Po '"removeList"\s*:\s*\[\K[^\]]+' | tr ',' '\n' | sed 's/"//g' | sed 's/^ *//' || true)

if [[ -n "$REMOVE_LIST" ]] && [[ "$USE_WIMLIB" == "false" ]]; then
    PACKAGE_COUNT=$(echo "$REMOVE_LIST" | wc -l)
    echo "[INFO] Removing $PACKAGE_COUNT packages..."
    
    # Get current package list to verify what's installed
    echo "[DEBUG] Getting installed package list..."
    INSTALLED_PACKAGES=$(docker exec "$CONTAINER_NAME" powershell -NoProfile -Command \
        "dism /Image:C:\\build\\workspace\\mount /Get-ProvisionedAppxPackages | Select-String 'PackageName :' | ForEach-Object { (\$_ -split ':')[1].Trim() }" \
        2>> "$LOG_FILE" || echo "")
    
    # Remove each package
    for package in $REMOVE_LIST; do
        package=$(echo "$package" | xargs)  # Trim whitespace
        if [[ -z "$package" ]]; then
            continue
        fi
        
        # Find exact package name (includes version suffix)
        EXACT_PACKAGE=$(echo "$INSTALLED_PACKAGES" | grep -i "^${package}_" | head -1)
        
        if [[ -n "$EXACT_PACKAGE" ]]; then
            echo "  [INFO] Removing: $EXACT_PACKAGE"
            if remove_package "mount" "$EXACT_PACKAGE" >> "$LOG_FILE" 2>&1; then
                echo "    ✓ Removed successfully"
            else
                echo "    ⚠ Failed to remove (may not be installed or dependency issue)"
            fi
        else
            echo "  [SKIP] Package not found: $package"
        fi
    done
fi

# Remove Edge if configured
if [[ "$REMOVE_EDGE" == "true" ]]; then
    echo "[INFO] Removing Microsoft Edge..."
    if [[ "$USE_WIMLIB" == "true" ]]; then
        # Direct filesystem access with wimlib mount
        rm -rf "$WORKSPACE/mount/Program Files (x86)/Microsoft/Edge" 2>/dev/null || true
        rm -rf "$WORKSPACE/mount/Program Files (x86)/Microsoft/EdgeUpdate" 2>/dev/null || true
    else
        docker exec "$CONTAINER_NAME" powershell -NoProfile -Command \
            "Remove-Item -Path 'C:\\build\\workspace\\mount\\Program Files (x86)\\Microsoft\\Edge' -Recurse -Force -ErrorAction SilentlyContinue; \
             Remove-Item -Path 'C:\\build\\workspace\\mount\\Program Files (x86)\\Microsoft\\EdgeUpdate' -Recurse -Force -ErrorAction SilentlyContinue" \
            >> "$LOG_FILE" 2>&1 || true
    fi
    echo "  ✓ Edge removal attempted"
fi

# Remove OneDrive if configured
if [[ "$REMOVE_ONEDRIVE" == "true" ]]; then
    echo "[INFO] Removing OneDrive..."
    if [[ "$USE_WIMLIB" == "true" ]]; then
        # Direct filesystem access with wimlib mount
        rm -f "$WORKSPACE/mount/Windows/System32/OneDriveSetup.exe" 2>/dev/null || true
        rm -f "$WORKSPACE/mount/Windows/SysWOW64/OneDriveSetup.exe" 2>/dev/null || true
    else
        docker exec "$CONTAINER_NAME" powershell -NoProfile -Command \
            "Remove-Item -Path 'C:\\build\\workspace\\mount\\Windows\\System32\\OneDriveSetup.exe' -Force -ErrorAction SilentlyContinue; \
             Remove-Item -Path 'C:\\build\\workspace\\mount\\Windows\\SysWOW64\\OneDriveSetup.exe' -Force -ErrorAction SilentlyContinue" \
            >> "$LOG_FILE" 2>&1 || true
    fi
    echo "  ✓ OneDrive removal attempted"
fi

log_success "Package removal complete ✓"
echo ""

# T023: Driver injection (if configured)
# Extract drivers section from JSON (more precise than simple grep)
DRIVERS_SECTION=$(echo "$CONFIG_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('drivers',{})))" 2>/dev/null || echo "{}")
INJECT_DRIVERS=$(echo "$DRIVERS_SECTION" | python3 -c "import sys,json; d=json.load(sys.stdin); print('true' if d.get('inject') else 'false')" 2>/dev/null || echo "false")

if [[ "$INJECT_DRIVERS" == "true" ]]; then
    DRIVER_PATH=$(echo "$DRIVERS_SECTION" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('path',''))" 2>/dev/null || echo "")
    
    # Resolve to absolute path
    if [[ -n "$DRIVER_PATH" ]]; then
        if [[ ! "$DRIVER_PATH" = /* ]]; then
            DRIVER_PATH="$PROJECT_ROOT/$DRIVER_PATH"
        fi
    fi
    
    if [[ -n "$DRIVER_PATH" && -d "$DRIVER_PATH" ]]; then
        echo "[INFO] Injecting drivers from: $DRIVER_PATH"
        
        # Inject drivers directly to mount point (wimlib approach)
        if add_drivers "$MOUNT_PATH" "$DRIVER_PATH" >> "$LOG_FILE" 2>&1; then
            log_success "Drivers injected successfully ✓"
        else
            echo "[WARN] Driver injection failed (see log for details)"
        fi
    else
        echo "[INFO] Driver injection enabled but no valid driver path found: $DRIVER_PATH"
    fi
else
    echo "[INFO] Driver injection disabled (skipping)"
fi
echo ""

# T024: Generate or inject autounattend.xml
if [[ "$VALIDATION_MODE" == "true" ]]; then
    echo "[INFO] Validation mode enabled: using known-good template autounattend.xml"
    TEMPLATE_PATH="$PROJECT_ROOT/templates/example-autounattend/autounattend.example.xml"
    if [[ ! -f "$TEMPLATE_PATH" ]]; then
        echo "[ERROR] Template autounattend not found: $TEMPLATE_PATH"
        exit 1
    fi
    cp "$TEMPLATE_PATH" "$WORKSPACE/iso/autounattend.xml"
    log_success "autounattend.xml copied from template ✓"
    echo ""
else
    echo "[INFO] Generating autounattend.xml..."
    echo "[DEBUG] Calling Autounattend.psm1 module..."

    # Save full JSON config for PowerShell to parse
    CONFIG_TEMP_FILE=$(mktemp)
    echo "$CONFIG_JSON" > "$CONFIG_TEMP_FILE"

    echo "[DEBUG] Generating autounattend.xml with full configuration..."

    # Generate autounattend.xml using PowerShell script
    pwsh -NoProfile -File "$PROJECT_ROOT/platform/linux/generate-autounattend.ps1" \
        -ConfigPath "$CONFIG_TEMP_FILE" \
        -OutputPath "$WORKSPACE/iso/autounattend.xml" \
        -ProjectRoot "$PROJECT_ROOT" \
        >> "$LOG_FILE" 2>&1

    PWSH_EXIT=$?

    # Clean up temp file
    rm -f "$CONFIG_TEMP_FILE"

    echo "[DEBUG] PowerShell exit code: $PWSH_EXIT"

    if [[ -f "$WORKSPACE/iso/autounattend.xml" ]]; then
        log_success "autounattend.xml generated ✓"
    else
        echo "[WARN] autounattend.xml generation failed (see log)"
    fi
    echo ""
fi

# OEM file/folder copy via $OEM$\$1 (if specified)
OEM_COPY_LIST=$( (echo "$CONFIG_JSON" | python3 - <<'PY'
import os, json, sys
try:
    cfg = json.loads(sys.stdin.read())
    oem = cfg.get("oem") or {}
    items = oem.get("copy")
    lines = []
    if items:
        if isinstance(items, dict):
            items = [items]
        for item in items:
            if not item:
                continue
            src = item.get("source")
            dst = item.get("destination") or ""
            if src:
                lines.append(f"{src}::{dst}")
    print("\n".join(lines))
except Exception as e:
    print(f"ERROR: Failed to parse OEM copy config: {e}", file=sys.stderr)
    sys.exit(0)
PY
) 2>&1 )

if [[ -n "$OEM_COPY_LIST" && ! "$OEM_COPY_LIST" =~ "ERROR" ]]; then
    echo "[INFO] Injecting OEM copy items into ISO via \$OEM\$\\\$1..."
    OEM_STAGE="$WORKSPACE/iso/sources/\$OEM\$"
    TARGET_BASE="$OEM_STAGE/\$1"
    mkdir -p "$TARGET_BASE" || { echo "[ERROR] Failed to create OEM directory: $TARGET_BASE"; exit 1; }

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        src="${line%%::*}"
        dest="${line##*::}"
        [[ -z "$dest" ]] && dest="$(basename "$src")"
        dest="${dest#/}"
        
        # Verify source exists
        if [[ ! -e "$src" ]]; then
            echo "[ERROR] OEM copy source not found: $src"
            exit 1
        fi
        
        target_path="$TARGET_BASE/$dest"
        mkdir -p "$(dirname "$target_path")" || { echo "[ERROR] Failed to create directory: $(dirname "$target_path")"; exit 1; }
        
        if [[ -d "$src" ]]; then
            mkdir -p "$target_path" || { echo "[ERROR] Failed to create directory: $target_path"; exit 1; }
            cp -a "$src"/. "$target_path"/ || { echo "[ERROR] Failed to copy directory: $src"; exit 1; }
        else
            cp -a "$src" "$target_path" || { echo "[ERROR] Failed to copy file: $src"; exit 1; }
        fi
    done <<< "$OEM_COPY_LIST"

    log_success "OEM copy items staged via \$OEM\$\\\$1 ✓"
else
    echo "[INFO] No OEM copy items specified"
fi
echo ""

# Optimization: Component cleanup
echo "[INFO] Running component cleanup..."
RESET_BASE=$(echo "$CONFIG_JSON" | grep -Po '"resetBase"\s*:\s*\K(true|false)' || echo "false")
echo "[DEBUG] Reset base: $RESET_BASE"

if cleanup_image "mount" "$RESET_BASE" >> "$LOG_FILE" 2>&1; then
    log_success "Component cleanup complete ✓"
else
    echo "[WARN] Component cleanup failed (see log)"
fi
echo ""

# Commit changes and unmount WIM
echo "[INFO] Committing changes and unmounting WIM..."
if ! unmount_wim "$WORKSPACE/mount" "true" >> "$LOG_FILE" 2>&1; then
    echo "[ERROR] Failed to unmount WIM with changes"
    [[ "$USE_WIMLIB" == "false" ]] && stop_container
    exit 1
fi
log_success "WIM unmounted with changes committed ✓"
echo ""

# Stop Docker container (if used)
if [[ "$USE_WIMLIB" == "false" ]]; then
    echo "[INFO] Stopping DISM container..."
    stop_container >> "$LOG_FILE" 2>&1 || true
    echo ""
fi

# T025: Create bootable ISO
echo "[INFO] Creating bootable ISO..."
echo "[DEBUG] Output: $OUTPUT_PATH/$OUTPUT_IMAGE"

# Clean up any existing output file that might have permission issues
if [[ -f "$OUTPUT_PATH/$OUTPUT_IMAGE" ]]; then
    echo "[INFO] Removing existing ISO file..."
    rm -f "$OUTPUT_PATH/$OUTPUT_IMAGE" || true
fi

# Check for genisoimage or xorriso
if command -v genisoimage &>/dev/null; then
    ISO_TOOL="genisoimage"
elif command -v xorriso &>/dev/null; then
    ISO_TOOL="xorriso"
else
    echo "[ERROR] Neither genisoimage nor xorriso found"
    echo "[ERROR] Install with: sudo apt install genisoimage"
    exit 1
fi

echo "[DEBUG] Using ISO tool: $ISO_TOOL"

# Extract boot catalog and sector from original ISO
if [[ ! -f "$WORKSPACE/iso/boot/etfsboot.com" ]]; then
    echo "[ERROR] Boot file not found: $WORKSPACE/iso/boot/etfsboot.com"
    exit 1
fi

# Create ISO with bootable configuration
if [[ "$ISO_TOOL" == "genisoimage" ]]; then
    genisoimage \
        -l -iso-level 4 -J -joliet-long -D \
        -b boot/etfsboot.com \
        -no-emul-boot \
        -boot-load-size 8 \
        -hide boot.catalog \
        -eltorito-alt-boot \
        -eltorito-platform 0xEF \
        -eltorito-boot efi/microsoft/boot/efisys.bin \
        -no-emul-boot \
        -o "$OUTPUT_PATH/$OUTPUT_IMAGE" \
        "$WORKSPACE/iso" \
        >> "$LOG_FILE" 2>&1
else
    # xorriso alternative
    xorriso -as mkisofs \
        -iso-level 4 -J -joliet-long -D \
        -b boot/etfsboot.com \
        -no-emul-boot \
        -boot-load-size 8 \
        -hide boot.catalog \
        -eltorito-alt-boot \
        -eltorito-platform 0xEF \
        -eltorito-boot efi/microsoft/boot/efisys.bin \
        -no-emul-boot \
        -o "$OUTPUT_PATH/$OUTPUT_IMAGE" \
        "$WORKSPACE/iso" \
        >> "$LOG_FILE" 2>&1
fi

if [[ $? -ne 0 ]]; then
    echo "[ERROR] ISO creation failed"
    echo "[ERROR] Check log file for details: $LOG_FILE"
    exit 1
fi

log_success "Bootable ISO created successfully ✓"
echo ""

# Calculate ISO size and checksum
ISO_SIZE=$(du -h "$OUTPUT_PATH/$OUTPUT_IMAGE" | cut -f1)
echo "[INFO] Calculating SHA256 checksum..."
ISO_CHECKSUM=$(sha256sum "$OUTPUT_PATH/$OUTPUT_IMAGE" | cut -d' ' -f1)

echo ""
echo "===================================================================================================="
echo "BUILD COMPLETE!"
echo "===================================================================================================="
echo ""
echo "Output ISO: $OUTPUT_PATH/$OUTPUT_IMAGE"
echo "ISO Size: $ISO_SIZE"
echo "SHA256: $ISO_CHECKSUM"
echo ""
echo "Build log: $LOG_FILE"
echo ""
echo "===================================================================================================="
echo "REMAINING TASKS (Not yet implemented):"
echo "  - T026: Error handling and partial rollback (basic cleanup implemented)"
echo "  - T027: Memory usage monitoring (8GB limit enforcement)"
echo "  - T028: Logger.psm1 integration (currently using basic logging)"
echo "===================================================================================================="
echo ""
echo "[SUCCESS] ✓ Build complete! (T020-T025)"
echo "[INFO] ISO ready for testing"
echo ""

exit 0

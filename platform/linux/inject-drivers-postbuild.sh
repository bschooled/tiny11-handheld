#!/usr/bin/env bash
#
# Post-build driver injection script for Linux
# Extracts WIM from ISO, injects drivers, rebuilds ISO
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the wimlib wrapper
source "$SCRIPT_DIR/wimlib-dism.sh"

#
# Usage
#
usage() {
    cat << EOF
Usage: $0 --iso <path> --drivers <path>

Post-build driver injection for tiny11 ISOs

Options:
    --iso <path>        Path to the ISO file to modify
    --drivers <path>    Path to the drivers directory
    -h, --help          Show this help message

Example:
    $0 --iso ./output/tiny11-handheld.iso --drivers ./drivers
EOF
    exit 1
}

#
# Parse arguments
#
ISO_PATH=""
DRIVER_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --iso)
            ISO_PATH="$2"
            shift 2
            ;;
        --drivers)
            DRIVER_PATH="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate inputs
if [[ -z "$ISO_PATH" ]] || [[ -z "$DRIVER_PATH" ]]; then
    echo "Error: Missing required arguments"
    usage
fi

if [[ ! -f "$ISO_PATH" ]]; then
    echo "Error: ISO file not found: $ISO_PATH"
    exit 1
fi

if [[ ! -d "$DRIVER_PATH" ]]; then
    echo "Error: Drivers directory not found: $DRIVER_PATH"
    exit 1
fi

# Convert to absolute paths
ISO_PATH="$(cd "$(dirname "$ISO_PATH")" && pwd)/$(basename "$ISO_PATH")"
DRIVER_PATH="$(cd "$DRIVER_PATH" && pwd)"

echo "=========================================="
echo "POST-BUILD DRIVER INJECTION"
echo "=========================================="
echo "ISO: $ISO_PATH"
echo "Drivers: $DRIVER_PATH"
echo ""

# Create temporary workspace
TEMP_WORKSPACE="$PROJECT_ROOT/workspace-driver-inject"
EXTRACT_DIR="$TEMP_WORKSPACE/iso"
MOUNT_DIR="$TEMP_WORKSPACE/mount"
WIM_PATH="$TEMP_WORKSPACE/install.wim"

echo "[INFO] Creating temporary workspace..."
rm -rf "$TEMP_WORKSPACE"
mkdir -p "$EXTRACT_DIR" "$MOUNT_DIR"

# Extract ISO
echo "[INFO] Extracting ISO..."
if ! 7z x -o"$EXTRACT_DIR" "$ISO_PATH" >/dev/null 2>&1; then
    echo "[ERROR] Failed to extract ISO"
    rm -rf "$TEMP_WORKSPACE"
    exit 1
fi

# Find the WIM file
if [[ -f "$EXTRACT_DIR/sources/install.wim" ]]; then
    WIM_SOURCE="$EXTRACT_DIR/sources/install.wim"
elif [[ -f "$EXTRACT_DIR/sources/boot.wim" ]]; then
    WIM_SOURCE="$EXTRACT_DIR/sources/boot.wim"
else
    echo "[ERROR] No WIM file found in ISO"
    rm -rf "$TEMP_WORKSPACE"
    exit 1
fi

echo "[INFO] Found WIM: $WIM_SOURCE"

# Copy WIM to workspace (wimlib requires modifiable file)
cp "$WIM_SOURCE" "$WIM_PATH"

# Mount WIM
echo "[INFO] Mounting WIM..."
if ! mount_wim "$WIM_PATH" "$MOUNT_DIR" 1; then
    echo "[ERROR] Failed to mount WIM"
    rm -rf "$TEMP_WORKSPACE"
    exit 1
fi

# Inject drivers
echo "[INFO] Injecting drivers..."
TARGET_DIR="$MOUNT_DIR/Windows/System32/DriverStore/FileRepository"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "[ERROR] Driver target directory not found: $TARGET_DIR"
    wimlib-imagex unmount "$MOUNT_DIR" >/dev/null 2>&1 || true
    rm -rf "$TEMP_WORKSPACE"
    exit 1
fi

echo "[INFO] Copying drivers to: $TARGET_DIR"
DRIVER_COUNT=0
while IFS= read -r -d '' driver_dir; do
    driver_name="$(basename "$driver_dir")"
    if [[ -d "$driver_dir" ]]; then
        echo "  - $driver_name"
        cp -r "$driver_dir" "$TARGET_DIR/" || true
        ((DRIVER_COUNT++))
    fi
done < <(find "$DRIVER_PATH" -mindepth 1 -maxdepth 1 -type d -print0)

echo "[SUCCESS] Copied $DRIVER_COUNT driver packages"

# Unmount with commit
echo "[INFO] Committing changes and unmounting..."
if ! unmount_wim "$MOUNT_DIR" "true"; then
    echo "[ERROR] Failed to unmount WIM"
    rm -rf "$TEMP_WORKSPACE"
    exit 1
fi

# Replace WIM in extracted ISO
echo "[INFO] Replacing WIM in ISO structure..."
mv "$WIM_PATH" "$WIM_SOURCE"

# Create new ISO name
ISO_DIR="$(dirname "$ISO_PATH")"
ISO_NAME="$(basename "$ISO_PATH" .iso)"
NEW_ISO_PATH="$ISO_DIR/${ISO_NAME}-with-drivers.iso"

# Rebuild ISO
echo "[INFO] Rebuilding ISO with drivers..."
if command -v genisoimage &> /dev/null; then
    genisoimage -iso-level 4 \
        -b boot/etfsboot.com \
        -no-emul-boot \
        -boot-load-size 8 \
        -hide boot.catalog \
        -eltorito-alt-boot \
        -eltorito-platform efi \
        -no-emul-boot \
        -b efi/microsoft/boot/efisys.bin \
        -o "$NEW_ISO_PATH" \
        "$EXTRACT_DIR" >/dev/null 2>&1
elif command -v mkisofs &> /dev/null; then
    mkisofs -iso-level 4 \
        -b boot/etfsboot.com \
        -no-emul-boot \
        -boot-load-size 8 \
        -hide boot.catalog \
        -eltorito-alt-boot \
        -eltorito-platform efi \
        -no-emul-boot \
        -b efi/microsoft/boot/efisys.bin \
        -o "$NEW_ISO_PATH" \
        "$EXTRACT_DIR" >/dev/null 2>&1
else
    echo "[ERROR] No ISO creation tool found (genisoimage or mkisofs)"
    rm -rf "$TEMP_WORKSPACE"
    exit 1
fi

# Calculate checksum
echo "[INFO] Calculating SHA256 checksum..."
ISO_SIZE="$(du -h "$NEW_ISO_PATH" | cut -f1)"
SHA256="$(sha256sum "$NEW_ISO_PATH" | cut -d' ' -f1)"

# Cleanup
echo "[INFO] Cleaning up temporary files..."
rm -rf "$TEMP_WORKSPACE"

echo ""
echo "=========================================="
echo "DRIVER INJECTION COMPLETE!"
echo "=========================================="
echo "Original ISO: $ISO_PATH"
echo "New ISO: $NEW_ISO_PATH"
echo "ISO Size: $ISO_SIZE"
echo "SHA256: $SHA256"
echo "Drivers: $DRIVER_COUNT packages injected"
echo "=========================================="
echo ""
echo "[SUCCESS] ISO with drivers ready for testing!"

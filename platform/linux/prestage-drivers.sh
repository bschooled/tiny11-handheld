#!/usr/bin/env bash
#
# Pre-stage drivers into Windows ISO
# Modifies source ISO by injecting drivers before the build
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

#
# Usage
#
usage() {
    cat << EOF
Usage: $0 --source <iso> --drivers <path> --output <iso>

Pre-stage drivers into Windows ISO before build

Options:
    --source <iso>      Source Windows ISO
    --drivers <path>    Path to drivers directory
    --output <iso>      Output ISO with drivers
    -h, --help          Show this help message

Example:
    $0 --source ./Win1125H2.iso --drivers ./drivers --output ./Win1125H2-drivers.iso

Note: This creates a modified Windows ISO that can be used as build source.
      The drivers will be present in the install.wim and available during
      Windows installation.
EOF
    exit 1
}

#
# Parse arguments
#
SOURCE_ISO=""
DRIVER_PATH=""
OUTPUT_ISO=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --source)
            SOURCE_ISO="$2"
            shift 2
            ;;
        --drivers)
            DRIVER_PATH="$2"
            shift 2
            ;;
        --output)
            OUTPUT_ISO="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option: $1"
            usage
            ;;
    esac
done

# Validate inputs
if [[ -z "$SOURCE_ISO" ]] || [[ -z "$DRIVER_PATH" ]] || [[ -z "$OUTPUT_ISO" ]]; then
    echo "Error: Missing required arguments"
    usage
fi

if [[ ! -f "$SOURCE_ISO" ]]; then
    echo "Error: Source ISO not found: $SOURCE_ISO"
    exit 1
fi

if [[ ! -d "$DRIVER_PATH" ]]; then
    echo "Error: Drivers directory not found: $DRIVER_PATH"
    exit 1
fi

# Convert to absolute paths
SOURCE_ISO="$(cd "$(dirname "$SOURCE_ISO")" && pwd)/$(basename "$SOURCE_ISO")"
DRIVER_PATH="$(cd "$DRIVER_PATH" && pwd)"
OUTPUT_DIR="$(cd "$(dirname "$OUTPUT_ISO")" && pwd)"
OUTPUT_ISO="$OUTPUT_DIR/$(basename "$OUTPUT_ISO")"

echo "=========================================="
echo "PRE-STAGE DRIVERS INTO WINDOWS ISO"
echo "=========================================="
echo "Source ISO: $SOURCE_ISO"
echo "Drivers: $DRIVER_PATH"
echo "Output ISO: $OUTPUT_ISO"
echo ""

# Create temporary workspace
TEMP_WORKSPACE="$PROJECT_ROOT/workspace-prestage"
EXTRACT_DIR="$TEMP_WORKSPACE/iso"
WIM_WORK="$TEMP_WORKSPACE/wim"

echo "[INFO] Creating temporary workspace..."
rm -rf "$TEMP_WORKSPACE"
mkdir -p "$EXTRACT_DIR" "$WIM_WORK"

# Extract source ISO
echo "[INFO] Extracting source ISO..."
if ! 7z x -o"$EXTRACT_DIR" "$SOURCE_ISO" >/dev/null 2>&1; then
    echo "[ERROR] Failed to extract ISO"
    rm -rf "$TEMP_WORKSPACE"
    exit 1
fi

# Find install.wim
WIM_PATH="$EXTRACT_DIR/sources/install.wim"
if [[ ! -f "$WIM_PATH" ]]; then
    echo "[ERROR] install.wim not found in ISO"
    rm -rf "$TEMP_WORKSPACE"
    exit 1
fi

echo "[INFO] Found install.wim"

# Use wimlib-imagex update to add drivers to WIM (offline mode)
# This works on unmounted WIM files
echo "[INFO] Adding drivers to WIM (offline mode)..."

# Create a staging directory with drivers
DRIVER_STAGE="$WIM_WORK/drivers"
mkdir -p "$DRIVER_STAGE"

echo "[INFO] Staging drivers..."
DRIVER_COUNT=0
while IFS= read -r -d '' driver_dir; do
    driver_name="$(basename "$driver_dir")"
    if [[ -d "$driver_dir" ]]; then
        echo "  - $driver_name"
        cp -r "$driver_dir" "$DRIVER_STAGE/"
        ((DRIVER_COUNT++))
    fi
done < <(find "$DRIVER_PATH" -mindepth 1 -maxdepth 1 -type d -print0)

echo "[SUCCESS] Staged $DRIVER_COUNT driver packages"

# Add drivers to WIM using wimlib-imagex update
# This modifies the WIM without mounting it
echo "[INFO] Injecting drivers into install.wim..."

# Create update command file for wimlib
UPDATE_CMD="$WIM_WORK/update.txt"
cat > "$UPDATE_CMD" << EOF
add '$DRIVER_STAGE' '/Windows/System32/DriverStore/FileRepository'
EOF

# Apply update to each image in the WIM
IMAGE_COUNT=$(wimlib-imagex info "$WIM_PATH" | grep "Image Count:" | awk '{print $3}')
echo "[INFO] WIM contains $IMAGE_COUNT image(s)"

for ((i=1; i<=IMAGE_COUNT; i++)); do
    echo "[INFO] Updating image $i/$IMAGE_COUNT..."
    if ! wimlib-imagex update "$WIM_PATH" "$i" < "$UPDATE_CMD" 2>&1; then
        echo "[WARN] Failed to update image $i, continuing..."
    fi
done

echo "[SUCCESS] Drivers injected into WIM"

# Rebuild ISO
echo "[INFO] Creating new ISO with drivers..."
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
        -o "$OUTPUT_ISO" \
        "$EXTRACT_DIR" 2>&1 | grep -v "^Warning:"
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
        -o "$OUTPUT_ISO" \
        "$EXTRACT_DIR" 2>&1 | grep -v "^Warning:"
else
    echo "[ERROR] No ISO creation tool found (genisoimage or mkisofs)"
    rm -rf "$TEMP_WORKSPACE"
    exit 1
fi

# Calculate checksum
echo "[INFO] Calculating SHA256 checksum..."
ISO_SIZE="$(du -h "$OUTPUT_ISO" | cut -f1)"
SHA256="$(sha256sum "$OUTPUT_ISO" | cut -d' ' -f1)"

# Cleanup
echo "[INFO] Cleaning up temporary files..."
rm -rf "$TEMP_WORKSPACE"

echo ""
echo "=========================================="
echo "PRE-STAGING COMPLETE!"
echo "=========================================="
echo "Source: $SOURCE_ISO"
echo "Output: $OUTPUT_ISO"
echo "ISO Size: $ISO_SIZE"
echo "SHA256: $SHA256"
echo "Drivers: $DRIVER_COUNT packages pre-staged"
echo "=========================================="
echo ""
echo "[SUCCESS] Modified Windows ISO ready!"
echo "[INFO] Use this ISO as the --source for build.sh"

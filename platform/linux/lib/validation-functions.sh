#!/usr/bin/env bash
#
# Validation Functions - Input validation and sanity checks
# Sourced by build.sh
#

# Validate source ISO exists and is readable
# Args:
#   $1: ISO path
validate_source_iso() {
    local iso_path="$1"
    
    echo "[INFO] Validating source ISO..."
    
    if [[ ! -f "$iso_path" ]]; then
        echo "[ERROR] Source ISO not found: $iso_path"
        return 1
    fi
    
    if [[ ! -r "$iso_path" ]]; then
        echo "[ERROR] Source ISO not readable: $iso_path"
        return 1
    fi
    
    # Check file size (Windows 11 ISO should be > 4GB)
    local size=$(stat -f%z "$iso_path" 2>/dev/null || stat -c%s "$iso_path" 2>/dev/null)
    local min_size=$((4 * 1024 * 1024 * 1024)) # 4GB
    
    if [[ $size -lt $min_size ]]; then
        echo "[WARN] ISO file seems small ($size bytes). Expected > 4GB for Windows 11"
    fi
    
    echo "[SUCCESS] Source ISO validated ✓"
    return 0
}

# Validate required tools are installed
# Args: None
validate_dependencies() {
    local missing_deps=()
    
    echo "[INFO] Checking dependencies..."
    
    # Check for required commands
    local required_cmds=("pwsh" "7z" "wimlib-imagex" "genisoimage")
    
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "[ERROR] Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Install with:"
        echo "  sudo apt install p7zip-full wimtools genisoimage"
        echo "  # For PowerShell: https://docs.microsoft.com/en-us/powershell/scripting/install/install-ubuntu"
        return 1
    fi
    
    echo "[SUCCESS] All dependencies available ✓"
    return 0
}

# Validate output directory is writable
# Args:
#   $1: Output directory path
validate_output_directory() {
    local output_dir="$1"
    
    # Create if doesn't exist
    mkdir -p "$output_dir" 2>/dev/null
    
    if [[ ! -d "$output_dir" ]]; then
        echo "[ERROR] Output directory does not exist and cannot be created: $output_dir"
        return 1
    fi
    
    if [[ ! -w "$output_dir" ]]; then
        echo "[ERROR] Output directory is not writable: $output_dir"
        return 1
    fi
    
    echo "[DEBUG] Output directory: $output_dir (writable)"
    return 0
}

# Check available disk space
# Args:
#   $1: Path to check
#   $2: Required space in GB
check_disk_space() {
    local path="$1"
    local required_gb="$2"
    
    # Get available space in GB
    local available_kb=$(df -k "$path" | tail -1 | awk '{print $4}')
    local available_gb=$((available_kb / 1024 / 1024))
    
    if [[ $available_gb -lt $required_gb ]]; then
        echo "[WARN] Low disk space: ${available_gb}GB available, ${required_gb}GB recommended"
        echo "[WARN] Build may fail if disk space runs out"
    else
        echo "[DEBUG] Disk space: ${available_gb}GB available"
    fi
    
    return 0
}

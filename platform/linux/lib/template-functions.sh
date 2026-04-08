#!/usr/bin/env bash
#
# Template Functions - Handle autounattend.xml template loading and population
# Sourced by build.sh
#

# Load autounattend schema template and populate with preset values
# Args:
#   $1: Config JSON string
#   $2: Output path for autounattend.xml
generate_autounattend_from_template() {
    local config_json="$1"
    local output_path="$2"
    local template_path="$PROJECT_ROOT/templates/autounattend/schema.xml"
    
    echo "[INFO] Generating autounattend.xml from template..."
    echo "[DEBUG] Template: $template_path"
    echo "[DEBUG] Output: $output_path"
    
    # Check if template exists
    if [[ ! -f "$template_path" ]]; then
        echo "[ERROR] Template not found: $template_path"
        return 1
    fi
    
    # Call PowerShell to generate from template
    pwsh -NoProfile -Command "
        Import-Module '$PROJECT_ROOT/modules/Autounattend.psm1' -Force;
        \$config = '$config_json' | ConvertFrom-Json;
        \$template = Get-Content '$template_path' -Raw;
        \$result = New-AutounattendFromTemplate -Config \$config -Template \$template;
        \$result | Out-File -FilePath '$output_path' -Encoding UTF8 -NoNewline;
        Write-Host '[INFO] Autounattend.xml generated from template';
    " >> "$LOG_FILE" 2>&1
    
    if [[ $? -eq 0 ]]; then
        echo "[SUCCESS] Autounattend.xml generated from template ✓"
        return 0
    else
        echo "[ERROR] Failed to generate autounattend.xml from template"
        return 1
    fi
}

# Validate preset JSON against schema
# Args:
#   $1: Preset path
validate_preset_schema() {
    local preset_path="$1"
    local schema_path="$PROJECT_ROOT/schema.json"
    
    echo "[INFO] Validating preset against schema..."
    
    # Use PowerShell JSON schema validation
    pwsh -NoProfile -Command "
        \$preset = Get-Content '$preset_path' | ConvertFrom-Json;
        \$schema = Get-Content '$schema_path' | ConvertFrom-Json;
        # Basic validation - check required fields
        if (!\$preset.version) { Write-Error 'Missing version field'; exit 1; }
        if (!\$preset.metadata) { Write-Error 'Missing metadata field'; exit 1; }
        if (!\$preset.source) { Write-Error 'Missing source field'; exit 1; }
        Write-Host '[INFO] Preset validation passed';
    " >> "$LOG_FILE" 2>&1
    
    if [[ $? -eq 0 ]]; then
        echo "[SUCCESS] Preset validation passed ✓"
        return 0
    else
        echo "[ERROR] Preset validation failed"
        return 1
    fi
}

# Merge preset with defaults from schema
# Args:
#   $1: Preset JSON string
# Outputs: Merged JSON to stdout
merge_preset_with_defaults() {
    local preset_json="$1"
    local schema_path="$PROJECT_ROOT/templates/presets/schema.json"
    
    # Use PowerShell to merge
    pwsh -NoProfile -Command "
        \$preset = '$preset_json' | ConvertFrom-Json;
        \$schema = Get-Content '$schema_path' | ConvertFrom-Json;
        
        # Merge logic: preset values override schema defaults
        # For now, just return preset as-is
        # TODO: Implement deep merge if needed
        
        \$preset | ConvertTo-Json -Depth 10 -Compress;
    "
}

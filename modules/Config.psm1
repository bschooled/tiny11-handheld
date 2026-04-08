#Requires -Version 7.0

<#
.SYNOPSIS
    Configuration management module with preset merging support.

.DESCRIPTION
    Handles loading, merging, and accessing build configurations. Supports:
    - Loading configurations from JSON files
    - Preset merging with shallow top-level key merge strategy
    - Configuration inheritance (user config overrides preset)
    - Path resolution (relative to project root)

.NOTES
    Module: Config.psm1
    Requires: PowerShell 7.0+
    Dependencies: Logger.psm1
    Author: tiny11-handheld
    Version: 1.0.0
#>

<#
.SYNOPSIS
    Loads and merges a build configuration from JSON file.

.DESCRIPTION
    Reads a configuration JSON file and optionally merges it with a preset.
    Implements shallow top-level key merge: user config keys completely override
    preset keys at the root level.

.PARAMETER ConfigPath
    Path to the main configuration JSON file (e.g., configurations.json).

.PARAMETER PresetPath
    Optional path to a preset configuration file to use as a base.
    If specified, user config will override preset values.

.OUTPUTS
    System.Collections.Hashtable
    Returns merged configuration as a hashtable.

.EXAMPLE
    $config = Import-BuildConfiguration -ConfigPath "./configurations.json"

.EXAMPLE
    $config = Import-BuildConfiguration -ConfigPath "./my-config.json" -PresetPath "./presets/handheld-default.json"

.NOTES
    - Preset is loaded first, then user config overwrites it
    - Merge is shallow: top-level keys only (e.g., entire "packages" object replaced if user provides it)
    - Deep merging would be complex and error-prone for nested structures
    - Relative paths are resolved relative to script location
#>
function Import-BuildConfiguration {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [string]$PresetPath
    )

    Write-LogDebug "Loading configuration from: $ConfigPath"

    # Verify config file exists
    if (-not (Test-Path -Path $ConfigPath)) {
        Write-LogError "Configuration file not found: $ConfigPath"
        throw "Configuration file not found: $ConfigPath"
    }

    # Load user configuration
    try {
        $userConfig = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
        Write-LogDebug "User configuration loaded successfully"
    }
    catch {
        Write-LogError "Failed to parse configuration JSON: $ConfigPath - $($_.Exception.Message)"
        throw "Invalid JSON in configuration file: $ConfigPath"
    }

    # If no preset specified, return user config directly
    if (-not $PresetPath) {
        Write-LogInfo "Configuration loaded (no preset)"
        return $userConfig
    }

    # Load and merge with preset
    Write-LogDebug "Loading preset from: $PresetPath"

    if (-not (Test-Path -Path $PresetPath)) {
        Write-LogError "Preset file not found: $PresetPath"
        throw "Preset file not found: $PresetPath"
    }

    try {
        $presetConfig = Get-Content -Path $PresetPath -Raw | ConvertFrom-Json -AsHashtable
        Write-LogDebug "Preset configuration loaded successfully"
    }
    catch {
        Write-LogError "Failed to parse preset JSON: $PresetPath - $($_.Exception.Message)"
        throw "Invalid JSON in preset file: $PresetPath"
    }

    # Merge configurations (user overrides preset)
    $mergedConfig = Merge-Configurations -BaseConfig $presetConfig -OverrideConfig $userConfig

    Write-LogInfo "Configuration loaded and merged with preset: $(Split-Path -Leaf $PresetPath)"
    return $mergedConfig
}

<#
.SYNOPSIS
    Merges two configurations with shallow top-level key merge.

.DESCRIPTION
    Implements shallow merge strategy: top-level keys from override config
    completely replace corresponding keys in base config. No deep merging.

.PARAMETER BaseConfig
    Base configuration (e.g., preset). Lower priority.

.PARAMETER OverrideConfig
    Override configuration (e.g., user config). Higher priority.

.OUTPUTS
    System.Collections.Hashtable
    Returns merged configuration hashtable.

.EXAMPLE
    $merged = Merge-Configurations -BaseConfig $preset -OverrideConfig $userConfig

.NOTES
    Shallow merge strategy rationale:
    - Simple and predictable behavior
    - Avoids complex nested merge logic
    - If user provides "packages" section, entire preset "packages" is replaced
    - Example: User can completely redefine package removal list without preset interference
#>
function Merge-Configurations {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$BaseConfig,

        [Parameter(Mandatory = $true)]
        [hashtable]$OverrideConfig
    )

    Write-LogDebug "Merging configurations (shallow top-level merge)"

    # Start with base config
    $merged = $BaseConfig.Clone()

    # Override with user config keys (top-level only)
    foreach ($key in $OverrideConfig.Keys) {
        if ($merged.ContainsKey($key)) {
            Write-LogDebug "Overriding preset key: $key"
        }
        else {
            Write-LogDebug "Adding new key: $key"
        }
        $merged[$key] = $OverrideConfig[$key]
    }

    Write-LogDebug "Configuration merge complete: $($merged.Keys.Count) top-level keys"
    return $merged
}

<#
.SYNOPSIS
    Retrieves a configuration value with optional default.

.DESCRIPTION
    Safely retrieves a value from the configuration hashtable.
    Supports nested keys using dot notation (e.g., "output.imageName").

.PARAMETER Config
    Configuration hashtable.

.PARAMETER KeyPath
    Configuration key path. Use dot notation for nested values (e.g., "packages.removeEdge").

.PARAMETER DefaultValue
    Default value to return if key doesn't exist.

.OUTPUTS
    System.Object
    Returns configuration value or default value if not found.

.EXAMPLE
    $imageName = Get-ConfigValue -Config $config -KeyPath "output.imageName" -DefaultValue "tiny11.iso"

.EXAMPLE
    $removeEdge = Get-ConfigValue -Config $config -KeyPath "packages.removeEdge" -DefaultValue $false

.NOTES
    - Returns $null if key doesn't exist and no default provided
    - Dot notation: "output.imageName" retrieves $config.output.imageName
    - Safe against missing intermediate keys
#>
function Get-ConfigValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $true)]
        [string]$KeyPath,

        [Parameter(Mandatory = $false)]
        $DefaultValue = $null
    )

    # Split key path by dots
    $keys = $KeyPath -split '\.'
    $current = $Config

    # Navigate nested structure
    foreach ($key in $keys) {
        if ($current -is [hashtable] -and $current.ContainsKey($key)) {
            $current = $current[$key]
        }
        else {
            # Key not found, return default
            Write-LogDebug "Configuration key not found: $KeyPath (using default)"
            return $DefaultValue
        }
    }

    return $current
}

# Export module members
Export-ModuleMember -Function Import-BuildConfiguration, Get-ConfigValue, Merge-Configurations

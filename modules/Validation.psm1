#Requires -Version 7.0

<#
.SYNOPSIS
    Configuration validation module with schema validation and security checks.

.DESCRIPTION
    Provides comprehensive validation for build configurations:
    - JSON Schema validation against schema.json
    - Path normalization and validation
    - Sensitive data detection (passwords, API keys, tokens)
    - File existence checks
    - Architecture and format validation

.NOTES
    Module: Validation.psm1
    Requires: PowerShell 7.0+
    Dependencies: Logger.psm1
    Author: tiny11-handheld
    Version: 1.0.0
#>

<#
.SYNOPSIS
    Validates configuration against JSON Schema.

.DESCRIPTION
    Uses Test-Json cmdlet to validate configuration JSON against schema.json.
    Ensures all required fields are present and values match expected formats.

.PARAMETER ConfigPath
    Path to configuration JSON file to validate.

.PARAMETER SchemaPath
    Path to JSON Schema file. Defaults to ./schema.json in project root.

.OUTPUTS
    System.Boolean
    Returns $true if valid, throws exception if invalid.

.EXAMPLE
    Test-ConfigurationSchema -ConfigPath "./configurations.json"

.NOTES
    - Requires PowerShell 6.1+ for Test-Json cmdlet
    - Validates semver version, ISO paths, checksums, product keys, etc.
    - Throws detailed error on validation failure
#>
function Test-ConfigurationSchema {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [string]$SchemaPath = "./schema.json"
    )

    Write-LogInfo "Validating configuration against JSON Schema..."

    # Verify files exist
    if (-not (Test-Path -Path $ConfigPath)) {
        Write-LogError "Configuration file not found: $ConfigPath"
        throw "Configuration file not found: $ConfigPath"
    }

    if (-not (Test-Path -Path $SchemaPath)) {
        Write-LogError "Schema file not found: $SchemaPath"
        throw "Schema file not found: $SchemaPath"
    }

    # Load configuration JSON
    try {
        $configJson = Get-Content -Path $ConfigPath -Raw
    }
    catch {
        Write-LogError "Failed to read configuration file: $($_.Exception.Message)"
        throw "Failed to read configuration file: $ConfigPath"
    }

    # Validate against schema
    try {
        $isValid = Test-Json -Json $configJson -SchemaFile $SchemaPath -ErrorAction Stop

        if ($isValid) {
            Write-LogInfo "✓ Configuration schema validation passed"
            return $true
        }
        else {
            Write-LogError "Configuration schema validation failed"
            throw "Configuration does not conform to schema"
        }
    }
    catch {
        Write-LogError "Schema validation error: $($_.Exception.Message)"
        throw "Schema validation failed: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Validates file and directory paths in configuration.

.DESCRIPTION
    Checks that all required paths exist:
    - Source ISO file
    - Output directory (creates if missing)
    - Driver path (if driver injection enabled)
    - Update path (if update injection enabled)
    - OEM path (if OEM injection enabled)

.PARAMETER Config
    Configuration hashtable to validate.

.OUTPUTS
    System.Boolean
    Returns $true if all paths valid, throws exception on failure.

.EXAMPLE
    Test-ConfigurationPaths -Config $config

.NOTES
    - Creates output directory if it doesn't exist
    - Validates paths are accessible and readable
    - Checks conditional paths only if injection enabled
#>
function Test-ConfigurationPaths {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    Write-LogInfo "Validating configuration paths..."

    # Validate source ISO path
    if ($Config.source -and $Config.source.isoPath) {
        $isoPath = $Config.source.isoPath
        if (-not (Test-Path -Path $isoPath -PathType Leaf)) {
            Write-LogError "Source ISO file not found: $isoPath"
            throw "Source ISO file not found: $isoPath"
        }
        Write-LogDebug "✓ Source ISO exists: $isoPath"
    }
    else {
        Write-LogError "Source ISO path not specified in configuration"
        throw "Missing required field: source.isoPath"
    }

    # Validate and create output directory
    if ($Config.output -and $Config.output.outputPath) {
        $outputPath = $Config.output.outputPath
        if (-not (Test-Path -Path $outputPath)) {
            Write-LogWarning "Output directory does not exist, creating: $outputPath"
            try {
                New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
                Write-LogDebug "✓ Output directory created: $outputPath"
            }
            catch {
                Write-LogError "Failed to create output directory: $($_.Exception.Message)"
                throw "Failed to create output directory: $outputPath"
            }
        }
        else {
            Write-LogDebug "✓ Output directory exists: $outputPath"
        }
    }
    else {
        Write-LogError "Output path not specified in configuration"
        throw "Missing required field: output.outputPath"
    }

    # Validate driver path (if injection enabled)
    if ($Config.drivers -and $Config.drivers.inject -eq $true) {
        if ($Config.drivers.driverPath) {
            $driverPath = $Config.drivers.driverPath
            if (-not (Test-Path -Path $driverPath -PathType Container)) {
                Write-LogError "Driver path not found: $driverPath"
                throw "Driver path not found: $driverPath"
            }
            Write-LogDebug "✓ Driver path exists: $driverPath"
        }
        else {
            Write-LogError "Driver injection enabled but driverPath not specified"
            throw "Missing required field when drivers.inject=true: drivers.driverPath"
        }
    }

    # Validate update path (if injection enabled)
    if ($Config.updates -and $Config.updates.inject -eq $true) {
        if ($Config.updates.updatePath) {
            $updatePath = $Config.updates.updatePath
            if (-not (Test-Path -Path $updatePath -PathType Container)) {
                Write-LogError "Update path not found: $updatePath"
                throw "Update path not found: $updatePath"
            }
            Write-LogDebug "✓ Update path exists: $updatePath"
        }
        else {
            Write-LogError "Update injection enabled but updatePath not specified"
            throw "Missing required field when updates.inject=true: updates.updatePath"
        }
    }

    # Validate OEM path (if injection enabled)
    if ($Config.oem -and $Config.oem.inject -eq $true) {
        if ($Config.oem.oemPath) {
            $oemPath = $Config.oem.oemPath
            if (-not (Test-Path -Path $oemPath -PathType Container)) {
                Write-LogError "OEM path not found: $oemPath"
                throw "OEM path not found: $oemPath"
            }
            Write-LogDebug "✓ OEM path exists: $oemPath"
        }
        else {
            Write-LogError "OEM injection enabled but oemPath not specified"
            throw "Missing required field when oem.inject=true: oem.oemPath"
        }
    }

    # Validate OEM copy sources (if provided)
    if ($Config.oem -and $Config.oem.copy) {
        foreach ($item in @($Config.oem.copy)) {
            if (-not $item) { continue }
            $src = $item.source
            if (-not [string]::IsNullOrWhiteSpace($src)) {
                if (-not (Test-Path -Path $src)) {
                    Write-LogError "OEM copy source not found: $src"
                    throw "OEM copy source not found: $src"
                }
            }
        }
    }

    # Validate runOnce scripts (string or array)
    if ($Config.scripts -and $Config.scripts.runOnce) {
        foreach ($entry in @($Config.scripts.runOnce)) {
            if (-not $entry) { continue }
            if (-not (Test-Path -Path $entry)) {
                Write-LogError "runOnce script not found: $entry"
                throw "runOnce script not found: $entry"
            }
        }
    }

    Write-LogInfo "✓ All configuration paths validated"
    return $true
}

<#
.SYNOPSIS
    Detects sensitive data patterns in configuration.

.DESCRIPTION
    Scans configuration for potential sensitive data:
    - Passwords
    - API keys
    - Tokens
    - Secrets
    - Credentials
    
    Issues warnings if sensitive patterns detected (FR-020).

.PARAMETER Config
    Configuration hashtable to scan.

.OUTPUTS
    System.Boolean
    Returns $true (always passes), but logs warnings if sensitive data detected.

.EXAMPLE
    Test-SensitiveData -Config $config

.NOTES
    - Pattern matching is case-insensitive
    - Warns on detection but does not block build
    - Recommended: Use environment variables or external secret management
    - Product keys are exempt from this check (expected in unattended config)
#>
function Test-SensitiveData {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    Write-LogDebug "Scanning configuration for sensitive data patterns..."

    # Convert config to JSON for pattern matching
    $configJson = $Config | ConvertTo-Json -Depth 10

    # Sensitive data patterns (case-insensitive)
    $sensitivePatterns = @(
        'password\s*[=:]\s*["\x27][^"\x27]+["\x27]',   # password="value" or password='value'
        'apikey\s*[=:]\s*["\x27][^"\x27]+["\x27]',      # apikey="value"
        'api_key\s*[=:]\s*["\x27][^"\x27]+["\x27]',     # api_key="value"
        'token\s*[=:]\s*["\x27][^"\x27]+["\x27]',       # token="value"
        'secret\s*[=:]\s*["\x27][^"\x27]+["\x27]',      # secret="value"
        'credential\s*[=:]\s*["\x27][^"\x27]+["\x27]'   # credential="value"
    )

    $foundSensitiveData = $false

    foreach ($pattern in $sensitivePatterns) {
        if ($configJson -match $pattern) {
            $patternName = ($pattern -split '\s')[0]
            Write-LogWarning "⚠ Possible sensitive data detected: $patternName pattern found in configuration"
            Write-LogWarning "  Recommendation: Use environment variables or external secret management"
            $foundSensitiveData = $true
        }
    }

    if ($foundSensitiveData) {
        Write-LogWarning "⚠ Sensitive data detection complete: Patterns found (see warnings above)"
    }
    else {
        Write-LogDebug "✓ No sensitive data patterns detected"
    }

    # Always return true (warning only, not blocking)
    return $true
}

<#
.SYNOPSIS
    Resolves relative paths in configuration to absolute paths.

.DESCRIPTION
    Converts all relative paths in configuration to absolute paths based on
    a root directory (typically project root). Modifies config in-place.

.PARAMETER Config
    Configuration hashtable to modify.

.PARAMETER RootPath
    Root directory for resolving relative paths. Defaults to current directory.

.OUTPUTS
    System.Collections.Hashtable
    Returns modified configuration with absolute paths.

.EXAMPLE
    $config = Resolve-ConfigurationPaths -Config $config -RootPath "/home/user/tiny11-handheld"

.NOTES
    - Modifies config in-place and returns it
    - Only resolves paths that appear to be relative (don't start with / or C:\)
    - Paths that are already absolute are left unchanged
    - Applies to: isoPath, outputPath, driverPath, updatePath, oemPath
#>
function Resolve-ConfigurationPaths {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [string]$RootPath = (Get-Location).Path
    )

    Write-LogDebug "Resolving relative paths (root: $RootPath)"

    # Helper function to resolve a path if it's relative
    function Resolve-IfRelative {
        param([string]$Path, [string]$Root)
        
        if ([string]::IsNullOrWhiteSpace($Path)) {
            return $Path
        }

        # Check if path is already absolute (starts with / or drive letter)
        if ($Path -match '^([A-Za-z]:|\/)') {
            return $Path
        }

        # Resolve relative path
        $resolved = Join-Path -Path $Root -ChildPath $Path | Convert-Path -ErrorAction SilentlyContinue
        if ($resolved) {
            Write-LogDebug "  Resolved: $Path -> $resolved"
            return $resolved
        }
        else {
            # Path doesn't exist yet (e.g., output path), join anyway
            $resolved = Join-Path -Path $Root -ChildPath $Path
            Write-LogDebug "  Resolved (non-existent): $Path -> $resolved"
            return $resolved
        }
    }

    # Resolve source ISO path
    if ($Config.source -and $Config.source.isoPath) {
        $Config.source.isoPath = Resolve-IfRelative -Path $Config.source.isoPath -Root $RootPath
    }

    # Resolve output path
    if ($Config.output -and $Config.output.outputPath) {
        $Config.output.outputPath = Resolve-IfRelative -Path $Config.output.outputPath -Root $RootPath
    }

    # Resolve driver path
    if ($Config.drivers -and $Config.drivers.driverPath) {
        $Config.drivers.driverPath = Resolve-IfRelative -Path $Config.drivers.driverPath -Root $RootPath
    }

    # Resolve update path
    if ($Config.updates -and $Config.updates.updatePath) {
        $Config.updates.updatePath = Resolve-IfRelative -Path $Config.updates.updatePath -Root $RootPath
    }

    # Resolve OEM path
    if ($Config.oem -and $Config.oem.oemPath) {
        $Config.oem.oemPath = Resolve-IfRelative -Path $Config.oem.oemPath -Root $RootPath
    }

    # Resolve postInstall packages path
    if ($Config.postInstall -and $Config.postInstall.packagesJsonPath) {
        $Config.postInstall.packagesJsonPath = Resolve-IfRelative -Path $Config.postInstall.packagesJsonPath -Root $RootPath
    }

    Write-LogDebug "✓ Path resolution complete"
    return $Config
}

# Export module members
Export-ModuleMember -Function Test-ConfigurationSchema, Test-ConfigurationPaths, Test-SensitiveData, Resolve-ConfigurationPaths

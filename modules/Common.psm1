#Requires -Version 7.0

<#
.SYNOPSIS
    Common utilities and shared error codes.

.DESCRIPTION
    Provides shared utilities and standardized error codes for the build system:
    - Error code constants
    - Common helper functions
    - Build metadata structures

.NOTES
    Module: Common.psm1
    Requires: PowerShell 7.0+
    Author: tiny11-handheld
    Version: 1.0.0
#>

<#
.SYNOPSIS
    Standardized error codes for build system.

.DESCRIPTION
    Error code ranges:
    - 1-10: Configuration errors
    - 11-20: Validation errors
    - 21-30: File system errors
    - 31-40: DISM errors
    - 41-50: ISO creation errors
    - 51-60: Platform-specific errors
    - 100+: General errors
#>
$script:ErrorCodes = @{
    # Configuration errors (1-10)
    CONFIG_NOT_FOUND        = 1
    CONFIG_PARSE_ERROR      = 2
    CONFIG_INVALID_SCHEMA   = 3
    PRESET_NOT_FOUND        = 4
    
    # Validation errors (11-20)
    VALIDATION_FAILED       = 11
    PATH_NOT_FOUND          = 12
    CHECKSUM_MISMATCH       = 13
    SENSITIVE_DATA_WARNING  = 14
    
    # File system errors (21-30)
    ISO_NOT_FOUND           = 21
    OUTPUT_DIR_ERROR        = 22
    WORKSPACE_CREATE_ERROR  = 23
    EXTRACTION_FAILED       = 24
    
    # DISM errors (31-40)
    DISM_MOUNT_FAILED       = 31
    DISM_UNMOUNT_FAILED     = 32
    DISM_PACKAGE_ERROR      = 33
    DISM_DRIVER_ERROR       = 34
    DISM_UPDATE_ERROR       = 35
    DISM_CLEANUP_ERROR      = 36
    
    # ISO creation errors (41-50)
    ISO_CREATE_FAILED       = 41
    ISO_BOOT_CONFIG_ERROR   = 42
    
    # Platform-specific errors (51-60)
    DOCKER_NOT_FOUND        = 51
    DOCKER_IMAGE_ERROR      = 52
    WINDOWS_DISM_ERROR      = 53
    UNSUPPORTED_PLATFORM    = 54
    
    # Memory errors (61-70)
    MEMORY_LIMIT_EXCEEDED   = 61
    
    # General errors (100+)
    UNKNOWN_ERROR           = 100
    PREREQUISITE_FAILED     = 101
    USER_CANCELLED          = 102
}

# Make error codes available to importers
Set-Variable -Name ErrorCodes -Value $script:ErrorCodes -Scope Script -Option ReadOnly

<#
.SYNOPSIS
    Creates a structured error detail object.

.DESCRIPTION
    Standardizes error reporting across the build system with consistent structure.

.PARAMETER ErrorCode
    Numeric error code from $ErrorCodes.

.PARAMETER Message
    Human-readable error message.

.PARAMETER Stage
    Build stage where error occurred (e.g., "PackageRemoval", "ISOExtraction").

.PARAMETER Details
    Optional additional details or context.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns error detail object with code, message, stage, timestamp, details.

.EXAMPLE
    $error = New-ErrorDetail -ErrorCode $ErrorCodes.DISM_MOUNT_FAILED -Message "Failed to mount WIM" -Stage "Mounting"

.EXAMPLE
    $error = New-ErrorDetail -ErrorCode $ErrorCodes.ISO_NOT_FOUND -Message "Source ISO not found" -Stage "Validation" -Details $isoPath

.NOTES
    - Used for logging and error reporting
    - Includes timestamp for debugging
    - Provides context for partial rollback
#>
function New-ErrorDetail {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ErrorCode,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [string]$Stage,

        [Parameter(Mandatory = $false)]
        [string]$Details = ""
    )

    return [PSCustomObject]@{
        ErrorCode = $ErrorCode
        Message   = $Message
        Stage     = $Stage
        Details   = $Details
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

<#
.SYNOPSIS
    Retrieves build system metadata.

.DESCRIPTION
    Returns information about the build system version, platform, and environment.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns metadata object with version, platform, PowerShell version, date.

.EXAMPLE
    $metadata = Get-BuildMetadata
    Write-LogInfo "Build system version: $($metadata.Version)"

.NOTES
    - Used for logging build information
    - Helps with troubleshooting and support
    - Version follows semver (MAJOR.MINOR.PATCH)
#>
function Get-BuildMetadata {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    return [PSCustomObject]@{
        Version           = "1.0.0"
        Platform          = if ($IsLinux) { "Linux" } elseif ($IsWindows) { "Windows" } else { "Unknown" }
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        BuildDate         = Get-Date -Format "yyyy-MM-dd"
        Architecture      = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    }
}

# Export module members
Export-ModuleMember -Variable ErrorCodes
Export-ModuleMember -Function New-ErrorDetail, Get-BuildMetadata

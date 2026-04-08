#Requires -Version 7.0

<#
.SYNOPSIS
    Hybrid logging module for cross-platform build system.

.DESCRIPTION
    Provides unified logging interface that adapts to platform conventions:
    - Windows: Uses native PowerShell verbs (Write-Error, Write-Warning, Write-Information, Write-Verbose)
    - Linux/Cross-platform: Provides ERROR/WARN/INFO/DEBUG abstraction for Bash integration
    
    All log messages include timestamps and are written to both console and log file.

.NOTES
    Module: Logger.psm1
    Requires: PowerShell 7.0+
    Author: tiny11-handheld
    Version: 1.0.0
#>

# Module-scoped variable for log file path
$script:LogFilePath = $null

<#
.SYNOPSIS
    Initializes the logging system with a log file path.

.DESCRIPTION
    Sets up the logging system by creating the log file and directory if needed.
    Must be called before any logging functions are used.

.PARAMETER LogPath
    Full path to the log file. Directory will be created if it doesn't exist.

.EXAMPLE
    Initialize-Logger -LogPath "./output/build-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

.NOTES
    - Creates parent directory if it doesn't exist
    - Overwrites existing log file
    - Writes initialization message to log
#>
function Initialize-Logger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath
    )

    # Ensure parent directory exists
    $logDir = Split-Path -Path $LogPath -Parent
    if ($logDir -and -not (Test-Path -Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    # Set module-scoped log path
    $script:LogFilePath = $LogPath

    # Initialize log file with header
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $header = @"
====================================================================================================
Tiny11 Handheld Build Log
Started: $timestamp
Platform: $(if ($IsLinux) { "Linux" } else { "Windows" })
PowerShell: $($PSVersionTable.PSVersion)
====================================================================================================

"@
    Set-Content -Path $script:LogFilePath -Value $header -Force
}

<#
.SYNOPSIS
    Gets the current log file path.

.DESCRIPTION
    Returns the log file path set by Initialize-Logger.

.OUTPUTS
    System.String
    Returns log file path or $null if logging not initialized.

.EXAMPLE
    $logPath = Get-LogFilePath
#>
function Get-LogFilePath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return $script:LogFilePath
}

<#
.SYNOPSIS
    Writes an ERROR-level log message.

.DESCRIPTION
    Logs an error message using platform-appropriate conventions:
    - Windows: Write-Error (red text, error stream)
    - Linux: "[ERROR]" prefix to stdout for Bash parsing

.PARAMETER Message
    The error message to log.

.EXAMPLE
    Write-LogError "Failed to mount WIM image: Access denied"

.NOTES
    - Always writes to log file if initialized
    - Uses ErrorRecord for Windows to preserve stack trace
#>
function Write-LogError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [ERROR] $Message"

    # Write to log file
    if ($script:LogFilePath) {
        Add-Content -Path $script:LogFilePath -Value $logMessage
    }

    # Platform-specific console output
    if ($IsWindows) {
        Write-Error -Message $Message -ErrorAction Continue
    }
    else {
        # Linux/cross-platform: Use explicit prefix for Bash parsing
        Write-Host "[ERROR] $Message" -ForegroundColor Red
    }
}

<#
.SYNOPSIS
    Writes a WARNING-level log message.

.DESCRIPTION
    Logs a warning message using platform-appropriate conventions:
    - Windows: Write-Warning (yellow text, warning stream)
    - Linux: "[WARN]" prefix to stdout for Bash parsing

.PARAMETER Message
    The warning message to log.

.EXAMPLE
    Write-LogWarning "Package 'Microsoft.BingNews' not found, skipping removal"

.NOTES
    - Always writes to log file if initialized
    - Non-blocking, execution continues after warning
#>
function Write-LogWarning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [WARN] $Message"

    # Write to log file
    if ($script:LogFilePath) {
        Add-Content -Path $script:LogFilePath -Value $logMessage
    }

    # Platform-specific console output
    if ($IsWindows) {
        Write-Warning -Message $Message
    }
    else {
        # Linux/cross-platform: Use explicit prefix for Bash parsing
        Write-Host "[WARN] $Message" -ForegroundColor Yellow
    }
}

<#
.SYNOPSIS
    Writes an INFO-level log message.

.DESCRIPTION
    Logs an informational message using platform-appropriate conventions:
    - Windows: Write-Information (information stream, requires -InformationAction Continue)
    - Linux: "[INFO]" prefix to stdout for Bash parsing

.PARAMETER Message
    The informational message to log.

.EXAMPLE
    Write-LogInfo "Starting package removal phase..."

.NOTES
    - Always writes to log file if initialized
    - Default visibility level for normal operations
#>
function Write-LogInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [INFO] $Message"

    # Write to log file
    if ($script:LogFilePath) {
        Add-Content -Path $script:LogFilePath -Value $logMessage
    }

    # Platform-specific console output
    if ($IsWindows) {
        Write-Information -MessageData $Message -InformationAction Continue
    }
    else {
        # Linux/cross-platform: Use explicit prefix for Bash parsing
        Write-Host "[INFO] $Message"
    }
}

<#
.SYNOPSIS
    Writes a DEBUG-level log message.

.DESCRIPTION
    Logs a debug message using platform-appropriate conventions:
    - Windows: Write-Verbose (verbose stream, requires -Verbose flag)
    - Linux: "[DEBUG]" prefix to stdout for Bash parsing (only if VERBOSE env var set)

.PARAMETER Message
    The debug message to log.

.EXAMPLE
    Write-LogDebug "Configuration validation: 15 fields validated successfully"

.NOTES
    - Always writes to log file if initialized
    - Only shown in console when verbose/debug mode enabled
    - On Linux, check $env:VERBOSE for visibility
#>
function Write-LogDebug {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [DEBUG] $Message"

    # Write to log file
    if ($script:LogFilePath) {
        Add-Content -Path $script:LogFilePath -Value $logMessage
    }

    # Platform-specific console output
    if ($IsWindows) {
        Write-Verbose -Message $Message
    }
    else {
        # Linux/cross-platform: Only show if VERBOSE environment variable is set
        if ($env:VERBOSE -eq "1" -or $env:VERBOSE -eq "true") {
            Write-Host "[DEBUG] $Message" -ForegroundColor Cyan
        }
    }
}

# Export module members
Export-ModuleMember -Function Initialize-Logger, Write-LogError, Write-LogWarning, Write-LogInfo, Write-LogDebug, Get-LogFilePath

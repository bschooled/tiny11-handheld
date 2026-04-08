#Requires -Version 7.0

<#
.SYNOPSIS
    Platform detection module for cross-platform build system.

.DESCRIPTION
    Provides platform detection functionality to determine whether the build
    is running on Linux or Windows. This enables conditional logic for
    platform-specific operations (Docker DISM vs native DISM).

.NOTES
    Module: Platform.psm1
    Requires: PowerShell 7.0+
    Author: tiny11-handheld
    Version: 1.0.0
#>

<#
.SYNOPSIS
    Detects the current operating system platform.

.DESCRIPTION
    Determines whether the build is running on Linux or Windows by checking
    the $IsLinux and $IsWindows automatic variables (PowerShell 7+).
    Returns a platform identifier string used throughout the build system.

.OUTPUTS
    System.String
    Returns "Linux" if running on Linux, "Windows" if running on Windows.

.EXAMPLE
    $platform = Get-BuildPlatform
    if ($platform -eq "Linux") {
        # Use Docker DISM
    } else {
        # Use native DISM
    }

.NOTES
    - Requires PowerShell 7.0+ for $IsLinux/$IsWindows automatic variables
    - Throws error if platform cannot be determined (e.g., macOS, FreeBSD)
    - Platform detection is case-sensitive for consistency
#>
function Get-BuildPlatform {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # PowerShell 7+ provides automatic variables for platform detection
    if ($IsLinux) {
        return "Linux"
    }
    elseif ($IsWindows) {
        return "Windows"
    }
    else {
        throw "Unsupported platform detected. This build system requires Linux or Windows."
    }
}

# Export module members
Export-ModuleMember -Function Get-BuildPlatform

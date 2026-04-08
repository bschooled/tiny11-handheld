#Requires -Version 5.1

<#
.SYNOPSIS
    Windows image building module with native DISM operations.

.DESCRIPTION
    Provides Windows-specific implementation for WIM manipulation using
    native DISM cmdlets and tools. Implements all image modification
    operations required for tiny11-handheld build process.

.NOTES
    Module: ImageBuilder.psm1
    Platform: Windows only
    Requires: PowerShell 5.1+, DISM (built-in), Administrator privileges
    Dependencies: Logger.psm1, Common.psm1
    Author: tiny11-handheld
    Version: 1.0.0
#>

# Export module members
Export-ModuleMember -Function Mount-WindowsImageCustom, Dismount-WindowsImageCustom, Remove-WindowsPackages, Add-WindowsDriversCustom, Add-WindowsUpdatesCustom, Optimize-WindowsImageCustom, Get-WindowsPackageList

<#
.SYNOPSIS
    Mounts a Windows image (WIM) file.

.DESCRIPTION
    Mounts a WIM file using native DISM with proper error handling and logging.

.PARAMETER WimPath
    Path to WIM file to mount.

.PARAMETER MountPath
    Directory where the image will be mounted.

.PARAMETER Index
    Image index to mount. Defaults to 1.

.PARAMETER ReadOnly
    Mount image as read-only.

.EXAMPLE
    Mount-WindowsImageCustom -WimPath ".\install.wim" -MountPath ".\mount" -Index 1

.NOTES
    - Requires administrator privileges
    - Creates mount directory if it doesn't exist
    - Uses Dism.exe for compatibility with PowerShell 5.1
#>
function Mount-WindowsImageCustom {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WimPath,

        [Parameter(Mandatory = $true)]
        [string]$MountPath,

        [Parameter(Mandatory = $false)]
        [int]$Index = 1,

        [Parameter(Mandatory = $false)]
        [switch]$ReadOnly
    )

    Write-LogInfo "Mounting WIM image..."
    Write-LogDebug "  WIM: $WimPath"
    Write-LogDebug "  Mount: $MountPath"
    Write-LogDebug "  Index: $Index"

    # Verify WIM exists
    if (-not (Test-Path -Path $WimPath)) {
        Write-LogError "WIM file not found: $WimPath"
        throw "WIM file not found: $WimPath"
    }

    # Create mount directory
    if (-not (Test-Path -Path $MountPath)) {
        Write-LogDebug "Creating mount directory: $MountPath"
        New-Item -Path $MountPath -ItemType Directory -Force | Out-Null
    }

    # Build DISM arguments
    $dismArgs = @(
        "/Mount-Wim",
        "/WimFile:$WimPath",
        "/MountDir:$MountPath",
        "/Index:$Index"
    )

    if ($ReadOnly) {
        $dismArgs += "/ReadOnly"
    }

    # Mount WIM
    Write-LogInfo "Executing DISM mount operation..."
    $dismOutput = & dism.exe $dismArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-LogError "DISM mount failed with exit code: $LASTEXITCODE"
        Write-LogError "DISM output: $($dismOutput -join "`n")"
        throw "Failed to mount WIM image"
    }

    Write-LogInfo "✓ WIM mounted successfully: $MountPath"
}

<#
.SYNOPSIS
    Unmounts a Windows image.

.DESCRIPTION
    Unmounts a WIM file with option to commit or discard changes.

.PARAMETER MountPath
    Path to mounted image directory.

.PARAMETER Commit
    Commit changes to WIM file. If false, discards changes.

.EXAMPLE
    Dismount-WindowsImageCustom -MountPath ".\mount" -Commit

.NOTES
    - Automatically retries with /Discard if commit fails
    - Cleans up mount directory after unmount
#>
function Dismount-WindowsImageCustom {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MountPath,

        [Parameter(Mandatory = $false)]
        [switch]$Commit
    )

    if (-not (Test-Path -Path $MountPath)) {
        Write-LogWarning "Mount path does not exist, nothing to unmount: $MountPath"
        return
    }

    $action = if ($Commit) { "/Commit" } else { "/Discard" }
    Write-LogInfo "Unmounting WIM image: $MountPath ($action)"

    # Unmount WIM
    $dismOutput = & dism.exe /Unmount-Wim /MountDir:$MountPath $action 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-LogWarning "DISM unmount failed with exit code: $LASTEXITCODE"
        Write-LogWarning "Attempting cleanup with /Discard..."
        
        # Retry with discard
        $dismOutput = & dism.exe /Unmount-Wim /MountDir:$MountPath /Discard 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-LogError "DISM unmount with /Discard also failed"
            Write-LogError "DISM output: $($dismOutput -join "`n")"
            Write-LogWarning "Manual cleanup may be required: dism /Cleanup-Wim"
        }
    }

    # Clean up mount directory
    if (Test-Path -Path $MountPath) {
        try {
            Remove-Item -Path $MountPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-LogDebug "✓ Mount directory removed"
        }
        catch {
            Write-LogWarning "Failed to remove mount directory: $MountPath"
        }
    }

    Write-LogInfo "✓ WIM unmounted"
}

<#
.SYNOPSIS
    Gets list of provisioned Windows packages from mounted image.

.DESCRIPTION
    Retrieves all provisioned AppX packages from a mounted Windows image.

.PARAMETER MountPath
    Path to mounted image directory.

.OUTPUTS
    Array of package names.

.EXAMPLE
    $packages = Get-WindowsPackageList -MountPath ".\mount"

.NOTES
    - Returns package names only, not full package objects
    - Used for selective removal with remove/keep lists
#>
function Get-WindowsPackageList {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MountPath
    )

    Write-LogInfo "Retrieving installed packages from image..."

    $dismOutput = & dism.exe /Image:$MountPath /Get-ProvisionedAppxPackages 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-LogError "Failed to get package list: DISM exit code $LASTEXITCODE"
        return @()
    }

    # Parse DISM output to extract package names
    $packages = $dismOutput | Where-Object { $_ -match "^PackageName\s*:\s*(.+)$" } | ForEach-Object {
        $matches[1].Trim()
    }

    Write-LogDebug "Found $($packages.Count) provisioned packages"
    return $packages
}

<#
.SYNOPSIS
    Removes Windows packages from mounted image.

.DESCRIPTION
    Removes specified AppX packages from a mounted Windows image using DISM.
    Supports remove/keep list filtering.

.PARAMETER MountPath
    Path to mounted image directory.

.PARAMETER RemoveList
    Array of package names to remove.

.PARAMETER KeepList
    Array of package names to preserve (takes precedence over RemoveList).

.EXAMPLE
    Remove-WindowsPackages -MountPath ".\mount" -RemoveList @("Microsoft.BingNews", "Microsoft.Xbox.TCUI")

.NOTES
    - Keep list takes precedence over remove list
    - Logs warnings for packages that fail to remove
    - Does not throw errors for missing packages
#>
function Remove-WindowsPackages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MountPath,

        [Parameter(Mandatory = $false)]
        [string[]]$RemoveList = @(),

        [Parameter(Mandatory = $false)]
        [string[]]$KeepList = @()
    )

    Write-LogInfo "Starting package removal phase..."

    # Get all installed packages
    $installedPackages = Get-WindowsPackageList -MountPath $MountPath

    if ($installedPackages.Count -eq 0) {
        Write-LogWarning "No packages found in image"
        return
    }

    # Filter packages to remove
    $packagesToRemove = $RemoveList | Where-Object {
        $packageName = $_
        
        # Skip if in keep list
        if ($KeepList -contains $packageName) {
            Write-LogDebug "Skipping package (in keep list): $packageName"
            return $false
        }

        # Check if package exists (partial match)
        $exists = $installedPackages | Where-Object { $_ -like "*$packageName*" }
        if (-not $exists) {
            Write-LogWarning "Package not found (skipping): $packageName"
            return $false
        }

        return $true
    }

    Write-LogInfo "Removing $($packagesToRemove.Count) packages..."

    $successCount = 0
    $failCount = 0

    foreach ($packagePattern in $packagesToRemove) {
        # Find full package name
        $fullPackageName = $installedPackages | Where-Object { $_ -like "*$packagePattern*" } | Select-Object -First 1

        if ($fullPackageName) {
            Write-LogInfo "Removing: $fullPackageName"

            $dismOutput = & dism.exe /Image:$MountPath /Remove-ProvisionedAppxPackage /PackageName:$fullPackageName 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-LogDebug "✓ Removed: $fullPackageName"
                $successCount++
            }
            else {
                Write-LogWarning "Failed to remove: $fullPackageName (exit code: $LASTEXITCODE)"
                $failCount++
            }
        }
    }

    Write-LogInfo "✓ Package removal complete: $successCount removed, $failCount failed"
}

<#
.SYNOPSIS
    Injects drivers into mounted Windows image.

.DESCRIPTION
    Adds device drivers from a directory to the Windows image using DISM.

.PARAMETER MountPath
    Path to mounted image directory.

.PARAMETER DriverPath
    Path to directory containing driver INF files.

.PARAMETER Recursive
    Search driver path recursively.

.EXAMPLE
    Add-WindowsDriversCustom -MountPath ".\mount" -DriverPath ".\drivers" -Recursive

.NOTES
    - Only processes .inf files
    - DISM validates driver signatures
    - Invalid drivers are skipped with warnings
#>
function Add-WindowsDriversCustom {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MountPath,

        [Parameter(Mandatory = $true)]
        [string]$DriverPath,

        [Parameter(Mandatory = $false)]
        [switch]$Recursive
    )

    Write-LogInfo "Injecting drivers from: $DriverPath"

    if (-not (Test-Path -Path $DriverPath)) {
        Write-LogError "Driver path not found: $DriverPath"
        throw "Driver path not found: $DriverPath"
    }

    $dismArgs = @(
        "/Image:$MountPath",
        "/Add-Driver",
        "/Driver:$DriverPath"
    )

    if ($Recursive) {
        $dismArgs += "/Recurse"
    }

    $dismOutput = & dism.exe $dismArgs 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-LogInfo "✓ Drivers injected successfully"
    }
    else {
        Write-LogWarning "Driver injection completed with warnings (exit code: $LASTEXITCODE)"
        Write-LogDebug "DISM output: $($dismOutput -join "`n")"
    }
}

<#
.SYNOPSIS
    Applies Windows updates to mounted image.

.DESCRIPTION
    Injects Windows Update packages (.msu, .cab) into the image.

.PARAMETER MountPath
    Path to mounted image directory.

.PARAMETER UpdatePath
    Path to directory containing update files.

.EXAMPLE
    Add-WindowsUpdatesCustom -MountPath ".\mount" -UpdatePath ".\updates"

.NOTES
    - Supports .msu and .cab files
    - Processes updates sequentially
    - Large cumulative updates can take 30+ minutes
#>
function Add-WindowsUpdatesCustom {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MountPath,

        [Parameter(Mandatory = $true)]
        [string]$UpdatePath
    )

    Write-LogInfo "Applying updates from: $UpdatePath"

    if (-not (Test-Path -Path $UpdatePath)) {
        Write-LogError "Update path not found: $UpdatePath"
        throw "Update path not found: $UpdatePath"
    }

    # Find all update files
    $updateFiles = Get-ChildItem -Path $UpdatePath -Include *.msu,*.cab -Recurse

    if ($updateFiles.Count -eq 0) {
        Write-LogWarning "No update files found in: $UpdatePath"
        return
    }

    Write-LogInfo "Found $($updateFiles.Count) update file(s)"

    foreach ($updateFile in $updateFiles) {
        Write-LogInfo "Applying: $($updateFile.Name)"

        $dismOutput = & dism.exe /Image:$MountPath /Add-Package /PackagePath:$updateFile.FullName 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-LogDebug "✓ Applied: $($updateFile.Name)"
        }
        else {
            Write-LogWarning "Failed to apply: $($updateFile.Name) (exit code: $LASTEXITCODE)"
        }
    }

    Write-LogInfo "✓ Update injection complete"
}

<#
.SYNOPSIS
    Optimizes Windows image by cleaning up component store.

.DESCRIPTION
    Runs DISM cleanup operations to reduce image size.

.PARAMETER MountPath
    Path to mounted image directory.

.PARAMETER ResetBase
    Reset the base of superseded components (irreversible).

.EXAMPLE
    Optimize-WindowsImageCustom -MountPath ".\mount" -ResetBase

.NOTES
    - /StartComponentCleanup: Removes superseded components (reversible)
    - /ResetBase: Makes cleanup permanent (irreversible, more space savings)
    - Can take 10-20 minutes
#>
function Optimize-WindowsImageCustom {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MountPath,

        [Parameter(Mandatory = $false)]
        [switch]$ResetBase
    )

    Write-LogInfo "Running component cleanup..."

    $dismArgs = @(
        "/Image:$MountPath",
        "/Cleanup-Image",
        "/StartComponentCleanup"
    )

    if ($ResetBase) {
        Write-LogWarning "Using /ResetBase - this operation is irreversible"
        $dismArgs += "/ResetBase"
    }

    $dismOutput = & dism.exe $dismArgs 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-LogInfo "✓ Component cleanup completed successfully"
    }
    else {
        Write-LogWarning "Component cleanup completed with warnings (exit code: $LASTEXITCODE)"
        Write-LogDebug "DISM output: $($dismOutput -join "`n")"
    }
}

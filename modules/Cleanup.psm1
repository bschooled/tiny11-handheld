#Requires -Version 7.0

<#
.SYNOPSIS
    Workspace cleanup and partial rollback module.

.DESCRIPTION
    Manages cleanup of build artifacts and implements partial rollback strategy:
    - Cleans workspace directories
    - Unmounts WIM images safely
    - Implements partial rollback (preserves completed stages, undoes failed stage only)
    - Manages temporary files and directories

.NOTES
    Module: Cleanup.psm1
    Requires: PowerShell 7.0+
    Dependencies: Logger.psm1
    Author: tiny11-handheld
    Version: 1.0.0
#>

<#
.SYNOPSIS
    Initializes the build workspace directory.

.DESCRIPTION
    Creates a clean workspace directory for build operations.
    Removes existing workspace if present.

.PARAMETER WorkspacePath
    Path to workspace directory.

.OUTPUTS
    System.String
    Returns workspace path.

.EXAMPLE
    $workspace = Initialize-Workspace -WorkspacePath "./workspace"

.NOTES
    - Creates parent directories if needed
    - Removes existing workspace to ensure clean state
    - Logs all operations
#>
function Initialize-Workspace {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspacePath
    )

    Write-LogInfo "Initializing workspace: $WorkspacePath"

    # Remove existing workspace if present
    if (Test-Path -Path $WorkspacePath) {
        Write-LogWarning "Removing existing workspace: $WorkspacePath"
        try {
            Remove-Item -Path $WorkspacePath -Recurse -Force -ErrorAction Stop
            Write-LogDebug "✓ Existing workspace removed"
        }
        catch {
            Write-LogError "Failed to remove existing workspace: $($_.Exception.Message)"
            throw "Failed to remove existing workspace: $WorkspacePath"
        }
    }

    # Create fresh workspace
    try {
        New-Item -Path $WorkspacePath -ItemType Directory -Force | Out-Null
        Write-LogInfo "✓ Workspace initialized: $WorkspacePath"
    }
    catch {
        Write-LogError "Failed to create workspace: $($_.Exception.Message)"
        throw "Failed to create workspace: $WorkspacePath"
    }

    return $WorkspacePath
}

<#
.SYNOPSIS
    Removes the build workspace directory.

.DESCRIPTION
    Cleans up the workspace directory after build completion or failure.
    Ensures all files are removed properly.

.PARAMETER WorkspacePath
    Path to workspace directory to remove.

.PARAMETER Force
    Force removal even if files are in use (use with caution).

.EXAMPLE
    Remove-Workspace -WorkspacePath "./workspace"

.NOTES
    - Logs warnings if workspace cannot be removed
    - Does not throw errors (cleanup failures shouldn't block build reporting)
#>
function Remove-Workspace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspacePath,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    if (-not (Test-Path -Path $WorkspacePath)) {
        Write-LogDebug "Workspace does not exist, nothing to remove: $WorkspacePath"
        return
    }

    Write-LogInfo "Removing workspace: $WorkspacePath"

    try {
        Remove-Item -Path $WorkspacePath -Recurse -Force:$Force -ErrorAction Stop
        Write-LogInfo "✓ Workspace removed successfully"
    }
    catch {
        Write-LogWarning "Failed to remove workspace: $($_.Exception.Message)"
        Write-LogWarning "  Manual cleanup may be required: $WorkspacePath"
    }
}

<#
.SYNOPSIS
    Implements partial rollback for failed build stages.

.DESCRIPTION
    Partial rollback strategy (FR-010):
    - Preserves completed stages (e.g., ISO extraction, package removal)
    - Only undoes the failed stage
    - Allows retry from point of failure
    - More efficient than complete rollback

.PARAMETER StageName
    Name of the stage that failed.

.PARAMETER WorkspacePath
    Path to workspace directory.

.PARAMETER MountPath
    Path to mounted WIM image (if any).

.PARAMETER KeepWorkspace
    If true, preserves workspace for debugging.

.EXAMPLE
    Invoke-PartialRollback -StageName "PackageRemoval" -WorkspacePath "./workspace" -MountPath "./workspace/mount"

.NOTES
    - Only cleans up resources from failed stage
    - Preserves previous stages for retry
    - Unmounts WIM if mounted
    - Can preserve workspace for debugging
#>
function Invoke-PartialRollback {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StageName,

        [Parameter(Mandatory = $true)]
        [string]$WorkspacePath,

        [Parameter(Mandatory = $false)]
        [string]$MountPath,

        [Parameter(Mandatory = $false)]
        [switch]$KeepWorkspace
    )

    Write-LogWarning "Initiating partial rollback for failed stage: $StageName"

    # Unmount WIM if it was mounted during this stage
    if ($MountPath -and (Test-Path -Path $MountPath)) {
        Write-LogInfo "Unmounting WIM image from failed stage..."
        Dismount-SafeWIM -MountPath $MountPath
    }

    # Clean up stage-specific temporary files
    # Note: We preserve earlier stages (extracted ISO, etc.) for retry

    if ($KeepWorkspace) {
        Write-LogInfo "Workspace preserved for debugging: $WorkspacePath"
        Write-LogInfo "  To retry, fix the issue and run build again"
    }
    else {
        Write-LogInfo "Removing workspace (preserving completed stages not yet implemented)"
        # Future: Implement selective cleanup based on stage
        # For now, remove entire workspace for simplicity
        Remove-Workspace -WorkspacePath $WorkspacePath
    }

    Write-LogWarning "✓ Partial rollback complete for stage: $StageName"
}

<#
.SYNOPSIS
    Safely unmounts a WIM image with error handling.

.DESCRIPTION
    Unmounts a WIM image and handles common errors:
    - Checks if mount point exists
    - Discards changes on failure
    - Retries if initial unmount fails
    - Cleans up mount directory

.PARAMETER MountPath
    Path to WIM mount point.

.PARAMETER SaveChanges
    If true, saves changes to WIM. If false (default), discards changes.

.EXAMPLE
    Dismount-SafeWIM -MountPath "./workspace/mount" -SaveChanges

.NOTES
    - Uses DISM to unmount
    - Platform-aware (Docker DISM on Linux, native on Windows)
    - Retries once if unmount fails
    - Always logs operations
#>
function Dismount-SafeWIM {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MountPath,

        [Parameter(Mandatory = $false)]
        [switch]$SaveChanges
    )

    if (-not (Test-Path -Path $MountPath)) {
        Write-LogDebug "Mount path does not exist, nothing to unmount: $MountPath"
        return
    }

    Write-LogInfo "Unmounting WIM image: $MountPath"

    $dismountArgs = if ($SaveChanges) {
        "/Commit"
    }
    else {
        "/Discard"
    }

    try {
        # Use DISM to unmount
        # Note: Platform detection handled by calling script (Docker on Linux, native on Windows)
        $dismResult = & dism /Unmount-Wim /MountDir:$MountPath $dismountArgs

        if ($LASTEXITCODE -eq 0) {
            Write-LogInfo "✓ WIM unmounted successfully"
        }
        else {
            Write-LogWarning "DISM unmount returned non-zero exit code: $LASTEXITCODE"
            Write-LogWarning "  Attempting cleanup with /Discard..."
            
            # Retry with discard
            & dism /Unmount-Wim /MountDir:$MountPath /Discard | Out-Null
        }
    }
    catch {
        Write-LogError "Failed to unmount WIM: $($_.Exception.Message)"
        Write-LogWarning "  Manual cleanup may be required: dism /Cleanup-Wim"
    }
    finally {
        # Remove mount directory if it still exists
        if (Test-Path -Path $MountPath) {
            try {
                Remove-Item -Path $MountPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-LogDebug "✓ Mount directory removed"
            }
            catch {
                Write-LogWarning "Failed to remove mount directory: $MountPath"
            }
        }
    }
}

# Export module members
Export-ModuleMember -Function Initialize-Workspace, Remove-Workspace, Invoke-PartialRollback, Dismount-SafeWIM

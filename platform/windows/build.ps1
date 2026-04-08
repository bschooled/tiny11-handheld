#Requires -Version 5.1

<#
.SYNOPSIS
    Tiny11 Handheld - Windows Build Script

.DESCRIPTION
    Cross-platform Windows 11 image builder for Windows hosts using native DISM.
    Creates customized Windows 11 installation ISOs with debloating, bypasses,
    and device-specific optimizations.

.PARAMETER ConfigPath
    Path to configuration JSON file.

.PARAMETER PresetPath
    Path to preset configuration file (base configuration).

.PARAMETER SourceIso
    Path to Windows 11 source ISO file.

.PARAMETER WorkspacePath
    Custom workspace directory. Defaults to .\workspace

.PARAMETER Force
    Skip confirmation prompts.

.EXAMPLE
    .\build.ps1 -SourceIso "Win11_23H2_x64.iso" -ConfigPath "configurations.json"

.EXAMPLE
    .\build.ps1 -SourceIso "Win11.iso" -PresetPath "presets\handheld-default.json"

.EXAMPLE
    .\build.ps1 -SourceIso "Win11.iso" -ConfigPath "my-config.json" -PresetPath "presets\rog-ally.json"

.NOTES
    Script: build.ps1
    Platform: Windows 10/11
    Requires: PowerShell 5.1+, Administrator privileges, DISM, oscdimg, 7-Zip
    Author: tiny11-handheld
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [string]$PresetPath,

    [Parameter(Mandatory = $true)]
    [string]$SourceIso,

    [Parameter(Mandatory = $false)]
    [string]$WorkspacePath = ".\workspace",

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Script initialization
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

# Import modules
Import-Module "$ProjectRoot\modules\Platform.psm1" -Force
Import-Module "$ProjectRoot\modules\Logger.psm1" -Force
Import-Module "$ProjectRoot\modules\Config.psm1" -Force
Import-Module "$ProjectRoot\modules\Validation.psm1" -Force
Import-Module "$ProjectRoot\modules\Cleanup.psm1" -Force
Import-Module "$ProjectRoot\modules\Common.psm1" -Force
Import-Module "$ProjectRoot\modules\Autounattend.psm1" -Force

# Validate parameters
if (-not $ConfigPath -and -not $PresetPath) {
    Write-Error "At least one of -ConfigPath or -PresetPath must be specified"
    exit 1
}

if (-not (Test-Path -Path $SourceIso)) {
    Write-Error "Source ISO file not found: $SourceIso"
    exit 1
}

# Initialize logging
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputDir = Join-Path -Path $ProjectRoot -ChildPath "output\logs"
if (-not (Test-Path -Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
}
$logFile = Join-Path -Path $outputDir -ChildPath "build-windows-$timestamp.log"

Initialize-Logger -LogPath $logFile

Write-Host ""
Write-Host "====================================================================================================" -ForegroundColor Cyan
Write-Host "Tiny11 Handheld - Windows Build" -ForegroundColor Cyan
Write-Host "====================================================================================================" -ForegroundColor Cyan
Write-Host "Source ISO: $SourceIso" -ForegroundColor White
Write-Host "Config: $(if ($ConfigPath) { $ConfigPath } else { '<none>' })" -ForegroundColor White
Write-Host "Preset: $(if ($PresetPath) { $PresetPath } else { '<none>' })" -ForegroundColor White
Write-Host "Workspace: $WorkspacePath" -ForegroundColor White
Write-Host "Log: $logFile" -ForegroundColor White
Write-Host "====================================================================================================" -ForegroundColor Cyan
Write-Host ""

Write-LogInfo "Build started on Windows platform"

# Check administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-LogError "This script must be run as Administrator for DISM operations"
    Write-Host ""
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Red
    exit 1
}

Write-LogInfo "Administrator privileges confirmed"

# Load and validate configuration
Write-LogInfo "Loading configuration..."

$configArgs = @{}
if ($ConfigPath) {
    $configArgs.ConfigPath = Resolve-Path -Path $ConfigPath
}
if ($PresetPath) {
    $configArgs.PresetPath = Resolve-Path -Path $PresetPath
}

try {
    $config = Import-BuildConfiguration @configArgs
    $config = Resolve-ConfigurationPaths -Config $config -RootPath $ProjectRoot

    # Validate configuration
    if ($ConfigPath) {
        $schemaPath = Join-Path -Path $ProjectRoot -ChildPath "schema.json"
        Test-ConfigurationSchema -ConfigPath $configArgs.ConfigPath -SchemaPath $schemaPath
    }
    
    Test-ConfigurationPaths -Config $config
    Test-SensitiveData -Config $config

    Write-LogInfo "Configuration loaded and validated successfully"
}
catch {
    Write-LogError "Configuration validation failed: $($_.Exception.Message)"
    exit 1
}

# T038: Error handling setup
$global:WorkspacePath = Resolve-Path -Path $WorkspacePath -ErrorAction SilentlyContinue
if (-not $global:WorkspacePath) {
    $global:WorkspacePath = Join-Path -Path $ProjectRoot -ChildPath $WorkspacePath
}

function Cleanup-OnError {
    param($ErrorRecord)
    
    Write-Host ""
    Write-LogError "Build failed: $($ErrorRecord.Exception.Message)"
    Write-Host ""
    Write-LogInfo "Performing cleanup..."
    
    # Unmount WIM if mounted
    $mountPath = Join-Path -Path $global:WorkspacePath -ChildPath "mount"
    if (Test-Path -Path $mountPath) {
        try {
            Dismount-WindowsImage -Path $mountPath -Discard -ErrorAction SilentlyContinue | Out-Null
            Write-LogInfo "WIM unmounted (changes discarded)"
        }
        catch {
            Write-LogWarning "Failed to unmount WIM: $($_.Exception.Message)"
        }
    }
    
    Write-LogInfo "Cleanup complete"
    Write-LogInfo "Partial workspace preserved at: $global:WorkspacePath"
    Write-Host "To retry, fix the issue and run the build command again" -ForegroundColor Yellow
    Write-Host "To clean up, run: Remove-Item -Path '$global:WorkspacePath' -Recurse -Force" -ForegroundColor Yellow
    Write-Host ""
}

# T039: Memory monitoring
Write-LogInfo "Checking system resources..."
$totalRAM = [Math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$availableRAM = [Math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB / 1024, 2)

Write-Host "Total RAM: ${totalRAM}GB" -ForegroundColor Cyan
Write-Host "Available RAM: ${availableRAM}GB" -ForegroundColor Cyan

if ($availableRAM -lt 6) {
    Write-LogWarning "Low memory detected (${availableRAM}GB available)"
    Write-LogWarning "Recommended: 8GB+ RAM for Windows 11 image building"
    Write-LogWarning "Build may fail or be very slow"
    
    if (-not $Force) {
        $response = Read-Host "Continue anyway? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-LogInfo "Build cancelled by user"
            exit 0
        }
    }
}
elseif ($totalRAM -lt 8) {
    Write-LogWarning "System has ${totalRAM}GB RAM (recommended: 8GB+)"
}
else {
    Write-Host "Memory check passed (${totalRAM}GB total)" -ForegroundColor Green
}
Write-Host ""

# Setup workspace
Write-LogInfo "Setting up workspace..."
$workspaceIso = Join-Path -Path $global:WorkspacePath -ChildPath "iso"
$workspaceMount = Join-Path -Path $global:WorkspacePath -ChildPath "mount"

New-Item -Path $global:WorkspacePath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
New-Item -Path $workspaceIso -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
New-Item -Path $workspaceMount -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

Write-LogInfo "Workspace created at: $global:WorkspacePath"
Write-Host ""

try {
    # T032: Extract ISO with 7-Zip
    Write-LogInfo "Step 1/10: Extracting Windows 11 ISO..."
    Write-Host "Source: $SourceIso" -ForegroundColor Cyan
    Write-Host "Destination: $workspaceIso" -ForegroundColor Cyan
    
    $sevenZip = Get-Command "7z.exe" -ErrorAction SilentlyContinue
    if (-not $sevenZip) {
        $sevenZip = Get-Command "C:\Program Files\7-Zip\7z.exe" -ErrorAction SilentlyContinue
    }
    if (-not $sevenZip) {
        throw "7-Zip (7z.exe) not found. Install from https://www.7-zip.org/"
    }
    
    $extractArgs = @("x", "-y", "-o$workspaceIso", $SourceIso)
    $process = Start-Process -FilePath $sevenZip.Path -ArgumentList $extractArgs -Wait -NoNewWindow -PassThru
    
    if ($process.ExitCode -ne 0) {
        throw "7-Zip extraction failed with exit code: $($process.ExitCode)"
    }
    
    Write-Host "ISO extracted successfully" -ForegroundColor Green
    Write-Host ""
    
    # Verify critical files
    Write-LogInfo "Verifying ISO contents..."
    if (-not (Test-Path -Path (Join-Path -Path $workspaceIso -ChildPath "sources"))) {
        throw "sources\ directory not found in extracted ISO"
    }
    
    $wimFile = Join-Path -Path $workspaceIso -ChildPath "sources\install.wim"
    $esdFile = Join-Path -Path $workspaceIso -ChildPath "sources\install.esd"
    
    if (Test-Path -Path $wimFile) {
        $sourceWim = $wimFile
        Write-Host "Found: install.wim" -ForegroundColor Cyan
    }
    elseif (Test-Path -Path $esdFile) {
        $sourceWim = $esdFile
        Write-Host "Found: install.esd (will need conversion)" -ForegroundColor Cyan
    }
    else {
        throw "Neither install.wim nor install.esd found in sources\"
    }
    
    $wimSize = [Math]::Round((Get-Item $sourceWim).Length / 1GB, 2)
    Write-Host "WIM size: ${wimSize}GB" -ForegroundColor Cyan
    Write-Host "ISO verification complete" -ForegroundColor Green
    Write-Host ""
    
    # T033: Mount WIM with native DISM
    Write-LogInfo "Step 2/10: Mounting WIM image..."
    $imageIndex = if ($config.source.imageIndex) { $config.source.imageIndex } else { 1 }
    Write-Host "Image index: $imageIndex" -ForegroundColor Cyan
    Write-Host "Mount point: $workspaceMount" -ForegroundColor Cyan
    
    Mount-WindowsImage -ImagePath $sourceWim -Index $imageIndex -Path $workspaceMount -ErrorAction Stop | Out-Null
    Write-Host "WIM image mounted successfully" -ForegroundColor Green
    Write-Host ""
    
    # T034: Package removal operations
    Write-LogInfo "Step 3/10: Processing package removals..."
    
    if ($config.packages.removeList -and $config.packages.removeList.Count -gt 0) {
        Write-Host "Removing $($config.packages.removeList.Count) packages..." -ForegroundColor Cyan
        
        # Get installed packages
        $installedPackages = Get-AppxProvisionedPackage -Path $workspaceMount | Select-Object -ExpandProperty DisplayName
        
        foreach ($packagePattern in $config.packages.removeList) {
            $matchingPackages = $installedPackages | Where-Object { $_ -like "*$packagePattern*" }
            
            foreach ($pkg in $matchingPackages) {
                try {
                    Write-Host "  Removing: $pkg" -ForegroundColor Gray
                    Remove-AppxProvisionedPackage -Path $workspaceMount -PackageName $pkg -ErrorAction Stop | Out-Null
                    Write-Host "    Removed" -ForegroundColor Green
                }
                catch {
                    Write-LogWarning "Failed to remove $pkg : $($_.Exception.Message)"
                }
            }
        }
    }
    
    # Remove Edge if configured
    if ($config.packages.removeEdge) {
        Write-Host "Removing Microsoft Edge..." -ForegroundColor Cyan
        $edgePaths = @(
            "Program Files (x86)\Microsoft\Edge",
            "Program Files (x86)\Microsoft\EdgeUpdate"
        )
        foreach ($path in $edgePaths) {
            $fullPath = Join-Path -Path $workspaceMount -ChildPath $path
            if (Test-Path -Path $fullPath) {
                Remove-Item -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "  Edge removal attempted" -ForegroundColor Green
    }
    
    # Remove OneDrive if configured
    if ($config.packages.removeOneDrive) {
        Write-Host "Removing OneDrive..." -ForegroundColor Cyan
        $onedrivePaths = @(
            "Windows\System32\OneDriveSetup.exe",
            "Windows\SysWOW64\OneDriveSetup.exe"
        )
        foreach ($path in $onedrivePaths) {
            $fullPath = Join-Path -Path $workspaceMount -ChildPath $path
            if (Test-Path -Path $fullPath) {
                Remove-Item -Path $fullPath -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "  OneDrive removal attempted" -ForegroundColor Green
    }
    
    Write-Host "Package removal complete" -ForegroundColor Green
    Write-Host ""
    
    # T035: Driver injection (if configured)
    if ($config.drivers.inject -and $config.drivers.path) {
        Write-LogInfo "Step 4/10: Injecting drivers..."
        $driverPath = $config.drivers.path
        
        if (Test-Path -Path $driverPath) {
            Write-Host "Driver path: $driverPath" -ForegroundColor Cyan
            Add-WindowsDriver -Path $workspaceMount -Driver $driverPath -Recurse -ErrorAction Stop | Out-Null
            Write-Host "Drivers injected successfully" -ForegroundColor Green
        }
        else {
            Write-LogWarning "Driver path not found: $driverPath"
        }
    }
    else {
        Write-Host "Step 4/10: Driver injection disabled (skipping)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # T036: Generate autounattend.xml
    Write-LogInfo "Step 5/10: Generating autounattend.xml..."
    $autoUnattendPath = Join-Path -Path $workspaceIso -ChildPath "autounattend.xml"
    
    try {
        New-AutounattendXml -Config $config -OutputPath $autoUnattendPath
        Write-Host "autounattend.xml generated" -ForegroundColor Green
    }
    catch {
        Write-LogWarning "autounattend.xml generation failed: $($_.Exception.Message)"
    }
    Write-Host ""
    
    # T037: Optimization - Component cleanup
    Write-LogInfo "Step 6/10: Running component cleanup..."
    $resetBase = if ($config.optimization.resetBase) { $config.optimization.resetBase } else { $false }
    Write-Host "Reset base: $resetBase" -ForegroundColor Cyan
    
    $dismArgs = @("/Image:$workspaceMount", "/Cleanup-Image", "/StartComponentCleanup")
    if ($resetBase) {
        $dismArgs += "/ResetBase"
    }
    
    & dism.exe $dismArgs | Out-File -FilePath $logFile -Append
    Write-Host "Component cleanup complete" -ForegroundColor Green
    Write-Host ""
    
    # Commit changes and unmount WIM
    Write-LogInfo "Step 7/10: Committing changes and unmounting WIM..."
    Dismount-WindowsImage -Path $workspaceMount -Save -ErrorAction Stop | Out-Null
    Write-Host "WIM unmounted with changes committed" -ForegroundColor Green
    Write-Host ""
    
    # T040: Create bootable ISO with oscdimg
    Write-LogInfo "Step 8/10: Creating bootable ISO..."
    $outputImage = if ($config.output.imageName) { $config.output.imageName } else { "tiny11-handheld.iso" }
    $outputPath = if ($config.output.outputPath) { $config.output.outputPath } else { $outputDir }
    $outputIso = Join-Path -Path $outputPath -ChildPath $outputImage
    
    Write-Host "Output: $outputIso" -ForegroundColor Cyan
    
    # Find oscdimg
    $oscdimg = Get-Command "oscdimg.exe" -ErrorAction SilentlyContinue
    if (-not $oscdimg) {
        # Check common ADK locations
        $adkPaths = @(
            "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
            "C:\Program Files\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
        )
        foreach ($path in $adkPaths) {
            if (Test-Path -Path $path) {
                $oscdimg = Get-Command $path
                break
            }
        }
    }
    
    if (-not $oscdimg) {
        throw "oscdimg.exe not found. Install Windows ADK (Deployment Tools component)"
    }
    
    # Create ISO with UEFI boot support
    $bootData = "2#p0,e,b$workspaceIso\boot\etfsboot.com#pEF,e,b$workspaceIso\efi\microsoft\boot\efisys.bin"
    $oscdimgArgs = @(
        "-m",
        "-o",
        "-u2",
        "-udfver102",
        "-bootdata:$bootData",
        $workspaceIso,
        $outputIso
    )
    
    $process = Start-Process -FilePath $oscdimg.Path -ArgumentList $oscdimgArgs -Wait -NoNewWindow -PassThru -RedirectStandardOutput "$logFile.oscdimg.log"
    
    if ($process.ExitCode -ne 0) {
        throw "oscdimg failed with exit code: $($process.ExitCode)"
    }
    
    Write-Host "Bootable ISO created successfully" -ForegroundColor Green
    Write-Host ""
    
    # T041: Calculate ISO size and checksum
    Write-LogInfo "Step 9/10: Calculating checksum..."
    $isoSize = [Math]::Round((Get-Item $outputIso).Length / 1GB, 2)
    $isoChecksum = (Get-FileHash -Path $outputIso -Algorithm SHA256).Hash
    
    Write-Host ""
    Write-Host "====================================================================================================" -ForegroundColor Cyan
    Write-Host "BUILD COMPLETE!" -ForegroundColor Green
    Write-Host "====================================================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Output ISO: $outputIso" -ForegroundColor White
    Write-Host "ISO Size: ${isoSize}GB" -ForegroundColor White
    Write-Host "SHA256: $isoChecksum" -ForegroundColor White
    Write-Host ""
    Write-Host "Build log: $logFile" -ForegroundColor White
    Write-Host ""
    Write-Host "====================================================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-LogInfo "Build complete! (T032-T041)"
    Write-LogInfo "ISO ready for testing"
    Write-Host ""
    
    exit 0
}
catch {
    Cleanup-OnError -ErrorRecord $_
    exit 1
}

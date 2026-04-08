#Requires -Version 5.1

<#
.SYNOPSIS
    Windows platform prerequisite checker for tiny11-handheld build system.

.DESCRIPTION
    Validates that all required tools and dependencies are installed on Windows:
    - PowerShell 5.1+
    - DISM (built-in on Windows 10/11)
    - oscdimg (from Windows ADK or custom install)
    - 7-Zip command line tool
    - Administrator privileges
    - Adequate disk space (20GB+ recommended)

.NOTES
    Script: check-prereqs.ps1
    Platform: Windows only
    Requires: PowerShell 5.1+ (native Windows PowerShell or PowerShell 7+)
    Author: tiny11-handheld
    Version: 1.0.0

.EXAMPLE
    .\check-prereqs.ps1

.EXAMPLE
    .\check-prereqs.ps1 -Verbose
#>

[CmdletBinding()]
param()

# Initialize results
$script:ChecksPassed = 0
$script:ChecksFailed = 0
$script:Warnings = 0

function Write-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Message = ""
    )

    if ($Passed) {
        Write-Host "✓ " -ForegroundColor Green -NoNewline
        Write-Host "$Name" -ForegroundColor White
        if ($Message) {
            Write-Host "  $Message" -ForegroundColor Gray
        }
        $script:ChecksPassed++
    }
    else {
        Write-Host "✗ " -ForegroundColor Red -NoNewline
        Write-Host "$Name" -ForegroundColor White
        if ($Message) {
            Write-Host "  $Message" -ForegroundColor Yellow
        }
        $script:ChecksFailed++
    }
}

function Write-CheckWarning {
    param(
        [string]$Name,
        [string]$Message
    )

    Write-Host "⚠ " -ForegroundColor Yellow -NoNewline
    Write-Host "$Name" -ForegroundColor White
    if ($Message) {
        Write-Host "  $Message" -ForegroundColor Yellow
    }
    $script:Warnings++
}

Write-Host ""
Write-Host "==================================================================================================" -ForegroundColor Cyan
Write-Host "Tiny11 Handheld - Windows Prerequisites Check" -ForegroundColor Cyan
Write-Host "==================================================================================================" -ForegroundColor Cyan
Write-Host ""

# Check 1: Platform
Write-Verbose "Checking platform..."
$isWindows = $PSVersionTable.PSVersion.Major -ge 5 -or $IsWindows
Write-Check -Name "Platform: Windows" -Passed $isWindows -Message $(if ($isWindows) { "Running on Windows" } else { "This script must run on Windows" })

# Check 2: PowerShell version
Write-Verbose "Checking PowerShell version..."
$psVersion = $PSVersionTable.PSVersion
$psVersionOk = $psVersion.Major -ge 5
Write-Check -Name "PowerShell Version" -Passed $psVersionOk -Message "Version $psVersion (minimum: 5.1)"

# Check 3: Administrator privileges
Write-Verbose "Checking administrator privileges..."
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Check -Name "Administrator Privileges" -Passed $isAdmin -Message $(if ($isAdmin) { "Running as Administrator" } else { "DISM operations require Administrator privileges" })

# Check 4: DISM
Write-Verbose "Checking DISM..."
try {
    $dismPath = (Get-Command dism.exe -ErrorAction SilentlyContinue).Source
    if ($dismPath) {
        $dismVersion = (dism.exe /? 2>&1 | Select-String "Version" | Select-Object -First 1).ToString().Trim()
        Write-Check -Name "DISM (Deployment Image Servicing)" -Passed $true -Message "Found at $dismPath"
    }
    else {
        Write-Check -Name "DISM (Deployment Image Servicing)" -Passed $false -Message "dism.exe not found in PATH"
    }
}
catch {
    Write-Check -Name "DISM (Deployment Image Servicing)" -Passed $false -Message "Failed to check DISM: $($_.Exception.Message)"
}

# Check 5: oscdimg (for ISO creation)
Write-Verbose "Checking oscdimg..."
$oscdimgPath = $null
$oscdimgLocations = @(
    "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
    "C:\Program Files\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
    (Get-Command oscdimg.exe -ErrorAction SilentlyContinue).Source
)

foreach ($loc in $oscdimgLocations) {
    if ($loc -and (Test-Path -Path $loc)) {
        $oscdimgPath = $loc
        break
    }
}

if ($oscdimgPath) {
    Write-Check -Name "oscdimg (ISO Creation)" -Passed $true -Message "Found at $oscdimgPath"
}
else {
    Write-Check -Name "oscdimg (ISO Creation)" -Passed $false -Message "oscdimg.exe not found. Install Windows ADK: https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install"
}

# Check 6: 7-Zip
Write-Verbose "Checking 7-Zip..."
$7zipPath = $null
$7zipLocations = @(
    "C:\Program Files\7-Zip\7z.exe",
    "C:\Program Files (x86)\7-Zip\7z.exe",
    (Get-Command 7z.exe -ErrorAction SilentlyContinue).Source
)

foreach ($loc in $7zipLocations) {
    if ($loc -and (Test-Path -Path $loc)) {
        $7zipPath = $loc
        break
    }
}

if ($7zipPath) {
    Write-Check -Name "7-Zip" -Passed $true -Message "Found at $7zipPath"
}
else {
    Write-Check -Name "7-Zip" -Passed $false -Message "7z.exe not found. Install from: https://www.7-zip.org/download.html"
}

# Check 7: Disk space
Write-Verbose "Checking disk space..."
try {
    $drive = (Get-Location).Drive
    $freeSpaceGB = [math]::Round((Get-PSDrive -Name $drive.Name).Free / 1GB, 2)
    $hasSpace = $freeSpaceGB -ge 20

    if ($hasSpace) {
        Write-Check -Name "Disk Space" -Passed $true -Message "$freeSpaceGB GB available (minimum: 20 GB)"
    }
    else {
        Write-CheckWarning -Name "Disk Space" -Message "$freeSpaceGB GB available (recommended: 20+ GB for build operations)"
    }
}
catch {
    Write-CheckWarning -Name "Disk Space" -Message "Could not determine free space"
}

# Check 8: Memory
Write-Verbose "Checking available memory..."
try {
    $totalMemoryGB = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    $hasMemory = $totalMemoryGB -ge 8

    if ($hasMemory) {
        Write-Check -Name "Physical Memory" -Passed $true -Message "$totalMemoryGB GB total (recommended: 8+ GB)"
    }
    else {
        Write-CheckWarning -Name "Physical Memory" -Message "$totalMemoryGB GB total (recommended: 8+ GB for optimal performance)"
    }
}
catch {
    Write-CheckWarning -Name "Physical Memory" -Message "Could not determine total memory"
}

# Summary
Write-Host ""
Write-Host "==================================================================================================" -ForegroundColor Cyan
Write-Host "Prerequisites Check Summary" -ForegroundColor Cyan
Write-Host "==================================================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Passed:   " -NoNewline
Write-Host "$script:ChecksPassed" -ForegroundColor Green
Write-Host "  Failed:   " -NoNewline
Write-Host "$script:ChecksFailed" -ForegroundColor $(if ($script:ChecksFailed -eq 0) { "Green" } else { "Red" })
Write-Host "  Warnings: " -NoNewline
Write-Host "$script:Warnings" -ForegroundColor $(if ($script:Warnings -eq 0) { "Green" } else { "Yellow" })
Write-Host ""

if ($script:ChecksFailed -eq 0) {
    Write-Host "✓ All prerequisites met! Ready to build." -ForegroundColor Green
    Write-Host ""
    exit 0
}
else {
    Write-Host "✗ Some prerequisites are missing. Please install the required tools." -ForegroundColor Red
    Write-Host ""
    Write-Host "Installation Guide:" -ForegroundColor Cyan
    Write-Host "  - Windows ADK (oscdimg): https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install" -ForegroundColor Gray
    Write-Host "  - 7-Zip: https://www.7-zip.org/download.html" -ForegroundColor Gray
    Write-Host "  - Run PowerShell as Administrator for DISM operations" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

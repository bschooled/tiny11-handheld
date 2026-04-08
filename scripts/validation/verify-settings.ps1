#!/usr/bin/env pwsh
#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies that autounattend.xml settings were applied correctly.

.DESCRIPTION
    Checks registry keys that should have been set by autounattend.xml
    and reports which settings are correctly applied and which are not.

.EXAMPLE
    .\verify-settings.ps1
#>

param(
    [string]$OutputPath = 'C:\build\build-state.txt'
)

Write-Host "`n=== Verifying Windows Settings ===" -ForegroundColor Cyan
Write-Host "Checking if autounattend.xml settings were applied...`n" -ForegroundColor Gray

$errors = 0
$warnings = 0
$success = 0

function Test-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$ExpectedValue,
        [string]$Description
    )
    
    try {
        if (Test-Path "Registry::$Path") {
            $value = Get-ItemProperty -Path "Registry::$Path" -Name $Name -ErrorAction SilentlyContinue
            if ($null -ne $value) {
                $actualValue = $value.$Name
                if ($actualValue -eq $ExpectedValue) {
                    Write-Host "[✓] $Description" -ForegroundColor Green
                    Write-Host "    Registry: $Path\$Name = $actualValue" -ForegroundColor DarkGray
                    return $true
                } else {
                    Write-Host "[✗] $Description" -ForegroundColor Red
                    Write-Host "    Expected: $ExpectedValue, Got: $actualValue" -ForegroundColor Yellow
                    Write-Host "    Registry: $Path\$Name" -ForegroundColor DarkGray
                    return $false
                }
            } else {
                Write-Host "[✗] $Description" -ForegroundColor Red
                Write-Host "    Value not found: $Path\$Name" -ForegroundColor Yellow
                return $false
            }
        } else {
            Write-Host "[✗] $Description" -ForegroundColor Red
            Write-Host "    Path not found: $Path" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "[!] $Description" -ForegroundColor Magenta
        Write-Host "    Error: $_" -ForegroundColor Yellow
        return $null
    }
}

# Check Privacy Settings
Write-Host "`n--- Privacy Settings ---`n" -ForegroundColor Yellow

if (Test-RegistryValue -Path "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ExpectedValue 1 -Description "Copilot Disabled") { $script:success++ } else { $script:errors++ }

$contentDeliveryKeys = @(
    'ContentDeliveryAllowed',
    'FeatureManagementEnabled',
    'OEMPreInstalledAppsEnabled',
    'PreInstalledAppsEnabled',
    'SilentInstalledAppsEnabled',
    'SubscribedContentEnabled',
    'SystemPaneSuggestionsEnabled'
)

foreach ($key in $contentDeliveryKeys) {
    if (Test-RegistryValue -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name $key -ExpectedValue 0 -Description "App Suggestion: $key Disabled") { $script:success++ } else { $script:errors++ }
}

# Check UI Settings
Write-Host "`n--- UI Settings ---`n" -ForegroundColor Yellow

if (Test-RegistryValue -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -ExpectedValue 0 -Description "File Extensions Shown") { $script:success++ } else { $script:errors++ }

if (Test-RegistryValue -Path "HKCU\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -ExpectedValue 1 -Description "Bing Search Disabled") { $script:success++ } else { $script:errors++ }

if (Test-RegistryValue -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -ExpectedValue 1 -Description "Explorer Opens to This PC") { $script:success++ } else { $script:errors++ }

if (Test-RegistryValue -Path "HKCU\Control Panel\Accessibility\StickyKeys" -Name "Flags" -ExpectedValue "10" -Description "Sticky Keys Disabled") { $script:success++ } else { $script:errors++ }

# Check Security Settings  
Write-Host "`n--- Security Settings (System-Wide) ---`n" -ForegroundColor Yellow

if (Test-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -ExpectedValue "Off" -Description "SmartScreen Disabled") { $script:success++ } else { $script:errors++ }

if (Test-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -ExpectedValue 0 -Description "VBS/HVCI Disabled") { $script:success++ } else { $script:errors++ }

if (Test-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\BitLocker" -Name "PreventDeviceEncryption" -ExpectedValue 1 -Description "Device Encryption Prevented") { $script:success++ } else { $script:errors++ }

# Check Performance Settings
Write-Host "`n--- Performance Settings ---`n" -ForegroundColor Yellow

if (Test-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -ExpectedValue 1 -Description "Long Paths Enabled") { $script:success++ } else { $script:errors++ }

if (Test-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -ExpectedValue 0 -Description "Fast Startup Disabled") { $script:success++ } else { $script:errors++ }

if (Test-RegistryValue -Path "HKLM\Software\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -ExpectedValue 0 -Description "Widgets Disabled") { $script:success++ } else { $script:errors++ }

if (Test-RegistryValue -Path "HKLM\Software\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -ExpectedValue 1 -Description "Consumer Features Disabled") { $script:success++ } else { $script:errors++ }

# Check Log Files
Write-Host "`n--- Installation Logs ---`n" -ForegroundColor Yellow

$logFiles = @(
    "C:\Windows\Setup\Scripts\Specialize.log",
    "C:\Windows\Setup\Scripts\DefaultUser.log",
    "C:\Windows\Setup\Scripts\FirstLogon.log",
    "$env:TEMP\UserOnce.log"
)

foreach ($logFile in $logFiles) {
    if (Test-Path $logFile) {
        Write-Host "[✓] Log file exists: $logFile" -ForegroundColor Green
        $script:success++
        
        # Show last few lines
        $lastLines = Get-Content $logFile -Tail 5 -ErrorAction SilentlyContinue
        if ($lastLines) {
            Write-Host "    Last 5 lines:" -ForegroundColor DarkGray
            $lastLines | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        }
    } else {
        Write-Host "[✗] Log file missing: $logFile" -ForegroundColor Red
        $script:warnings++
    }
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "✓ Success: $success" -ForegroundColor Green
Write-Host "✗ Failed:  $errors" -ForegroundColor Red
Write-Host "! Warnings: $warnings" -ForegroundColor Yellow

# Persist results to disk for post-build inspection
try {
    $outDir = Split-Path -Parent $OutputPath
    if ($outDir) {
        New-Item -Path $outDir -ItemType Directory -Force | Out-Null
    }

    $summary = @()
    $summary += "Success=$success"
    $summary += "Failed=$errors"
    $summary += "Warnings=$warnings"
    $summary += "Status=" + ($(if ($errors -gt 0) { 'Failed' } else { 'Passed' }))

    $summary | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Host "Saved verification summary to $OutputPath" -ForegroundColor Green
}
catch {
    Write-Host "[WARN] Failed to write verification summary: $_" -ForegroundColor Yellow
}

if ($errors -gt 0) {
    Write-Host "`nSome settings were not applied correctly." -ForegroundColor Red
    Write-Host "This could be due to:" -ForegroundColor Yellow
    Write-Host "  1. Scripts failing during Windows setup" -ForegroundColor Gray
    Write-Host "  2. Windows overriding settings with group policies" -ForegroundColor Gray
    Write-Host "  3. User profile not properly created from default template" -ForegroundColor Gray
    Write-Host "`nCheck the log files above for details.`n" -ForegroundColor Yellow
} else {
    Write-Host "`nAll settings applied successfully!`n" -ForegroundColor Green
}

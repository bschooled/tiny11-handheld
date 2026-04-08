#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Generate autounattend.xml from JSON configuration.

.PARAMETER ConfigPath
    Path to JSON configuration file.

.PARAMETER OutputPath
    Path where autounattend.xml will be created.

.PARAMETER ProjectRoot
    Root directory of the project.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot
)

# Import modules
Import-Module "$ProjectRoot/modules/Logger.psm1"
Import-Module "$ProjectRoot/modules/Autounattend.psm1"

# Load JSON configuration
$configJson = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
$config = @{}

# Copy all sections from JSON to hashtable
if ($configJson.unattended) {
    $config['unattended'] = @{}
    $configJson.unattended.PSObject.Properties | ForEach-Object {
        if ($_.Name -eq 'userAccount') {
            $config['unattended']['userAccount'] = @{
                username = $_.Value.username
                password = $_.Value.password
                group = $_.Value.group
            }
        } else {
            $config['unattended'][$_.Name] = $_.Value
        }
    }
}

# Support top-level settings
if ($configJson.locale) { $config['locale'] = $configJson.locale }
if ($configJson.timezone) { $config['timezone'] = $configJson.timezone }
if ($configJson.keyboard) { $config['keyboard'] = $configJson.keyboard }

if ($configJson.userAccount) {
    $config['userAccount'] = @{
        username = $configJson.userAccount.username
        password = $configJson.userAccount.password
        group = $configJson.userAccount.group
    }
}

# Copy configuration sections
if ($configJson.features) {
    $config['features'] = @{}
    $configJson.features.PSObject.Properties | ForEach-Object { $config['features'][$_.Name] = $_.Value }
}
if ($configJson.privacy) {
    $config['privacy'] = @{}
    $configJson.privacy.PSObject.Properties | ForEach-Object { $config['privacy'][$_.Name] = $_.Value }
}
if ($configJson.security) {
    $config['security'] = @{}
    $configJson.security.PSObject.Properties | ForEach-Object { $config['security'][$_.Name] = $_.Value }
}
if ($configJson.ui) {
    $config['ui'] = @{}
    $configJson.ui.PSObject.Properties | ForEach-Object { $config['ui'][$_.Name] = $_.Value }
}
if ($configJson.performance) {
    $config['performance'] = @{}
    $configJson.performance.PSObject.Properties | ForEach-Object { $config['performance'][$_.Name] = $_.Value }
}
if ($configJson.development) {
    $config['development'] = @{}
    $configJson.development.PSObject.Properties | ForEach-Object { $config['development'][$_.Name] = $_.Value }
}
if ($configJson.browser) {
    $config['browser'] = @{}
    $configJson.browser.PSObject.Properties | ForEach-Object { $config['browser'][$_.Name] = $_.Value }
}

# Scripts: load optional verification or custom run-once scripts
if ($configJson.scripts) {
    $config['scripts'] = @{}

    # Built-in build verification script (writes to C:\build\build-state.txt)
    if ($configJson.scripts.buildVerification -eq $true) {
        $verifyPath = Join-Path $ProjectRoot "scripts/validation/verify-settings.ps1"
        if (-not (Test-Path $verifyPath)) {
            throw "Verification script not found at expected path: $verifyPath"
        }

        $config['scripts']['buildVerification'] = @{
            path    = "C:\\Windows\\Setup\\Scripts\\BuildVerify.ps1"
            content = Get-Content -Path $verifyPath -Raw
        }
    }

    # Custom user-once script provided by preset
    if ($configJson.scripts.runOnce) {
        $userOncePath = $configJson.scripts.runOnce
        if (-not [System.IO.Path]::IsPathRooted($userOncePath)) {
            $userOncePath = Join-Path (Split-Path -Parent $ConfigPath) $userOncePath
        }

        if (-not (Test-Path $userOncePath)) {
            throw "Custom runOnce script not found: $userOncePath"
        }

        $config['scripts']['customUserOnce'] = @{
            path    = "C:\\Windows\\Setup\\Scripts\\CustomUserOnce.ps1"
            content = Get-Content -Path $userOncePath -Raw
        }
    }
}

# Generate autounattend.xml
New-AutounattendXml -Config $config -OutputPath $OutputPath

exit $LASTEXITCODE

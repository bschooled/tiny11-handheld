#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Standalone configuration loader for bash build script.

.DESCRIPTION
    Loads and validates configuration without complex logging dependencies.
    Outputs JSON to stdout for bash consumption.
#>

param(
    [string]$ProjectRoot,
    [string]$ConfigPath,
    [string]$PresetPath,
    [string]$SchemaPath
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

Write-Host "==> Loading configuration..." -ForegroundColor Cyan

# Simple JSON loading without logger
function Load-JsonFile {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }
    
    Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable
}

# Simple merge (shallow)
function Merge-Config {
    param([hashtable]$Base, [hashtable]$Override)
    
    $result = $Base.Clone()
    foreach ($key in $Override.Keys) {
        $result[$key] = $Override[$key]
    }
    return $result
}

# Load preset if specified
$config = @{}
if ($PresetPath) {
    Write-Host "  Loading preset: $PresetPath" -ForegroundColor Gray
    $config = Load-JsonFile -Path $PresetPath
}

# Load and merge user config if specified
if ($ConfigPath) {
    Write-Host "  Loading config: $ConfigPath" -ForegroundColor Gray
    $userConfig = Load-JsonFile -Path $ConfigPath
    if ($config.Count -gt 0) {
        $config = Merge-Config -Base $config -Override $userConfig
    } else {
        $config = $userConfig
    }
}

if ($config.Count -eq 0) {
    throw "No configuration loaded"
}

# Validate schema if config path provided
if ($ConfigPath -and $SchemaPath -and (Test-Path $SchemaPath)) {
    Write-Host "  Validating schema..." -ForegroundColor Gray
    $configJson = Get-Content $ConfigPath -Raw
    $isValid = Test-Json -Json $configJson -SchemaFile $SchemaPath
    if (-not $isValid) {
        throw "Schema validation failed"
    }
}

# Resolve paths
function Resolve-PathIfRelative {
    param([string]$Path, [string]$Root)
    
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    if ($Path -match '^([A-Za-z]:|\/)') { return $Path }
    
    $resolved = Join-Path $Root $Path
    if (Test-Path $resolved) {
        return (Resolve-Path $resolved).Path
    }
    return $resolved
}

Write-Host "  Resolving paths..." -ForegroundColor Gray

if ($config.source -and $config.source.isoPath) {
    $config.source.isoPath = Resolve-PathIfRelative $config.source.isoPath $ProjectRoot
}
if ($config.output -and $config.output.outputPath) {
    $config.output.outputPath = Resolve-PathIfRelative $config.output.outputPath $ProjectRoot
}
if ($config.drivers -and $config.drivers.driverPath) {
    $config.drivers.driverPath = Resolve-PathIfRelative $config.drivers.driverPath $ProjectRoot
}
if ($config.updates -and $config.updates.updatePath) {
    $config.updates.updatePath = Resolve-PathIfRelative $config.updates.updatePath $ProjectRoot
}
if ($config.oem -and $config.oem.oemPath) {
    $config.oem.oemPath = Resolve-PathIfRelative $config.oem.oemPath $ProjectRoot
}

# Resolve OEM copy sources (if provided)
if ($config.oem -and $config.oem.copy) {
    $resolvedCopy = @()
    foreach ($item in @($config.oem.copy)) {
        if (-not $item) { continue }
        if ($item.source) {
            $item.source = Resolve-PathIfRelative $item.source $ProjectRoot
        }
        $resolvedCopy += $item
    }
    $config.oem.copy = $resolvedCopy
}

# Resolve runOnce script paths (string or array)
if ($config.scripts -and $config.scripts.runOnce) {
    $resolvedRunOnce = @()
    foreach ($entry in @($config.scripts.runOnce)) {
        if (-not $entry) { continue }
        if ($entry -is [string]) {
            $resolvedRunOnce += (Resolve-PathIfRelative $entry $ProjectRoot)
        }
    }
    $config.scripts.runOnce = $resolvedRunOnce
}

Write-Host "==> Configuration loaded successfully" -ForegroundColor Green
Write-Host ""

# Output JSON to stdout
$config | ConvertTo-Json -Depth 10 -Compress

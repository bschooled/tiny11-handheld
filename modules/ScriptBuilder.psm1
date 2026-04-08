#Requires -Version 7.0

<#
.SYNOPSIS
    Helper functions for generating PowerShell scripts in autounattend.xml.

.DESCRIPTION
    Provides utility functions to build script sections for different installation phases.

.NOTES
    Module: ScriptBuilder.psm1
    Requires: PowerShell 7.0+
    Author: tiny11-handheld
    Version: 1.0.0
#>

<#
.SYNOPSIS
    Escapes XML special characters in script content.

.PARAMETER Content
    Script content to escape.

.OUTPUTS
    System.String
    Escaped XML content.
#>
function ConvertTo-XmlSafeString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    return $Content -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&apos;'
}

<#
.SYNOPSIS
    Generates a PowerShell script command entry for registry modification.

.PARAMETER Path
    Registry path.

.PARAMETER Name
    Value name.

.PARAMETER Type
    Registry value type (REG_DWORD, REG_SZ, etc).

.PARAMETER Data
    Value data.

.PARAMETER RootKey
    Root registry key (HKLM, HKCU, HKU, etc).

.OUTPUTS
    System.String
    Registry command scriptblock.
#>
function New-RegistryCommand {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Data,

        [Parameter(Mandatory = $false)]
        [string]$RootKey = "HKLM"
    )

    $fullPath = "$RootKey\$Path"
    return "reg.exe add `"$fullPath`" /v `"$Name`" /t $Type /d $Data /f;"
}

<#
.SYNOPSIS
    Generates scriptblock for bloatware removal.

.PARAMETER Packages
    Array of AppxPackage names to remove.

.PARAMETER Capabilities
    Array of Windows capabilities to remove.

.PARAMETER Features
    Array of Windows features to disable.

.OUTPUTS
    System.String
    PowerShell scriptblock for bloatware removal.
#>
function New-BloatwareRemovalScript {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$Packages = @(),

        [Parameter(Mandatory = $false)]
        [string[]]$Capabilities = @(),

        [Parameter(Mandatory = $false)]
        [string[]]$Features = @()
    )

    $script = @()

    if ($Packages.Count -gt 0) {
        $packageList = ($Packages | ForEach-Object { "'$_'" }) -join ";\`n`t"
        $script += @"
{
    Get-Content -LiteralPath 'C:\Windows\Setup\Scripts\RemovePackages.ps1' -Raw | Invoke-Expression;
}
"@
    }

    if ($Capabilities.Count -gt 0) {
        $script += @"
{
    Get-Content -LiteralPath 'C:\Windows\Setup\Scripts\RemoveCapabilities.ps1' -Raw | Invoke-Expression;
}
"@
    }

    if ($Features.Count -gt 0) {
        $script += @"
{
    Get-Content -LiteralPath 'C:\Windows\Setup\Scripts\RemoveFeatures.ps1' -Raw | Invoke-Expression;
}
"@
    }

    return ($script -join ";\`n`t")
}

# Export module members
Export-ModuleMember -Function ConvertTo-XmlSafeString, New-RegistryCommand, New-BloatwareRemovalScript

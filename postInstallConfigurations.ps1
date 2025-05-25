param(
    [string]$configurationPath = "$PSScriptRoot\configurations",
    [string]$configJsonPath = "$PSScriptRoot\configurations.json"
)
Start-Transcript -Path "$PSScriptRoot\postInstallConfigurations.log" -Append -NoClobber
function Set-Background() {
    # Define the path to the new wallpaper
    $wallpaperPath = "$($PWD.path)\configurations\tiny11.jpg"
    [string]$wallpaperPath = Write-Output $wallpaperPath

    # Load user32.dll and define the SystemParametersInfo function
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class User32 {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

    # Set the wallpaper
    $SPI_SETDESKWALLPAPER = 0x0014
    $SPIF_UPDATEINIFILE = 0x01
    $SPIF_SENDCHANGE = 0x02

    # Combine the flags using PowerShell's -bor operator
    $flags = $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE

    # Call the SystemParametersInfo function
    [User32]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $wallpaperPath, $flags)
}

function Copy-ConfigurationFiles($configurationPath,$configJsonPath){
    $configs = Get-Content $configJsonPath | ConvertFrom-Json
    foreach ($config in $configs.PSObject.Properties.Name) {

        Write-Host "Processing configuration: $config"
        
        $reg = $configs.$config.regFile
        $configFiles = $configs.$config.configFiles | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

        if([string]::IsNullOrEmpty($reg) -eq $false){
            Write-Host "Registry file: $reg"
            # Check if the registry file exists
            $regPath = Join-Path -Path $PSScriptRoot -ChildPath $reg
            if (Test-Path -Path $regPath) {
                Write-Host "Registry file found: $regPath"
                # Import the registry file
                Write-Host "Importing registry file: $regPath"
                Start-Process reg.exe -ArgumentList "import `"$regPath`"" -NoNewWindow -Wait
            } else {
                Write-Warning "Registry file $regPath does not exist."
            }
        }

        foreach ($file in $configFiles) {
            $destination = $configs."$config".configFiles."$file" | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $source = $configs."$config".configFiles."$file"."$destination"

            if($destination -match '\$env:USERNAME'){
                $destination = $destination -replace '\$env:USERNAME', "$(Write-Output $env:USERNAME)"
            }

            Write-Host "Processing configuration file: $file`nSource: $source`nDestination: $destination"

            $filePath = Join-Path -Path $PSScriptRoot -ChildPath $source
            if (Test-Path -Path $filePath) {
                Write-Host "Configuration file found: $filePath"
                # Copy the file to the destination
                if(Test-Path -Path $destination){
                    Write-Host "Destination path already exists: $destination"
                } else {
                    Write-Host "Creating destination path: $destination"
                    New-Item -ItemType Directory -Path $destination -Force | Out-Null
                }
                Copy-Item -Path $filePath -Destination $destination -Force
            } else {
                Write-Warning "Configuration file $filePath does not exist."
            }
        }
    }
}

# Copy configuration files and import registry settings
Copy-ConfigurationFiles -configurationPath $configurationPath -configJsonPath $configJsonPath
Set-Background

Stop-Transcript

Write-Host "Going for reboot..."
Shutdown.exe /F /R /T 15
exit;
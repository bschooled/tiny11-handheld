[CmdletBinding()]
param (
    [Parameter()]
    [string]$DownloadPath = "C:\packages",
    [Parameter()]
    [switch]$CheckGraphics
)

    #Filenames and URLs for the downloads
$Global:downloadHash = @{
    "7zr" = "https://7-zip.org/a/7zr.exe"
    "WinGet" = "https://github.com/microsoft/winget-cli/releases/download/v1.10.340/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    "AMD Software" = "https://ftp.nluug.nl/pub/games/PC/guru3d/amd/2025/[Guru3D]-whql-amd-software-adrenalin-edition-25.3.1-win10-win11-march-rdna.exe"
    "Intel Arc" = "https://ftp.nluug.nl/pub/games/PC/guru3d/intel/[Guru3D]-Intel-graphics-DCH.exe"
    "Handheld Companion" = "https://github.com/Valkirie/HandheldCompanion/releases/download/0.22.2.8/HandheldCompanion-0.22.2.8.exe"
    "Autologon" = "https://download.sysinternals.com/files/AutoLogon.zip"
}
$Global:chocoPackages= @(
    "steam",
    "memreduct"
)
$Global:wingetPackages = @(
    "IridiumIO.CompactGUI",
    "git.git"
)
$Global:vendorHash = @{
    "AMD Software" = 1002
    "Intel Arc" = 8086
}

function Optimize-Memory(){

    [hashtable]$settings = @{
        "ApplicationLaunchPrefetching" = $true
        "ApplicationPreLaunch" = $true
        "MaxOperationAPIFiles" = 8192
        "MemoryCompression" = $true
        "OperationAPI" = $true
        "PageCombining" = $true
    }
    #set powercfg 
    powercfg /h /type reduced

    foreach ($setting in $settings.Keys) {
        if ($($(Get-MMAgent).$setting) -eq $true -and $setting -notlike "MaxOperationAPIFiles") {
            Write-Host "Enabling $setting..."
            Enable-MMAgent "-$setting"
        }
        elseif ($setting -like "MaxOperationAPIFiles" -and $($(Get-MMAgent).$setting) -lt 8192) {
            Write-Host "Setting $setting to $($settings[$setting])..."
            Set-MMAgent "-$setting" $settings[$setting]
        } 
        else {
            Write-Host "No changes needed for $setting."
        }
    }
}

#download setup
function Download-Packages($DownloadPath,$downloadHash){

    If(-not $(Test-Path $DownloadPath)){
        New-Item -Path $DownloadPath -ItemType Directory | Out-Null
    } 
    $downloadHash.GetEnumerator() | ForEach-Object {
        $extension = $_.Value.Split("/")[-1].Split(".")[-1]
        $fileName = $_.Key + ".$extension"
        $filePath = Join-Path -Path $DownloadPath -ChildPath $fileName
        if (-not (Test-Path $filePath)) {
            Write-Host "Downloading $($_.Value) to $filePath"
            Start-BitsTransfer -Source $_.Value -Destination $filePath -DisplayName $fileName -TransferType Download -ErrorAction Stop
        } else {
            Write-Host "$fileName already exists, skipping download."
        }
    }
}

function Extract-Packages($DownloadPath,$packageName){
    $extractPath = "$($DownloadPath)\extracted\$packageName"
    If(-not $(Test-Path $extractPath)){
        New-Item -Path $extractPath -ItemType Directory | Out-Null
    } 
    #Extract the files using 7zr
    & "$downloadPath\7zr.exe" x "$downloadPath\$packageName.exe" -o"$extractPath" -y
}

function Install-Packages($DownloadPath,$packageName,[bool]$chocoInstall,[bool]$wingetInstall){
    if(-not $(Get-Command choco -ErrorAction SilentlyContinue) -and $chocoInstall -eq $true){
        Write-Host "Chocolatey is not installed. Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    }

    if ($chocoInstall -eq $true) {
        if([string]::IsNullOrEmpty("$(choco list $packageName | Select-String -Pattern '0')")){
            Write-Host "Installing $packageName using Chocolatey"
            choco install $packageName -y --no-prompt
        }
        else{
            Write-Host "$packageName is already installed, skipping installation."
        }
    }
    elseif(-not $(Get-Command winget -ErrorAction SilentlyContinue) -and $wingetInstall -eq $true) {
        if([string]::IsNullOrEmpty("$(winget list $packageName | Select-String -Pattern 'No installed packages found')")){
            Write-Host "Installing $packageName using winget"
            winget install --id $packageName --silent --accept-source-agreements --accept-package-agreements --source winget
        }
        else{
            Write-Host "$packageName is already installed, skipping installation."
        }
    }
    else{
        if($packageName -like "AMD Software"){
            #Install the packages using the extracted files
            Write-Host "Extracting $packageName"
            Extract-Packages -DownloadPath $DownloadPath -packageName $packageName

            Write-Host "Install AMD Package"
            Start-Process -FilePath "$downloadPath\extracted\$packageName\setup.exe" -ArgumentList "-INSTALL -OUTPUT screen" -Wait
        }
        elseif ($packageName -like "7zr" -or $packageName -like "AutoLogon"){
            Write-Host "$packageName doesn't need installed, skipping installation."
        }
        elseif ($packageName -like "Intel Arc"){
            Write-Host "Installing Intel Graphics Driver"
            Start-Process -FilePath "$downloadPath\$packageName.exe" -ArgumentList '-p' -Wait
        }
        elseif ($packageName -like "WinGet") {
            Write-Host "Installing WinGet"
            Add-AppxPackage -Path "$downloadPath\$packageName.msixbundle" -ForceUpdateFromAnyVersion -ErrorAction Stop
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
        }
        else{
            try {
                Write-Host "Attempting to install $downloadPath\$packageName.exe"
                Start-Process -FilePath "$downloadPath\$packageName.exe" -ArgumentList "/SILENT /NORESTART" -Wait
            }
            catch {
                Write-Host "Failed to install with /SILENT switch, will try with /S"
                Start-Process -FilePath "$downloadPath\$packageName.exe" -ArgumentList "/S" -Wait
            }
        }
    }
}

function CheckVenID($packageName){
    $venID = $(Get-WmiObject Win32_VideoController | select -ExpandProperty PNPDeviceID) -match "VEN_\d{4}" | Out-Null; $matches[0]

    if ($venID -eq $Global:vendorHash[$packageName]) {
        Write-Host "$packageName matches $venID."
        return $true

    } else {
        Write-Host "$packageName is not from the correct vendor."
        return $false  
    }
}

# Run optimize memory function
Optimize-Memory

# Check if the graphics packages are needed
if($CheckGraphics -eq $true) {
    foreach ($package in $Global:vendorHash.Keys) {   
        if($package -like "*AMD*" -or $package -like "*Intel*"){
            Write-Host "Checking vendor ID for $package..."
            if (-not $(CheckVenID($package))) {
                $Global:downloadHash.Remove($package)
                Write-Host "Removing $package from download list."
            }     
        }
    }
}

# Download the exe packages
Download-Packages -DownloadPath $DownloadPath -downloadHash $Global:downloadHash

foreach ($package in $downloadHash.Keys){
    $installedPackage = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like $package }
    if([string]::IsNullOrEmpty("$installedPackage")){
        Write-Host "$package is not installed, installing..."
        Install-Packages -DownloadPath $DownloadPath -packageName $package -chocoInstall $false
    }
    else{
        Write-Host "$package is already installed, skipping installation."
    }
}
 
foreach ($package in $Global:chocoPackages){
    Install-Packages -DownloadPath $DownloadPath -packageName $package -chocoInstall $true
}

foreach ($package in $Global:wingetPackages){
    Install-Packages -DownloadPath $DownloadPath -packageName $package -chocoInstall $false -wingetInstall $true
}
exit;

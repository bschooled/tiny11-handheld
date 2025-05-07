[CmdletBinding()]
param (
    [Parameter()]
    [string]$DownloadPath = "C:\packages",
    [Parameter()]
    [switch]$CheckGraphics,
    [Parameter()]
    [switch]$SkipInstall = $false
)

$ErrorActionPreference = 'Continue'

Start-Transcript -Path "$PSScriptRoot\postInstall.log" -Append -NoClobber -Force

#import packages.json
Write-Host "Importing $PSScriptRoot\packages.json..."
$packages = Get-Content "$PSScriptRoot\packages.json" | ConvertFrom-Json

if($(Get-Module PowerShellForGitHub -ListAvailable)){
    Write-Host "PowerShellForGitHub module is already installed."
}
else{
    Install-PackageProvider -Name NuGet -Scope CurrentUser -Force -ErrorAction Stop -Confirm:$false
    Write-Host "Installing PowerShellForGitHub module..."
    Install-Module -Name PowerShellForGitHub -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    Import-Module PowerShellForGitHub -Force -ErrorAction Stop
    Set-GitHubConfiguration -DisableTelemetry
}



$Global:vendorHash = @{
    "AMD Software" = '1002'
    "Intel Arc" = '8086'
    "Nvidia" = '10DE'
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
        $setting = $setting.ToString()
        if ($($(Get-MMAgent).$setting) -eq $true -and $setting -notlike "MaxOperationAPIFiles") {
            Write-Host "Enabling $setting..."
            Invoke-Expression -Command "Enable-MMAgent -$setting -ErrorAction SilentlyContinue"
        }
        elseif ($setting -like "MaxOperationAPIFiles" -and $($(Get-MMAgent).$setting) -lt 8192) {
            Write-Host "Setting $setting to $($settings[$setting])..."
            Invoke-Expression -Command "Set-MMAgent -$setting $($settings[$setting]) -ErrorAction SilentlyContinue"
        } 
        else {
            Write-Host "No changes needed for $setting."
        }
    }
}

#download setup
function Download-Packages($DownloadPath,$package,$packageProperties,[bool]$githubDownload){


    If(-not $(Test-Path $DownloadPath)){
        Write-Host "Creating $DownloadPath directory..."
        New-Item -Path $DownloadPath -ItemType Directory | Out-Null
    } 

    if ($githubDownload -eq $true) {
        Write-Host "`tGithub download is true, downloading $package from GitHub."
        $extension = $package.Split(".")[-1]
        Write-Host "`tExtension is $extension"
        $repoName = $package -replace "\.$extension$", ""
        $filePath = Join-Path -Path $DownloadPath -ChildPath $package
        Write-host "`tFile Path is $filePath"
        Write-Host "`tRepo Name is $repoName and owner is $($packageProperties.author)"
        if (-not (Test-Path $filePath -ErrorAction SilentlyContinue)) {
            $downloadURL = $(Get-GitHubRelease -RepositoryName $repoName -OwnerName $packageProperties.author).assets.browser_download_url
            if($downloadURL.Count -gt 1 -and -not [string]::IsNullOrEmpty("$($downloadURL -match 'amd64')")){
                Write-Host "`tMultiple download URLs found, pattern match for amd64, setting to matching URL"
                $downloadURL = $downloadURL -match 'amd64'
            }
            else{
                Write-Host "`tMultiple download URL found, setting to first URL"
                $downloadURL = $downloadURL[0]
            }
            Write-Host "`tDownload URL is $downloadURL"
            Write-Host "`tDownloading $downloadURL to $filePath"
            Start-BitsTransfer -Source $downloadURL -Destination $filePath -DisplayName $repoName -TransferType Download -ErrorAction Stop
        } 
        else {
            Write-Host "`t$package already exists, skipping download..."
        } 
    }
    else{
        Write-Host "Github download is false, downloading $package from URL."
        $filePath = Join-Path -Path $DownloadPath -ChildPath $package
        Write-Host "`tFile Path is $filePath"
        if (-not (Test-Path $filePath -ErrorAction SilentlyContinue)) {
            Write-Host "`tDownloading $($packageProperties.url) to $filePath"
            Start-BitsTransfer -Source $packageProperties.url -Destination $filePath -DisplayName $package -TransferType Download -ErrorAction Stop
        } else {
            Write-Host "`t$package already exists, skipping download..."
        }
    }
}

function Extract-Packages($DownloadPath,$package,$packageName){
    Write-Host "`tExtracting $package..."
    $extractPath = "$($DownloadPath)\extracted\$packageName"
    Write-Host `t"Extracting to $extractPath"
    If(-not $(Test-Path $extractPath -ErrorAction SilentlyContinue)){
        Write-Host "`tCreating $extractPath directory..."
        New-Item -Path $extractPath -ItemType Directory | Out-Null
    } 
    #Extract the files using 7z
    7z.exe x "$downloadPath\$package" -o"$extractPath" -y
}

function Check-WingetInstall() {
    if($(Get-Command winget.exe -ErrorAction SilentlyContinue)){
        Write-Host "WinGet is already on path"
        $wingetPath = 'winget.exe'
    }
    else {
        $wingetPath = $(Get-ChildItem "C:\Program Files\WindowsApps" -Recurse -Include "winget.exe" -ErrorAction SilentlyContinue| select -First 1).FullName

        if([string]::IsNullOrEmpty("$wingetPath")){
            $wingetPath = $(Get-ChildItem "C:\Users\$($env:USERNAME)\AppData\Local\Microsoft\WindowsApps" -Recurse -Include "winget.exe" -ErrorAction SilentlyContinue | select -First 1).FullName
        }        <# Action when all if and elseif conditions are false #>
    }
    Write-Host "Final winget path is $wingetPath"
    return $wingetPath
}

function Install-ChocoPackages($package, $packageProperties) {

    if([string]::IsNullOrEmpty("$(choco list $package | Select-String -Pattern '1')")){
        if($null -ne $packageProperties.version){
            Write-Host "`tInstalling $package using Chocolatey"
            choco install $package --yes --no-prompt --accept-package-agreements --accept-source-agreements --version $packageProperties.version
        }
        else{
            Write-Host "`tInstalling $package using Chocolatey"
            choco install $package --yes --no-prompt --accept-package-agreements --accept-source-agreements
        }
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    }
    else{
        Write-Host "`t$package is already installed, skipping installation."
    }
}

function Install-Dependencies($package, $packageProperties, $packageFull) {
    if($package -like "choco"){
        if($(Get-Command choco.exe -ErrorAction SilentlyContinue)){
            Write-Host "Chocolatey is already installed, skipping installation."
        }
        else{
            Write-Host "Chocolatey is not installed. Installing Chocolatey..."
            Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
            iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
        }
    }
    elseif($packageProperties.url -like "choco"){
        $packageProperties = $packageFull.chocoPackages.$package
        Install-ChocoPackages -package $package -packageProperties $packageProperties
    }
    elseif($packageProperties.url -like "winget"){
        $packageProperties = $packageFull.winget.$package
        Install-WingetPackages -package $package -packageProperties $packageProperties
    }
    elseif($packageProperties.url -like "exes"){
        $packageProperties = $packageFull.exes.$package
        Download-Packages -DownloadPath $DownloadPath -package $package -packageProperties $packageProperties -githubDownload $false
        Install-Packages -DownloadPath $DownloadPath -package $package -packageProperties $packageProperties
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
}

function Install-WingetPackages($package, $packageProperties) {
    $wingetStatus = Check-WingetInstall

    if($wingetStatus -eq "winget.exe"){
        Write-Host "Installing $package using winget on path"
        winget.exe install --id $package --silent --accept-source-agreements --accept-package-agreements --source winget
    }
    else{
        Write-Host "Installing $package using winget with direct executable path"
        & $wingetStatus install --id $package --silent --accept-source-agreements --accept-package-agreements --source winget
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
}

function Install-Packages($DownloadPath,$package,$packageProperties){
    $extension = $package.Split(".")[-1]
    $packageName = $package -replace "\.$extension$", ""

    if($packageName -like "AMDSoftware"){
        #Install the packages using the extracted files
        Write-Host "Extracting $package"
        Extract-Packages -DownloadPath $DownloadPath -packageName $packageName -package $package

        Write-Host "Install AMD Package"
        Start-Process -FilePath "$downloadPath\extracted\$packageName\setup.exe" -ArgumentList "-INSTALL -OUTPUT screen" -Wait
    }
    elseif ($packageName -like "Intel Arc"){
        Write-Host "Installing Intel Graphics Driver"
        Start-Process -FilePath "$downloadPath\$package" -ArgumentList '-p' -Wait
    }
    elseif ($extension -like "zip"){
        Write-Host "Installing $package using 7z"
        Extract-Packages -DownloadPath $DownloadPath -packageName $packageName -package $package
        $exeFile = Get-ChildItem "$downloadPath\extracted\$packageName\setup.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 | select -ExpandProperty Name
        if ($null -ne $exeFile) {
            Write-Host "No setup executable found in the extracted files, trying for .msi file."
            $exeFile = Get-ChildItem "$downloadPath\extracted\$packageName\setup.msi" -ErrorAction SilentlyContinue | Select-Object -First 1 | select -ExpandProperty Name
        }

        if($null -eq $exeFile) {
            Write-Host "No setup executable found in the extracted files, skipping installation."
        }
        else{
            try {
                Write-Host "Attempting to install $downloadPath\$package"
                Start-Process -FilePath "$downloadPath\extracted\$packageName\$exeFile" -ArgumentList "/SILENT /NORESTART" -Wait
            }
            catch {
                Write-Host "Failed to install with /SILENT switch, will try with /S"
                Start-Process -FilePath "$downloadPath\extracted\$packageName\$exeFile" -ArgumentList "/S" -Wait
            }
        }

    }
    elseif ($extension -like "msxibundle"){
        Write-Host "Installing $package using Add-AppxPackage"
        Add-AppxPackage -Path "$downloadPath\$package" -ForceApplicationShutdown -ForceUpdateFromAnyVersion -Register
    }
    else{
        try {
            Write-Host "Attempting to install $downloadPath\$package"
            Start-Process -FilePath "$downloadPath\$package" -ArgumentList "/SILENT /NORESTART" -Wait
        }
        catch {
            Write-Host "Failed to install with /SILENT switch, will try with /S"
            Start-Process -FilePath "$downloadPath\$package" -ArgumentList "/S" -Wait
        }
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
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

$dependencies = $packages.dependencies | Get-Member -MemberType NoteProperty | select -ExpandProperty Name
# Custom sort function to ensure choco is installed first
$sortedNames = $dependencies| Sort-Object { 
    if ($_ -eq "choco") { 
        return -1 
    } else { 
        return 1 
    }
}
$dependencies = $sortedNames

$exes = $packages.exes | Get-Member -MemberType NoteProperty | select -ExpandProperty Name
$github = $packages.github | Get-Member -MemberType NoteProperty | select -ExpandProperty Name
$zip = $packages.zip | Get-Member -MemberType NoteProperty | select -ExpandProperty Name
$winget = $packages.winget | Get-Member -MemberType NoteProperty | select -ExpandProperty Name
$choco = $packages.chocoPackages | Get-Member -MemberType NoteProperty | select -ExpandProperty Name

#first install dependencies
Write-Host "Begin installation of dependencies..."
foreach ($package in $dependencies) {
    Write-Host "Dependency is $package"
    $packageProperties = $packages.dependencies.$package
    Install-Dependencies -package $package -packageProperties $packageProperties -packageFull $packages  
}

#download and install the exe packages
Write-Host "Begin installation of exe packages..."
foreach ($package in $exes) {
    Write-Host "Exe package is $package"
    $packageProperties = $packages.exes.$package

    if($packageProperties.download -eq 'true'){
        Download-Packages -DownloadPath $DownloadPath -package $package -packageProperties $packageProperties -githubDownload $false
        if(-not $SkipInstall){
            Install-Packages -DownloadPath $DownloadPath -package $package -packageProperties $packageProperties
        }
        else{
            Write-Host "`tSkipInstall is set, would install $package, but skipping..."
        }
    }
    else{
        Write-Host "`t$package is not set to download, skipping..."
    }
}

#download and install the github packages
Write-Host "Begin installation of github packages..."
foreach ($package in $github) {
    Write-Host "Github package is $package"
    $packageProperties = $packages.github.$package
    if($packageProperties.download -eq 'true'){
        Download-Packages -DownloadPath $DownloadPath -package $package -packageProperties $packageProperties -githubDownload $true
        if(-not $SkipInstall){
            Install-Packages -DownloadPath $DownloadPath -package $package -packageProperties $packageProperties
        }
        else{
            Write-Host "`tSkipInstall is set, would install $package, but skipping..."
        }
    }
    else{
        Write-Host "`t$package is not set to download, skipping..."
    }
}

#download and install the zip packages
Write-Host "Begin installation of zip packages..."
foreach ($package in $zip) {
    Write-Host "Zip package is $package"
    $packageProperties = $packages.zip.$package
    if($packageProperties.download -eq 'true'){
        Download-Packages -DownloadPath $DownloadPath -package $package -packageProperties $packageProperties -githubDownload $false
        if(-not $SkipInstall){
            Install-Packages -DownloadPath $DownloadPath -package $package -packageProperties $packageProperties
        }
        else{
            Write-Host "`tSkipInstall is set, would install $package, but skipping..."
        }
    }
    else{
        Write-Host "`t$package is not set to download, skipping..."
    }
}

#download and install the winget packages
Write-Host "Begin installation of winget packages..."
foreach ($package in $winget) {
    Write-Host "Winget package is $package"
    $packageProperties = $packages.winget.$package
    if($packageProperties.download -eq 'true'){
        if(-not $SkipInstall){
            Install-WingetPackages -package $package -packageProperties $packageProperties
        }
        else{
            Write-Host "`tSkipInstall is set, would install $package, but skipping..."
        }
    }
    else{
        Write-Host "`t$package is not set to download, skipping..."
    }
}

#download and install the choco packages
Write-Host "Begin installation of choco packages..."
foreach ($package in $choco) {
    Write-Host "Choco package is $package"
    $packageProperties = $packages.chocoPackages.$package
    if($packageProperties.download -eq 'true'){
        if(-not $SkipInstall){
            Install-ChocoPackages -package $package -packageProperties $packageProperties
        }
        else{
            Write-Host "`tSkipInstall is set, would install $package, but skipping..."
        }
    }
    else{
        Write-Host "`t$package is not set to download, skipping..."
    }
}

Stop-Transcript 
exit;

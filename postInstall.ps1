[CmdletBinding()]
param (
    [Parameter()]
    [string]$DownloadPath = "C:\packages",
    [Parameter()]
    [switch]$CheckGraphics
)

Start-Transcript -Path "$PSScriptRoot\postInstall.log" -Append -NoClobber -Force

#import packages.json
$packages = Get-Content ".\packages.json" | ConvertFrom-Json

if($(Get-Module PowerShellForGitHub -ListAvailable)){
    Write-Host "PowerShellForGitHub module is already installed."
}
else{
    Write-Host "Installing PowerShellForGitHub module..."
    Install-Module -Name PowerShellForGitHub -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    Import-Module PowerShellForGitHub -Force -ErrorAction Stop
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
            Invoke-Expression -Command "Enable-MMAgent -$setting"
        }
        elseif ($setting -like "MaxOperationAPIFiles" -and $($(Get-MMAgent).$setting) -lt 8192) {
            Write-Host "Setting $setting to $($settings[$setting])..."
            Invoke-Expression -Command "Set-MMAgent -$setting $($settings[$setting])"
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
        $extension = $package.Split(".")[-1]
        $repoName = $package.TrimEnd(".$extension")
        $filePath = Join-Path -Path $DownloadPath -ChildPath $package
        $downloadURL = $(Get-GitHubRelease -RepositoryName $repoName -OwnerName $packageProperties.author)[0].assets.browser_download_url

        if (-not (Test-Path $filePath)) {
            Write-Host "Downloading $downloadURL to $filePath"
            Start-BitsTransfer -Source $downloadURL -Destination $filePath -DisplayName $repoName -TransferType Download -ErrorAction Stop
        } else {
            Write-Host "$package already exists, skipping download."
        } 
    }
    else{
        $filePath = Join-Path -Path $DownloadPath -ChildPath $package
        if (-not (Test-Path $filePath)) {
            Write-Host "Downloading $($packageProperties.url) to $filePath"
            Start-BitsTransfer -Source $packageProperties.url -Destination $filePath -DisplayName $package -TransferType Download -ErrorAction Stop
        } else {
            Write-Host "$package skipping download."
        }
    }
}

function Extract-Packages($DownloadPath,$package,$packageName){

    $extractPath = "$($DownloadPath)\extracted\$packagePath"
    If(-not $(Test-Path $extractPath)){
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
        $wingetPath = $(Get-ChildItem "C:\Program Files\WindowsApps" -Recurse -Include "winget.exe" -ErrorAction SilentlyContinue).FullName

        if(-not $wingetPath){
            $wingetPath = $(Get-ChildItem "C:\Users\$($env:USERNAME)\AppData\Local\Microsoft\WindowsApps" -Recurse -Include "winget.exe" -ErrorAction SilentlyContinue).FullName
        }        <# Action when all if and elseif conditions are false #>
    }
    return $wingetPath
}

function Install-ChocoPackages($package, $packageProperties) {

    if([string]::IsNullOrEmpty("$(choco list $packageName | Select-String -Pattern '0')")){
        if($null -ne $packageProperties.version){
            Write-Host "Installing $package using Chocolatey"
            choco install $package --yes --no-prompt --accept-package-agreements --accept-source-agreements --version $packageProperties.version
        }
        else{
            Write-Host "Installing $package using Chocolatey"
            choco install $package --yes --no-prompt --accept-package-agreements --accept-source-agreements
        }
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    }
    else{
        Write-Host "$package is already installed, skipping installation."
    }
}

function Install-Dependencies($package, $packageProperties, $packageFull) {
    if($package -like "choco"){
        Write-Host "Chocolatey is not installed. Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
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
        Download-Packages -DownloadPath $DownloadPath -packageName $package -packageProperties $packageProperties -githubDownload $false
        Install-Packages -DownloadPath $DownloadPath -package $package -packageProperties $packageProperties
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
}

function Install-WingetPackages($package, $packageProperties) {
    $wingetStatus = Check-WingetInstall

    if($wingetStatus -eq "winget.exe"){
        Write-Host "Installing $package using winget"
        winget.exe install --id $package --silent --accept-source-agreements --accept-package-agreements --source winget
    }
    else{
        Write-Host "Installing $package using winget"
        & $wingetPath install --id $package --silent --accept-source-agreements --accept-package-agreements --source winget
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
}

function Install-Packages($DownloadPath,$package,$packageProperties){
    $extension = $package.Split(".")[-1]
    $packageName = $package.TrimEnd(".$extension")

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
    elseif ($packageName -like ".zip"){
        Write-Host "Installing $package using 7z"
        Extract-Packages -DownloadPath $DownloadPath -packageName $packageName -package $package
        $exeFile = Get-ChildItem "$downloadPath\extracted\$packageName\*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 | select -ExpandProperty Name
        if ($null -ne $exeFile) {
            Write-Host "No executable found in the extracted files, trying for .msi file."
            $exeFile = Get-ChildItem "$downloadPath\extracted\$packageName\*.msi" -ErrorAction SilentlyContinue | Select-Object -First 1 | select -ExpandProperty Name
        }

        try {
            Write-Host "Attempting to install $downloadPath\$package"
            Start-Process -FilePath "$downloadPath\extracted\$packageName\$exeFile" -ArgumentList "/SILENT /NORESTART" -Wait
        }
        catch {
            Write-Host "Failed to install with /SILENT switch, will try with /S"
            Start-Process -FilePath "$downloadPath\extracted\$packageName\$exeFile" -ArgumentList "/S" -Wait
        }
    }
    elseif ($packageName -like ".msxibundle"){
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
$exes = $packages.exes | Get-Member -MemberType NoteProperty | select -ExpandProperty Name
$github = $packages.github | Get-Member -MemberType NoteProperty | select -ExpandProperty Name
$zip = $packages.zip | Get-Member -MemberType NoteProperty | select -ExpandProperty Name
$winget = $packages.winget | Get-Member -MemberType NoteProperty | select -ExpandProperty Name
$choco = $packages.choco | Get-Member -MemberType NoteProperty | select -ExpandProperty Name


#first install dependencies
foreach ($package in $dependencies) {
    Write-Host "Begin installation of dependencies..."
    $packageProperties = $packages.dependencies.$package
    Install-Dependencies -package $package -packageProperties $packageProperties -packageFull $packages
}

#download and install the exe packages
foreach ($package in $exes) {
    Write-Host "Begin installation of exe packages..."
    $packageProperties = $packages.exes.$package

    if($packageProperties.download -eq 'true'){
        Download-Packages -DownloadPath $DownloadPath -packageName $package -packageProperties $packageProperties -githubDownload $false
        Install-Packages -DownloadPath $DownloadPath -packageName $package -packageProperties $packageProperties
    }
    else{
        Write-Host "$package is not set to download, skipping..."
    }
}

#download and install the github packages
foreach ($package in $github) {
    Write-Host "Begin installation of github packages..."
    $packageProperties = $packages.github.$package
    if($packageProperties.download -eq 'true'){
        Download-Packages -DownloadPath $DownloadPath -packageName $package -packageProperties $packageProperties -githubDownload $true
        Install-Packages -DownloadPath $DownloadPath -packageName $package -packageProperties $packageProperties
    }
    else{
        Write-Host "$package is not set to download, skipping..."
    }
}

#download and install the zip packages
foreach ($package in $zip) {
    Write-Host "Begin installation of zip packages..."
    $packageProperties = $packages.zip.$package
    if($packageProperties.download -eq 'true'){
        Download-Packages -DownloadPath $DownloadPath -packageName $package -packageProperties $packageProperties -githubDownload $false
        Install-Packages -DownloadPath $DownloadPath -packageName $package -packageProperties $packageProperties
    }
    else{
        Write-Host "$package is not set to download, skipping..."
    }
}

#download and install the winget packages
foreach ($package in $winget) {
    Write-Host "Begin installation of winget packages..."
    $packageProperties = $packages.winget.$package
    if($packageProperties.download -eq 'true'){
        Install-WingetPackages -package $package -packageProperties $packageProperties
    }
    else{
        Write-Host "$package is not set to download, skipping..."
    }
}

#download and install the choco packages
foreach ($package in $choco) {
    Write-Host "Begin installation of choco packages..."
    $packageProperties = $packages.choco.$package
    if($packageProperties.download -eq 'true'){
        Install-ChocoPackages -package $package -packageProperties $packageProperties
    }
    else{
        Write-Host "$package is not set to download, skipping..."
    }
}

Stop-Transcript 
exit;

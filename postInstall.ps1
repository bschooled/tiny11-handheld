[CmdletBinding()]
param (
    [Parameter()]
    [string]$DownloadPath = "C:\packages"
)

    #Filenames and URLs for the downloads
$Global:downloadHash = @{
    "7zr" = "https://7-zip.org/a/7zr.exe"
    "AMD Software" = "https://ftp.nluug.nl/pub/games/PC/guru3d/amd/2025/[Guru3D]-whql-amd-software-adrenalin-edition-25.3.1-win10-win11-march-rdna.exe"
    "Handheld Companion" = "https://github.com/Valkirie/HandheldCompanion/releases/download/0.22.2.8/HandheldCompanion-0.22.2.8.exe"
}
$Global:chocoPackages= @(
    "steam",
    "memreduct"
)

$Global:wingetPackages = @(
    "CompactGUI"
)

function Optimize-Memory(){
    #set powercfg 
    powercfg /h /type reduced

    #set memory compression
    Enable-MMAgent -ApplicationLaunchPrefetching
    Enable-MMAgent -ApplicationPreLaunch
    Set-MMAgent -MaxOperationAPIFiles 8192
    Enable-MMAgent -MemoryCompression
    Enable-MMAgent -OperationAPI
    Enable-MMAgent -PageCombining
}

#download setup
function Download-Packages($DownloadPath,$downloadHash){

    If(-not $(Test-Path $DownloadPath)){
        New-Item -Path $DownloadPath -ItemType Directory | Out-Null
    } 
    
    $downloadHash.GetEnumerator() | ForEach-Object {
        $fileName = $_.Key + ".exe"
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
    & "$downloadPath\7zr.exe" x "$downloadPath\$packageName" -o"$extractPath" -y
}

function Install-Packages($DownloadPath,$packageName,[bool]$chocoInstall,[bool]$wingetInstall){
    if(-not $(Get-Command choco)){
        Write-Host "Chocolatey is not installed. Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
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
    elseif($wingetInstall -eq $true) {
        if([string]::IsNullOrEmpty("$(winget list $packageName | Select-String -Pattern 'No installed packages found')")){
            Write-Host "Installing $packageName using winget"
            winget install $packageName --disable-interactivity
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
        elseif ($packageName -like "7zr"){
            Write-Host "7zr doesn't need installed, skipping installation."
        }
        else{
            try {
                Write-Host "Attempting to install $downloadPath\$packageName.exe"
                Start-Process -FilePath "$downloadPath\$packageName.exe" -ArgumentList "/SILENT" -Wait
            }
            catch {
                Write-Host "Failed to install with /SILENT switch, will try with /S"
                Start-Process -FilePath "$downloadPath\$packageName.exe" -ArgumentList "/S" -Wait
            }
        }
    }
}

Optimize-Memory
Download-Packages -DownloadPath $DownloadPath -downloadHash $Global:downloadHash

foreach ($package in $downloadHash.Keys){
    $installedPackage = Get-ItemProperty -Path "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -eq $package }
    if([string]::IsNullOrEmpty("$installedPackage")){
        Write-Host "$package is not installed, installing..."
        Install-Packages -DownloadPath $DownloadPath -packageName $package -chocoInstall $false
    }
    }
    else{
        Write-Host "$package is already installed, skipping installation."
    }
 
foreach ($package in $Global:chocoPackages){
    Install-Packages -DownloadPath $DownloadPath -packageName $package -chocoInstall $true
}

foreach ($package in $Global:wingetPackages){
    Install-Packages -DownloadPath $DownloadPath -packageName $package -chocoInstall $false -wingetInstall $true
}
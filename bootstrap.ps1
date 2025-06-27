$ErrorActionPreference = 'Continue'

Start-Transcript -Path "$PSScriptRoot\bootstrap.log" -Append -NoClobber -Force

function Install-PowerShellForGithub(){
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
}

function Install-Git(){
    if(-not $(Get-Command git -ErrorAction SilentlyContinue)){
    Write-Host "Git is not installed, installing Git..."
    $url = "https://github.com/git-for-windows/git/releases/download/v2.50.0.windows.1/Git-2.50.0-64-bit.exe"
    Start-BitsTransfer -Source $url -Destination "$env:TEMP\Git-2.50.0-64-bit.exe" -ErrorAction Stop
    Write-Host "Git installer downloaded successfully."
    $arguments = "/VERYSILENT /NORESTART /SUPPRESSMSGBOXES /SP- /CLOSEAPPLICATIONS /COMPONENTS=""gitlfs,gitk,gitgui,assoc,ext,icons,ssh,credentialmanager"" /LOG=""$env:TEMP\GitInstall.log"""
    $installerPath = "$env:TEMP\Git-2.50.0-64-bit.exe"
    Write-Host "Running Git installer..."
    Start-Process -FilePath $installerPath -ArgumentList $arguments -Wait

    # Refresh the shell environment so git is available
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "Refreshed PATH environment variable."
    }
    else{
        Write-Host "Git is already installed."
    }
}

function Clone-Tiny11HandheldRepo(){

    if(-not $(Get-Command git -ErrorAction SilentlyContinue)){
        $GitPath = "C:\Program Files\Git\cmd\git.exe"
        $gitExists = $false
    }
    else{
        $gitExists = $true
    }
    Write-Host "Clone repo for latest scripts..."
    if(-not $(Test-Path "C:\packages" -ErrorAction SilentlyContinue)){
        Write-Host "Creating C:\packages directory..."
        New-Item -Path "C:\packages" -ItemType Directory | Out-Null
    }
    else{
        Write-Host "C:\packages directory already exists, skipping creation..."
    }

    Set-Location -Path "C:\packages"
    Write-Host "Cloning tiny11-handheld repository..."
    if ($gitExists){
        git clone "https://github.com/bschooled/tiny11-handheld.git" -q -b dev
    }
    else{
        & "$GitPath" clone "https://github.com/bschooled/tiny11-handheld.git" "-q" "-b" "dev"
    }
    if(-not $(Test-Path "C:\packages\tiny11-handheld" -ErrorAction SilentlyContinue)){
        Write-Host "Failed to clone repository, exiting..."
        exit 1
    }
    else{
        Write-Host "Repository cloned successfully."
    }
}

Install-PowerShellForGithub
Install-Git
Clone-Tiny11HandheldRepo

Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile "$env:TEMP\winget.msixbundle"; Add-AppxPackage -Path "$env:TEMP\winget.msixbundle" -ForceApplicationShutdown; Remove-Item "$env:TEMP\winget.msixbundle"


Set-Location -Path "C:\packages\tiny11-handheld"

Write-Host "Running post-install script..."
if(-not $(Test-Path "C:\packages\tiny11-handheld\postInstall.ps1" -ErrorAction SilentlyContinue)){
    Write-Host "postInstall.ps1 script not found, exiting..."
    exit 1
}
else{
    Write-Host "postInstall.ps1 script found, proceeding with execution..."
    Start-Process -FilePath "powershell.exe" -ArgumentList " -File C:\packages\tiny11-handheld\postInstall.ps1" -WindowStyle Normal
}

Stop-Transcript
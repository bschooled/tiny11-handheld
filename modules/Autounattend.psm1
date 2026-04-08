#Requires -Version 7.0

<#
.SYNOPSIS
    Autounattend.xml generation module aligned with working template.

.DESCRIPTION
    Generates autounattend.xml that precisely follows the structure and patterns
    of the known-working autounattend.example.xml template.
    
    Supports configuration mapping for customization while maintaining:
    - ISO boot compatibility (inline commands only)
    - Proper XML element ordering
    - All critical namespace declarations
    - Windows SIM validation support
    
.NOTES
    Module: Autounattend.psm1
    Requires: PowerShell 7.0+
    Version: 4.0.0 - Template-aligned generation
#>

function New-AutounattendXml {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    Write-Host "Generating autounattend.xml (template-aligned)..." -ForegroundColor Green

    # Extract configuration with defaults
    $productKey = $Config.unattended?.productKey ?? "YTMG3-N6DKC-DKB77-7M9GH-8HVX7"
    $computerName = $Config.unattended?.computerName ?? "*"
    $timezone = $Config.unattended?.timezone ?? "Pacific Standard Time"
    $locale = $Config.locale ?? "en-US"
    $keyboardLayout = $Config.unattended?.keyboardLayout ?? "0409:00000409"
    
    $username = $Config.unattended?.userAccount?.username ?? "user"
    $password = $Config.unattended?.userAccount?.password ?? "Password123"
    $displayName = $Config.unattended?.userAccount?.displayName ?? $username
    $userGroup = $Config.unattended?.userAccount?.group ?? "Administrators"
    
    # OOBE settings
    $oobeProtectPCValue = $Config.unattended?.oobe?.protectYourPC ?? "3"
    $hideWirelessSetup = $Config.unattended?.oobe?.hideWirelessSetup ?? "false"
    
    # Feature detection for generating bypass commands
    $bypassAll = $Config.security?.bypassRequirementsCheck ?? $false
    $bypassTPM = $bypassAll -or ($Config.features?.bypassTPM ?? $false)
    $bypassSecureBoot = $bypassAll -or ($Config.features?.bypassSecureBoot ?? $false)
    $bypassRAM = $bypassAll -or ($Config.features?.bypassRAMCheck ?? $false)
    $bypassCPU = $bypassAll -or ($Config.features?.bypassCPUCheck ?? $false)
    $bypassStorage = $bypassAll -or ($Config.features?.bypassStorageCheck ?? $false)
    $bypassDisk = $bypassAll -or ($Config.features?.bypassDiskCheck ?? $false)
    $bypassUpgrade = $bypassAll -or ($Config.security?.bypassUpgradeTPMCPUCheck ?? $false)

    # Build windowsPE bypass commands (only if needed)
    $windowsPECommands = @()
    $cmdOrder = 1

    if ($bypassTPM) {
        $windowsPECommands += @{order = $cmdOrder++; key = "bypassTPM"; cmd = 'reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassTPMCheck /t REG_DWORD /d 1 /f' }
    }
    if ($bypassSecureBoot) {
        $windowsPECommands += @{order = $cmdOrder++; key = "bypassSecureBoot"; cmd = 'reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f' }
    }
    if ($bypassRAM) {
        $windowsPECommands += @{order = $cmdOrder++; key = "bypassRAM"; cmd = 'reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassRAMCheck /t REG_DWORD /d 1 /f' }
    }
    if ($bypassCPU) {
        $windowsPECommands += @{order = $cmdOrder++; key = "bypassCPU"; cmd = 'reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassCPUCheck /t REG_DWORD /d 1 /f' }
    }
    if ($bypassStorage) {
        $windowsPECommands += @{order = $cmdOrder++; key = "bypassStorage"; cmd = 'reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassStorageCheck /t REG_DWORD /d 1 /f' }
    }
    if ($bypassDisk) {
        $windowsPECommands += @{order = $cmdOrder++; key = "bypassDisk"; cmd = 'reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassDiskCheck /t REG_DWORD /d 1 /f' }
    }

    # USB install helpers (always included for compatibility)
    $windowsPECommands += @{order = $cmdOrder++; key = "allowRemovable"; cmd = 'reg.exe add "HKLM\SYSTEM\Setup" /v AllowRemovableMedia /t REG_DWORD /d 1 /f' }
    $windowsPECommands += @{order = $cmdOrder++; key = "forceRemovable"; cmd = 'reg.exe add "HKLM\SYSTEM\Setup" /v ForceRemovableInstall /t REG_DWORD /d 1 /f' }
    $windowsPECommands += @{order = $cmdOrder++; key = "usbBootSupported"; cmd = 'reg.exe add "HKLM\SYSTEM\Setup" /v UsbBootSupported /t REG_DWORD /d 1 /f' }
    $windowsPECommands += @{order = $cmdOrder++; key = "usbInstallAllowed"; cmd = 'reg.exe add "HKLM\SYSTEM\Setup" /v UsbInstallAllowed /t REG_DWORD /d 1 /f' }

    # Hardware warning suppression
    $windowsPECommands += @{order = $cmdOrder++; key = "hardwareCache"; cmd = 'reg.exe add "HKLM\SYSTEM\Setup" /v UnsupportedHardwareNotificationCache /t REG_DWORD /d 0 /f' }
    $windowsPECommands += @{order = $cmdOrder++; key = "hardwareCacheTime"; cmd = 'reg.exe add "HKLM\SYSTEM\Setup" /v UnsupportedHardwareNotificationCacheTime /t REG_QWORD /d 0 /f' }

    # Generate windowsPE RunSynchronous XML
    $windowsPERunSync = ""
    foreach ($cmd in $windowsPECommands) {
        $windowsPERunSync += @"
        <RunSynchronousCommand wcm:action="add" wcm:keyValue="$($cmd.key)">
          <Order>$($cmd.order)</Order>
          <Path>$([System.Security.SecurityElement]::Escape($cmd.cmd))</Path>
        </RunSynchronousCommand>
"@
    }

    # Build specialize commands
    $specializeCommands = @()
    $specOrder = 1

    $specializeCommands += @{order = $specOrder++; key = "mkdir"; cmd = 'cmd.exe /c mkdir C:\Windows\Setup\Scripts 2>nul' }
    $specializeCommands += @{order = $specOrder++; key = "portableOS"; cmd = 'reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control" /v PortableOperatingSystem /t REG_DWORD /d 0 /f' }
    $specializeCommands += @{order = $specOrder++; key = "winToGo"; cmd = 'reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v WinToGo /t REG_DWORD /d 0 /f' }
    $specializeCommands += @{order = $specOrder++; key = "portableOSNT"; cmd = 'reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v PortableOperatingSystem /t REG_DWORD /d 0 /f' }
    $specializeCommands += @{order = $specOrder++; key = "moSetupUpgrade"; cmd = 'reg.exe add "HKLM\SYSTEM\Setup\MoSetup" /v AllowUpgradesWithUnsupportedTPMOrCPU /t REG_DWORD /d 1 /f' }
    $specializeCommands += @{order = $specOrder++; key = "wuSafeguards"; cmd = 'reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableWUfBSafeguards /t REG_DWORD /d 1 /f' }
    $specializeCommands += @{order = $specOrder++; key = "wuTargetVersion"; cmd = 'reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v TargetReleaseVersion /t REG_DWORD /d 1 /f' }
    $specializeCommands += @{order = $specOrder++; key = "wuVersionInfo"; cmd = 'reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v TargetReleaseVersionInfo /t REG_SZ /d "23H2" /f' }
    $specializeCommands += @{order = $specOrder++; key = "vbsDisable"; cmd = 'reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 0 /f' }
    $specializeCommands += @{order = $specOrder++; key = "vbsPlatform"; cmd = 'reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v RequirePlatformSecurityFeatures /t REG_DWORD /d 0 /f' }
    $specializeCommands += @{order = $specOrder++; key = "hvciDisable"; cmd = 'reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v Enabled /t REG_DWORD /d 0 /f' }
    $specializeCommands += @{order = $specOrder++; key = "bcdHypervisor"; cmd = 'cmd.exe /c bcdedit /set hypervisorlaunchtype off' }
    $specializeCommands += @{order = $specOrder++; key = "bcdVsm"; cmd = 'cmd.exe /c bcdedit /set vsmlaunchtype off' }
    $specializeCommands += @{order = $specOrder++; key = "bitLockerDisable"; cmd = 'reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\BitLocker" /v PreventDeviceEncryption /t REG_DWORD /d 1 /f' }
    $specializeCommands += @{order = $specOrder++; key = "longPaths"; cmd = 'reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f' }
    $specializeCommands += @{order = $specOrder++; key = "hibernation"; cmd = 'reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f' }
    $specializeCommands += @{order = $specOrder++; key = "newsInterests"; cmd = 'reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f' }
    $specializeCommands += @{order = $specOrder++; key = "cloudContent"; cmd = 'reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f' }
    $specializeCommands += @{order = $specOrder++; key = "startPins"; cmd = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$json='\''{\"pinnedList\":[]}\'\''; $key=\'\'Registry::HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start\'\''; New-Item -Path $key -Force | Out-Null; New-ItemProperty -Path $key -Name ConfigureStartPins -PropertyType String -Value $json -Force | Out-Null"' }
    $specializeCommands += @{order = $specOrder++; key = "loadDefaultUser"; cmd = 'reg.exe load "HKU\DefaultUser" "C:\Users\Default\NTUSER.DAT"' }
    $specializeCommands += @{order = $specOrder++; key = "copilotOff"; cmd = 'reg.exe add "HKU\DefaultUser\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f' }
    $specializeCommands += @{order = $specOrder++; key = "contentDeliveryMgr"; cmd = 'cmd.exe /c for %N in (ContentDeliveryAllowed FeatureManagementEnabled OEMPreInstalledAppsEnabled PreInstalledAppsEnabled PreInstalledAppsEverEnabled SilentInstalledAppsEnabled SoftLandingEnabled SubscribedContentEnabled SubscribedContent-310093Enabled SubscribedContent-338387Enabled SubscribedContent-338388Enabled SubscribedContent-338389Enabled SubscribedContent-338393Enabled SubscribedContent-353694Enabled SubscribedContent-353696Enabled SubscribedContent-353698Enabled SystemPaneSuggestionsEnabled) do reg.exe add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v %N /t REG_DWORD /d 0 /f' }
    $specializeCommands += @{order = $specOrder++; key = "fileExtensions"; cmd = 'reg.exe add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f' }
    $specializeCommands += @{order = $specOrder++; key = "searchSuggestions"; cmd = 'reg.exe add "HKU\DefaultUser\Software\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f' }
    $specializeCommands += @{order = $specOrder++; key = "stickyKeys"; cmd = 'reg.exe add "HKU\DefaultUser\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 10 /f' }
    $specializeCommands += @{order = $specOrder++; key = "unloadDefaultUser"; cmd = 'reg.exe unload "HKU\DefaultUser"' }

    # Generate specialize RunSynchronous XML
    $specializeRunSync = ""
    foreach ($cmd in $specializeCommands) {
        $specializeRunSync += @"
        <RunSynchronousCommand wcm:action="add" wcm:keyValue="$($cmd.key)">
          <Order>$($cmd.order)</Order>
          <Path>$([System.Security.SecurityElement]::Escape($cmd.cmd))</Path>
        </RunSynchronousCommand>
"@
    }

    # FirstLogon commands
    $firstLogonCommands = @"
        <SynchronousCommand wcm:action="add" wcm:keyValue="1">
          <Order>1</Order>
          <CommandLine>powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Disable-ComputerRestore -Drive 'C:\' 2>$null"</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add" wcm:keyValue="2">
          <Order>2</Order>
          <CommandLine>powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Set-ItemProperty -LiteralPath 'Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name LaunchTo -Type DWord -Value 1"</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add" wcm:keyValue="3">
          <Order>3</Order>
          <CommandLine>powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-AppxPackage -Name 'Microsoft.Windows.Ai.Copilot.Provider' -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue"</CommandLine>
        </SynchronousCommand>
"@

    # Assemble final XML (following template structure exactly)
    $xmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend"
          xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
          xmlns:cpi="urn:schemas-microsoft-com:cpi">

  <!-- ========================= -->
  <!-- windowsPE: setup-time only -->
  <!-- ========================= -->
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <SetupUILanguage>
        <UILanguage>$locale</UILanguage>
      </SetupUILanguage>
      <InputLocale>$keyboardLayout</InputLocale>
      <SystemLocale>$locale</SystemLocale>
      <UILanguage>$locale</UILanguage>
      <UserLocale>$locale</UserLocale>
    </component>

    <component name="Microsoft-Windows-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">

      <ImageInstall>
        <OSImage>
          <Compact>true</Compact>
        </OSImage>
      </ImageInstall>

      <UserData>
        <ProductKey>
          <Key>$productKey</Key>
          <WillShowUI>OnError</WillShowUI>
        </ProductKey>
        <AcceptEula>true</AcceptEula>
      </UserData>

      <UseConfigurationSet>true</UseConfigurationSet>

      <RunSynchronous>
$windowsPERunSync
      </RunSynchronous>
    </component>
  </settings>

  <!-- ========================= -->
  <!-- specialize: installed OS   -->
  <!-- ========================= -->
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <ComputerName>$computerName</ComputerName>
      <TimeZone>$timezone</TimeZone>

      <RunSynchronous>
$specializeRunSync
      </RunSynchronous>
    </component>
  </settings>

  <!-- ========================= -->
  <!-- oobeSystem: user + OOBE    -->
  <!-- ========================= -->
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <InputLocale>$keyboardLayout</InputLocale>
      <SystemLocale>$locale</SystemLocale>
      <UILanguage>$locale</UILanguage>
      <UserLocale>$locale</UserLocale>
    </component>

    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">

      <OOBE>
        <ProtectYourPC>$oobeProtectPCValue</ProtectYourPC>
        <HideEULAPage>true</HideEULAPage>
        <HideWirelessSetupInOOBE>$hideWirelessSetup</HideWirelessSetupInOOBE>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
      </OOBE>

      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add" wcm:keyValue="$username">
            <Name>$username</Name>
            <DisplayName>$displayName</DisplayName>
            <Group>$userGroup</Group>
            <Password>
              <Value>$password</Value>
              <PlainText>true</PlainText>
            </Password>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>

      <AutoLogon>
        <Enabled>true</Enabled>
        <LogonCount>1</LogonCount>
        <Username>$username</Username>
        <Password>
          <Value>$password</Value>
          <PlainText>true</PlainText>
        </Password>
      </AutoLogon>

      <FirstLogonCommands>
$firstLogonCommands
      </FirstLogonCommands>

    </component>
  </settings>

  <!-- Windows SIM validation reference -->
  <cpi:offlineImage cpi:source="wim:D:\sources\install.wim#Windows 11 Pro" />

</unattend>
"@

    # Write to file
    $xmlContent | Out-File -FilePath $OutputPath -Encoding UTF8 -NoNewline
    Write-Host "✓ XML written to: $OutputPath" -ForegroundColor Green
    
    return $OutputPath
}

Export-ModuleMember -Function New-AutounattendXml

# Placeholder logging functions for compatibility
function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-LogDebug {
    param([string]$Message)
    Write-Host "[DEBUG] $Message" -ForegroundColor Gray
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

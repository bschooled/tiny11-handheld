# Preset Configuration Schema

This document describes all available options in the JSON preset files for the tiny11-handheld builder.

## Basic Settings

### locale
- **Description**: System locale/region settings
- **Type**: `string`
- **Example**: `"en-US"`

### timezone
- **Description**: Windows timezone
- **Type**: `string`
- **Example**: `"Pacific Standard Time"`

### keyboard
- **Description**: Keyboard layout
- **Type**: `string`
- **Example**: `"0409:00000409"`

### userAccount
- **Description**: Default user account to create automatically
- **Type**: `object`
- **Properties**:
  - `username` (string): Account name
  - `password` (string): Account password
  - `group` (string): User group (`"Administrators"` or `"Users"`)
- **Example**:
```json
{
  "username": "User",
  "password": "User",
  "group": "Administrators"
}
```

## Privacy Settings (`privacy`)

Settings that control data collection and privacy features.

### disableAppSuggestions
- **Description**: Disable app suggestions and ads in start menu/notifications
- **Type**: `boolean`
- **Default**: `false`
- **Registry**: `HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\*`

### disableTelemetry
- **Description**: Disable Windows telemetry and data collection
- **Type**: `boolean`
- **Default**: `false`

### disableCopilot
- **Description**: Disable Windows Copilot
- **Type**: `boolean`
- **Default**: `false`
- **Registry**: `HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot\TurnOffWindowsCopilot`

### expressSettings
- **Description**: Configure OOBE privacy settings
- **Type**: `string`
- **Values**: `"interactive"`, `"enableAll"`, `"disableAll"`
- **Default**: `"disableAll"`

## Security Settings (`security`)

Settings that control security features and protections.

### disableUac
- **Description**: Disable User Account Control prompts
- **Type**: `boolean`
- **Default**: `false`
- **Registry**: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\EnableLUA`

### disableSmartScreen
- **Description**: Disable Windows SmartScreen
- **Type**: `boolean`
- **Default**: `false`
- **Registry**: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SmartScreenEnabled`

### disableVirtualizationBasedSecurity
- **Description**: Disable VBS (Virtualization-Based Security) including HVCI
- **Type**: `boolean`
- **Default**: `false`
- **Registry**: `HKLM\System\CurrentControlSet\Control\DeviceGuard\EnableVirtualizationBasedSecurity`

### preventDeviceEncryption
- **Description**: Prevent automatic device encryption (BitLocker)
- **Type**: `boolean`
- **Default**: `false`
- **Registry**: `HKLM\SYSTEM\CurrentControlSet\Control\BitLocker\PreventDeviceEncryption`

### bypassRequirementsCheck
- **Description**: Bypass TPM, Secure Boot, and RAM requirements
- **Type**: `boolean`
- **Default**: `true`
- **Registry**: `HKLM\SYSTEM\Setup\LabConfig\Bypass*Check`

## User Interface Settings (`ui`)

Settings that control the appearance and behavior of Windows UI.

### showFileExtensions
- **Description**: Show file extensions in Explorer
- **Type**: `boolean`
- **Default**: `false`
- **Registry**: `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\HideFileExt`

### hideFiles
- **Description**: Control hidden file visibility
- **Type**: `string`
- **Values**: `"none"`, `"hidden"`, `"hiddenSystem"`
- **Default**: `"hidden"`
- **Registry**: `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Hidden`

### taskbarSearch
- **Description**: Taskbar search box mode
- **Type**: `string`
- **Values**: `"hide"`, `"icon"`, `"box"`, `"label"`
- **Default**: `"box"`
- **Registry**: `HKCU\Software\Microsoft\Windows\CurrentVersion\Search\SearchboxTaskbarMode`

### disableWidgets
- **Description**: Disable widgets/news and interests on taskbar
- **Type**: `boolean`
- **Default**: `false`
- **Registry**: `HKLM\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests`

### launchToThisPC
- **Description**: Open File Explorer to This PC instead of Quick Access
- **Type**: `boolean`
- **Default**: `false`
- **Registry**: `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\LaunchTo`

### disableWindowsConsumerFeatures
- **Description**: Disable consumer features (app suggestions, tips, etc.)
- **Type**: `boolean`
- **Default**: `false`
- **Registry**: `HKLM\Software\Policies\Microsoft\Windows\CloudContent\DisableWindowsConsumerFeatures`

### emptyStartPins
- **Description**: Remove all pinned items from Start menu
- **Type**: `boolean`
- **Default**: `false`

### disableBingResults
- **Description**: Disable Bing web results in Windows Search
- **Type**: `boolean`
- **Default**: `false`
- **Registry**: `HKCU\Software\Policies\Microsoft\Windows\Explorer\DisableSearchBoxSuggestions`

### disableStickyKeys
- **Description**: Disable Sticky Keys accessibility feature
- **Type**: `boolean`
- **Default**: `false`
- **Registry**: `HKCU\Control Panel\Accessibility\StickyKeys\Flags`

## Performance Settings (`performance`)

Settings that affect system performance and resource usage.

### enableLongPaths
- **Description**: Enable long path support (>260 characters)
- **Type**: `boolean`
- **Default**: `false`
- **Registry**: `HKLM\SYSTEM\CurrentControlSet\Control\FileSystem\LongPathsEnabled`

### disableFastStartup
- **Description**: Disable fast startup (hybrid shutdown)
- **Type**: `boolean`
- **Default**: `false`
- **Registry**: `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power\HiberbootEnabled`

### disableSystemRestore
- **Description**: Disable System Restore
- **Type**: `boolean`
- **Default**: `false`

### disableWindowsUpdate
- **Description**: Disable Windows Update automatic installation
- **Type**: `boolean`
- **Default**: `false`

## Development Settings (`development`)

Settings useful for developers and power users.

### allowPowerShellScripts
- **Description**: Set PowerShell execution policy to RemoteSigned
- **Type**: `boolean`
- **Default**: `false`

## Browser Settings (`browser`)

Settings for Microsoft Edge browser.

### hideEdgeFre
- **Description**: Hide Edge First Run Experience
- **Type**: `boolean`
- **Default**: `false`
- **Registry**: `HKLM\Software\Policies\Microsoft\Edge\HideFirstRunExperience`

### disableEdgeStartupBoost
- **Description**: Disable Edge startup boost and background mode
- **Type**: `boolean`
- **Default**: `false`
- **Registry**: `HKLM\Software\Policies\Microsoft\Edge\Recommended\StartupBoostEnabled`

## Bloatware Removal (`bloatware`)

### removePackages
- **Description**: List of AppxPackages to remove
- **Type**: `array` of `string`
- **Default**: `[]`
- **Available packages**: See `RemovePackages.ps1` in autounattend.xml
- **Example**:
```json
{
  "removePackages": [
    "Microsoft.BingNews",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "MicrosoftTeams"
  ]
}
```

### removeCapabilities
- **Description**: List of Windows capabilities to remove
- **Type**: `array` of `string`
- **Default**: `[]`
- **Available capabilities**: `"Print.Fax.Scan"`, `"Browser.InternetExplorer"`, `"Microsoft.Windows.WordPad"`, etc.
- **Example**:
```json
{
  "removeCapabilities": [
    "Browser.InternetExplorer",
    "Microsoft.Windows.WordPad"
  ]
}
```

### removeFeatures
- **Description**: List of Windows optional features to disable
- **Type**: `array` of `string`
- **Default**: `[]`
- **Available features**: `"MicrosoftWindowsPowerShellV2Root"`, `"Recall"`
- **Example**:
```json
{
  "removeFeatures": [
    "MicrosoftWindowsPowerShellV2Root"
  ]
}
```

## User Scripts (`scripts`)

Custom PowerShell scripts to run during installation phases.

### specialize
- **Description**: Script to run during specialize phase (before OOBE)
- **Type**: `string` (file path relative to preset)
- **Example**: `"scripts/specialize.ps1"`

### defaultUser
- **Description**: Script to run on default user registry hive
- **Type**: `string` (file path relative to preset)
- **Example**: `"scripts/defaultUser.ps1"`

### firstLogon
- **Description**: Script to run on first user logon
- **Type**: `string` (file path relative to preset)
- **Example**: `"scripts/firstLogon.ps1"`

### userOnce
### userOnce
- **Description**: Script to run once per user on first logon
- **Type**: `string` (file path relative to preset)
- **Example**: `"scripts/userOnce.ps1"`


### bootstrapScript
- **Description**: Path to bootstrap script to execute
- **Type**: `string` (file path relative to preset)
- **Example**: `"scripts/bootstrap.ps1"`

### buildVerification
- **Description**: Include built-in post-install verification script (writes state to `C:\build\build-state.txt`)
- **Type**: `boolean`
- **Default**: `false`
- **Notes**: Uses repository script `scripts/validation/verify-settings.ps1`

### runOnce
- **Description**: Custom script to run once per user on first logon
- **Type**: `string` (file path relative to preset or absolute)
- **Default**: not set
- **Example**: `"scripts/custom-user-once.ps1"`
- **Example**: `"scripts/bootstrap.ps1"`

## Password Policy (`passwordPolicy`)

### maxPasswordAge
- **Description**: Maximum password age in days
- **Type**: `string`
- **Values**: `"unlimited"`, or number of days
- **Default**: `"unlimited"`

## Complete Example

```json
{
  "locale": "en-US",
  "timezone": "Pacific Standard Time",
  "keyboard": "0409:00000409",
  
  "userAccount": {
    "username": "User",
    "password": "User",
    "group": "Administrators"
  },

  "privacy": {
    "disableAppSuggestions": true,
    "disableTelemetry": true,
    "disableCopilot": true,
    "expressSettings": "disableAll"
  },

  "security": {
    "disableUac": false,
    "disableSmartScreen": true,
    "disableVirtualizationBasedSecurity": true,
    "preventDeviceEncryption": true,
    "bypassRequirementsCheck": true
  },

  "ui": {
    "showFileExtensions": true,
    "hideFiles": "hidden",
    "taskbarSearch": "box",
    "disableWidgets": true,
    "launchToThisPC": true,
    "disableWindowsConsumerFeatures": true,
    "emptyStartPins": true,
    "disableBingResults": true,
    "disableStickyKeys": true
  },

  "performance": {
    "enableLongPaths": true,
    "disableFastStartup": true,
    "disableSystemRestore": true,
    "disableWindowsUpdate": false
  },

  "development": {
    "allowPowerShellScripts": true
  },

  "browser": {
    "hideEdgeFre": true,
    "disableEdgeStartupBoost": true
  },

  "bloatware": {
    "removePackages": [
      "Microsoft.BingNews",
      "Microsoft.GetHelp",
      "Microsoft.Getstarted",
      "Microsoft.MixedReality.Portal",
      "Microsoft.People",
      "MicrosoftTeams"
    ],
    "removeCapabilities": [
      "Browser.InternetExplorer",
      "Microsoft.Windows.WordPad"
    ],
    "removeFeatures": [
      "MicrosoftWindowsPowerShellV2Root"
    ]
  },

  "scripts": {
    "bootstrapScript": "C:\\bootstrap.ps1"
  },

  "passwordPolicy": {
    "maxPasswordAge": "unlimited"
  }
}
```

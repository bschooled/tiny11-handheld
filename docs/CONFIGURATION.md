# Configuration Reference

Complete reference for `configurations.json` configuration file.

## Table of Contents

- [Schema Overview](#schema-overview)
- [Configuration Sections](#configuration-sections)
  - [version](#version)
  - [metadata](#metadata)
  - [source](#source)
  - [output](#output)
  - [packages](#packages)
  - [features](#features)
  - [optimization](#optimization)
  - [drivers](#drivers)
  - [updates](#updates)
  - [oem](#oem)
  - [unattended](#unattended)
  - [postInstall](#postinstall)
- [Validation Rules](#validation-rules)
- [Examples](#examples)

## Schema Overview

All configurations are validated against [`schema.json`](../schema.json) using JSON Schema Draft 07.

**Required fields:**
- `version`: Configuration schema version
- `source`: Source ISO information
- `output`: Output image settings

**Optional fields:**
- `metadata`: Configuration metadata
- `packages`: Package removal settings
- `features`: System requirement bypasses
- `optimization`: Image optimization settings
- `drivers`: Driver injection settings
- `updates`: Windows Update injection settings
- `oem`: OEM customization settings
- `unattended`: Unattended installation settings
- `postInstall`: Post-installation automation settings

## Configuration Sections

### version

**Type:** `string`  
**Required:** Yes  
**Format:** Semantic versioning (`MAJOR.MINOR.PATCH`)  
**Example:** `"1.0.0"`

Specifies the configuration schema version. Must match semver pattern `^\d+\.\d+\.\d+$`.

```json
{
  "version": "1.0.0"
}
```

---

### metadata

**Type:** `object`  
**Required:** No

Human-readable information about the configuration.

**Properties:**

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | string | No | Configuration display name |
| `description` | string | No | Configuration purpose/description |
| `author` | string | No | Configuration author |
| `created` | string (ISO 8601) | No | Creation timestamp |

**Example:**

```json
{
  "metadata": {
    "name": "ROG Ally Gaming Build",
    "description": "Optimized for ASUS ROG Ally with AMD drivers",
    "author": "John Doe",
    "created": "2024-01-15T10:30:00Z"
  }
}
```

---

### source

**Type:** `object`  
**Required:** Yes

Defines the source Windows 11 ISO file.

**Properties:**

| Property | Type | Required | Description | Validation |
|----------|------|----------|-------------|------------|
| `isoPath` | string | Yes | Path to Windows 11 ISO | Valid file path |
| `checksum` | string | No | SHA256 checksum (recommended) | 64 hex characters |
| `architecture` | string | Yes | Target architecture | `amd64` or `arm64` |

**Example:**

```json
{
  "source": {
    "isoPath": "/path/to/Win11_23H2_English_x64.iso",
    "checksum": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2",
    "architecture": "amd64"
  }
}
```

**Notes:**
- `isoPath` can be absolute or relative to project root
- `checksum` validation prevents corrupted source files
- `arm64` support is experimental

---

### output

**Type:** `object`  
**Required:** Yes

Defines output ISO settings.

**Properties:**

| Property | Type | Required | Default | Description | Validation |
|----------|------|----------|---------|-------------|------------|
| `imageName` | string | Yes | - | Output ISO filename | Must end with `.iso` |
| `outputPath` | string | Yes | - | Output directory | Valid directory path |
| `compressionLevel` | string | No | `"fast"` | WIM compression | `none`, `fast`, `max`, `recovery` |

**Example:**

```json
{
  "output": {
    "imageName": "tiny11-custom.iso",
    "outputPath": "./output",
    "compressionLevel": "max"
  }
}
```

**Compression Level Impact:**

| Level | Speed | Size | Use Case |
|-------|-------|------|----------|
| `none` | Fastest | Largest | Testing/development |
| `fast` | Fast | Medium | General use (recommended) |
| `max` | Slow | Smallest | Distribution/storage |
| `recovery` | Slowest | Smallest | Recovery images |

---

### packages

**Type:** `object`  
**Required:** No

Controls Windows app package removal.

**Properties:**

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `removeEdge` | boolean | No | `false` | Remove Microsoft Edge |
| `removeOneDrive` | boolean | No | `false` | Remove OneDrive integration |
| `removeList` | array of strings | No | `[]` | Packages to remove |
| `keepList` | array of strings | No | `[]` | Packages to preserve (overrides removeList) |

**Example:**

```json
{
  "packages": {
    "removeEdge": true,
    "removeOneDrive": true,
    "removeList": [
      "Microsoft.BingNews",
      "Microsoft.BingWeather",
      "Microsoft.Xbox.TCUI",
      "Microsoft.XboxApp"
    ],
    "keepList": [
      "Microsoft.WindowsStore",
      "Microsoft.WindowsTerminal"
    ]
  }
}
```

**Common Package Names:**

| Package | Description |
|---------|-------------|
| `Microsoft.BingNews` | News widget |
| `Microsoft.BingWeather` | Weather widget |
| `Microsoft.GamingApp` | Xbox app |
| `Microsoft.MicrosoftOfficeHub` | Office hub |
| `Microsoft.SkypeApp` | Skype |
| `Microsoft.WindowsStore` | Microsoft Store (keep!) |
| `Microsoft.WindowsTerminal` | Windows Terminal (keep!) |
| `Microsoft.XboxApp` | Xbox app |
| `Microsoft.YourPhone` | Phone Link |
| `Microsoft.ZuneMusic` | Media Player |

**Notes:**
- `keepList` takes precedence over `removeList`
- Always keep `Microsoft.WindowsStore` and `Microsoft.DesktopAppInstaller` for app installation
- Some packages have dependencies; check build logs for warnings

---

### features

**Type:** `object`  
**Required:** No

System requirement bypass settings.

**Properties:**

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `bypassSystemRequirements` | boolean | No | `false` | Bypass all checks (TPM, SecureBoot, RAM) |
| `bypassTPM` | boolean | No | `false` | Bypass TPM 2.0 requirement |
| `bypassSecureBoot` | boolean | No | `false` | Bypass Secure Boot requirement |
| `bypassRAMCheck` | boolean | No | `false` | Bypass 4GB RAM requirement |

**Example:**

```json
{
  "features": {
    "bypassSystemRequirements": true
  }
}
```

**Or granular control:**

```json
{
  "features": {
    "bypassTPM": true,
    "bypassSecureBoot": true,
    "bypassRAMCheck": false
  }
}
```

**Notes:**
- `bypassSystemRequirements: true` enables all individual bypasses
- Individual flags allow fine-grained control
- Required for older hardware and handheld devices
- Implemented via registry modifications in `autounattend.xml`

---

### optimization

**Type:** `object`  
**Required:** No

Image size optimization settings.

**Properties:**

| Property | Type | Required | Default | Description | Risk |
|----------|------|----------|---------|-------------|------|
| `componentCleanup` | boolean | No | `true` | Run component cleanup | Low |
| `resetBase` | boolean | No | `false` | Reset superseded components | Medium |
| `removeWinSxSBackups` | boolean | No | `false` | Remove WinSxS backups | **High** |

**Example:**

```json
{
  "optimization": {
    "componentCleanup": true,
    "resetBase": true,
    "removeWinSxSBackups": false
  }
}
```

**Optimization Impact:**

| Operation | Space Saved | Reversible | Risk |
|-----------|-------------|------------|------|
| Component cleanup | 500MB - 1GB | Yes | Low |
| Reset base | 1GB - 2GB | No | Medium |
| Remove WinSxS backups | 2GB - 4GB | **No** | **High** |

**Warnings:**
- `resetBase`: Cannot roll back Windows updates after this operation
- `removeWinSxSBackups`: **Irreversible** - prevents component restoration and some repairs
- Recommended: Enable `componentCleanup` only unless disk space is critical

---

### drivers

**Type:** `object`  
**Required:** No

Driver injection settings.

**Properties:**

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `inject` | boolean | No | `false` | Enable driver injection |
| `driverPath` | string | **If inject=true** | - | Path to driver directory |
| `recursive` | boolean | No | `true` | Search subdirectories |

**Example:**

```json
{
  "drivers": {
    "inject": true,
    "driverPath": "./drivers/rog-ally",
    "recursive": true
  }
}
```

**Driver Directory Structure:**

```
drivers/
└── rog-ally/
    ├── audio/
    │   ├── driver.inf
    │   └── driver.sys
    ├── gpu/
    │   └── amdgpu.inf
    └── chipset/
        └── chipset.inf
```

**Notes:**
- Only `.inf` files are processed
- `recursive: true` scans all subdirectories
- DISM validates driver signatures automatically
- Invalid drivers are skipped with warnings in logs

---

### updates

**Type:** `object`  
**Required:** No

Windows Update injection settings.

**Properties:**

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `inject` | boolean | No | `false` | Enable update injection |
| `updatePath` | string | **If inject=true** | - | Path to update directory |

**Example:**

```json
{
  "updates": {
    "inject": true,
    "updatePath": "./updates"
  }
}
```

**Supported Update Formats:**
- `.msu` files (standalone updates)
- `.cab` files (cabinet archives)

**Notes:**
- Updates must match source ISO architecture (amd64/arm64)
- Download from [Microsoft Update Catalog](https://www.catalog.update.microsoft.com/)
- Cumulative updates can be large (500MB+)

---

### oem

**Type:** `object`  
**Required:** No

OEM customization file injection.

**Properties:**

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `inject` | boolean | No | `false` | Enable OEM injection |
| `oemPath` | string | **If inject=true** | - | Path to OEM directory |

**Example:**

```json
{
  "oem": {
    "inject": true,
    "oemPath": "./oem"
  }
}
```

**OEM Directory Contents:**
- Logo images (`.bmp`, `.png`)
- Support information files
- Pre-installed configuration files
- Custom scripts

**Injection Target:** `C:\Windows\System32\oem\` in final image

---

### unattended

**Type:** `object`  
**Required:** No

Unattended installation settings (generates `autounattend.xml`).

**Properties:**

| Property | Type | Required | Default | Description | Validation |
|----------|------|----------|---------|-------------|------------|
| `computerName` | string | No | Auto-generated | Computer name | 1-15 chars, alphanumeric + hyphens |
| `productKey` | string | No | - | Windows product key | `XXXXX-XXXXX-XXXXX-XXXXX-XXXXX` |
| `timezone` | string | No | `"Pacific Standard Time"` | Windows timezone | Valid timezone name |
| `locale` | string | No | `"en-US"` | Culture code | `xx-XX` format |
| `keyboardLayout` | string | No | `"0409:00000409"` | Keyboard layout | `LLLL:KKKKKKKK` format |

**Example:**

```json
{
  "unattended": {
    "computerName": "GAMING-PC",
    "productKey": "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX",
    "timezone": "Eastern Standard Time",
    "locale": "en-US",
    "keyboardLayout": "0409:00000409"
  }
}
```

**Common Timezones:**

| Timezone | Description |
|----------|-------------|
| `Pacific Standard Time` | US West Coast (UTC-8) |
| `Mountain Standard Time` | US Mountain (UTC-7) |
| `Central Standard Time` | US Central (UTC-6) |
| `Eastern Standard Time` | US East Coast (UTC-5) |
| `UTC` | Coordinated Universal Time |
| `GMT Standard Time` | UK (UTC+0) |

**Common Keyboard Layouts:**

| Layout | Code | Description |
|--------|------|-------------|
| US | `0409:00000409` | US English (QWERTY) |
| UK | `0809:00000809` | UK English |
| German | `0407:00000407` | German (QWERTZ) |
| French | `040c:0000040c` | French (AZERTY) |

**Notes:**
- If `computerName` is omitted, Windows generates one automatically
- `productKey` is optional; can activate later
- Timezone names must match Windows registry names exactly
- `autounattend.xml` is regenerated only when config changes

---

### postInstall

**Type:** `object`  
**Required:** No

Post-installation automation settings.

**Properties:**

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `packagesJsonPath` | string | No | `"packages.json"` | Path to package manifest |

**Example:**

```json
{
  "postInstall": {
    "packagesJsonPath": "packages.json"
  }
}
```

**Package Manifest Format (`packages.json`):**

```json
{
  "packages": [
    {
      "name": "Google Chrome",
      "url": "https://dl.google.com/chrome/install/latest/chrome_installer.exe",
      "installer": "chrome_installer.exe",
      "arguments": "/silent /install"
    },
    {
      "name": "7-Zip",
      "url": "https://www.7-zip.org/a/7z2201-x64.exe",
      "installer": "7z2201-x64.exe",
      "arguments": "/S"
    }
  ]
}
```

**Execution:**
- Runs on first boot after OOBE
- Executes via PowerShell scheduled task
- Logs to `C:\Windows\Temp\postInstall.log`

---

## Validation Rules

All configurations are validated against [`schema.json`](../schema.json) before build execution.

### Manual Validation

**Using PowerShell:**

```powershell
Test-Json -SchemaFile schema.json -Path configurations.json
```

**Using online validator:**

1. Open [jsonschemavalidator.net](https://www.jsonschemavalidator.net/)
2. Paste `schema.json` into left panel
3. Paste `configurations.json` into right panel
4. Check for errors

### Common Validation Errors

**"Missing required property: version"**
- Add `"version": "1.0.0"` to root object

**"Pattern mismatch: version"**
- Version must be semver format: `1.0.0`, not `1.0` or `v1.0.0`

**"Enum mismatch: architecture"**
- Must be exactly `"amd64"` or `"arm64"` (case-sensitive)

**"Pattern mismatch: checksum"**
- Must be 64 hexadecimal characters (SHA256)
- Use: `sha256sum Win11.iso` (Linux) or `Get-FileHash -Algorithm SHA256 Win11.iso` (PowerShell)

**"Dependency not met: driverPath"**
- If `"inject": true`, `driverPath` is required
- Either set `"inject": false` or provide `"driverPath": "./drivers"`

---

## Examples

### Minimal Configuration

```json
{
  "version": "1.0.0",
  "source": {
    "isoPath": "Win11_23H2_English_x64.iso",
    "architecture": "amd64"
  },
  "output": {
    "imageName": "tiny11.iso",
    "outputPath": "./output"
  }
}
```

### Handheld Gaming Device

```json
{
  "version": "1.0.0",
  "metadata": {
    "name": "Handheld Gaming Build",
    "description": "Aggressive debloating for handheld devices"
  },
  "source": {
    "isoPath": "Win11_23H2_English_x64.iso",
    "architecture": "amd64"
  },
  "output": {
    "imageName": "tiny11-handheld.iso",
    "outputPath": "./output",
    "compressionLevel": "max"
  },
  "packages": {
    "removeEdge": true,
    "removeOneDrive": true,
    "removeList": [
      "Microsoft.BingNews",
      "Microsoft.Xbox.TCUI",
      "Microsoft.XboxApp"
    ],
    "keepList": [
      "Microsoft.WindowsStore"
    ]
  },
  "features": {
    "bypassSystemRequirements": true
  },
  "optimization": {
    "componentCleanup": true,
    "resetBase": true
  },
  "unattended": {
    "timezone": "Pacific Standard Time",
    "locale": "en-US"
  }
}
```

### Enterprise Desktop with Updates

```json
{
  "version": "1.0.0",
  "metadata": {
    "name": "Enterprise Desktop Image",
    "description": "Pre-patched Windows 11 for corporate deployment"
  },
  "source": {
    "isoPath": "Win11_23H2_Enterprise_x64.iso",
    "checksum": "abc123...",
    "architecture": "amd64"
  },
  "output": {
    "imageName": "win11-enterprise-2024-01.iso",
    "outputPath": "./output",
    "compressionLevel": "fast"
  },
  "packages": {
    "removeOneDrive": true,
    "removeList": [
      "Microsoft.BingNews",
      "Microsoft.BingWeather"
    ]
  },
  "updates": {
    "inject": true,
    "updatePath": "./updates/2024-01"
  },
  "drivers": {
    "inject": true,
    "driverPath": "./drivers/enterprise",
    "recursive": true
  },
  "unattended": {
    "productKey": "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX",
    "timezone": "Eastern Standard Time",
    "locale": "en-US"
  },
  "postInstall": {
    "packagesJsonPath": "packages-enterprise.json"
  }
}
```

### Maximum Compression for Distribution

```json
{
  "version": "1.0.0",
  "source": {
    "isoPath": "Win11_23H2_English_x64.iso",
    "architecture": "amd64"
  },
  "output": {
    "imageName": "tiny11-ultra.iso",
    "outputPath": "./output",
    "compressionLevel": "max"
  },
  "packages": {
    "removeEdge": true,
    "removeOneDrive": true,
    "removeList": [
      "Microsoft.BingNews",
      "Microsoft.BingWeather",
      "Microsoft.GamingApp",
      "Microsoft.GetHelp",
      "Microsoft.Getstarted",
      "Microsoft.Microsoft3DViewer",
      "Microsoft.MicrosoftOfficeHub",
      "Microsoft.MicrosoftSolitaireCollection",
      "Microsoft.Office.OneNote",
      "Microsoft.SkypeApp",
      "Microsoft.WindowsCamera",
      "Microsoft.WindowsMaps",
      "Microsoft.Xbox.TCUI",
      "Microsoft.XboxApp",
      "Microsoft.YourPhone",
      "Microsoft.ZuneMusic",
      "Microsoft.ZuneVideo"
    ]
  },
  "features": {
    "bypassSystemRequirements": true
  },
  "optimization": {
    "componentCleanup": true,
    "resetBase": true,
    "removeWinSxSBackups": true
  }
}
```

---

## See Also

- [README.md](README.md): Quick start guide
- [schema.json](../schema.json): JSON Schema definition
- [Specification](../specs/001-cross-platform-build/spec.md): Feature requirements
- [Architecture](../specs/001-cross-platform-build/plan.md): Technical design

# Data Model: Cross-Platform Build Support

**Feature**: 001-cross-platform-build  
**Date**: 2026-01-01  
**Purpose**: Define data structures for configuration, build state, and module interfaces

## Configuration Entities

### BuildConfiguration

Complete build configuration loaded from `configurations.json`. Controls all aspects of the Windows 11 image customization.

**Fields**:

```json
{
  "version": "string (semver)",
  "metadata": {
    "name": "string",
    "description": "string",
    "author": "string",
    "created": "ISO 8601 datetime"
  },
  "source": {
    "isoPath": "string (path to Windows 11 ISO)",
    "checksum": "string (SHA256 hash)",
    "architecture": "enum('amd64', 'arm64')"
  },
  "output": {
    "imageName": "string (output ISO filename)",
    "outputPath": "string (directory for output)",
    "compressionLevel": "enum('none', 'fast', 'max', 'recovery')"
  },
  "packages": {
    "removeEdge": "boolean",
    "removeOneDrive": "boolean",
    "removeList": ["string (package names)"],
    "keepList": ["string (package names to preserve)"]
  },
  "features": {
    "bypassSystemRequirements": "boolean",
    "bypassTPM": "boolean",
    "bypassSecureBoot": "boolean",
    "bypassRAMCheck": "boolean"
  },
  "optimization": {
    "componentCleanup": "boolean",
    "resetBase": "boolean",
    "removeWinSxSBackups": "boolean"
  },
  "drivers": {
    "inject": "boolean",
    "driverPath": "string (directory containing drivers)",
    "recursive": "boolean"
  },
  "updates": {
    "inject": "boolean",
    "updatePath": "string (directory containing .msu or .cab files)"
  },
  "oem": {
    "inject": "boolean",
    "oemPath": "string (directory containing OEM files)"
  },
  "unattended": {
    "computerName": "string (optional, auto-generated if not provided)",
    "productKey": "string (optional, Windows product key)",
    "timezone": "string (e.g., 'Pacific Standard Time')",
    "locale": "string (e.g., 'en-US')",
    "keyboardLayout": "string (e.g., '0409:00000409')"
  },
  "postInstall": {
    "packagesJsonPath": "string (path to packages.json)"
  }
}
```

**Validation Rules**:

- `version` must be valid semver (e.g., "1.0.0")
- `source.isoPath` must exist and be readable
- `source.checksum` must match ISO file if provided
- `source.architecture` must match ISO content
- `output.outputPath` must be writable
- All paths must be valid for the platform (normalized during load)
- If `drivers.inject` is true, `drivers.driverPath` must exist
- If `updates.inject` is true, `updates.updatePath` must exist
- `unattended.timezone` must be valid Windows timezone name (e.g., "Pacific Standard Time", "UTC")
- `unattended.locale` must be valid culture code (e.g., "en-US", "de-DE")
- `unattended.productKey` if provided must be valid format (XXXXX-XXXXX-XXXXX-XXXXX-XXXXX)
- Security bypasses (features.bypassTPM, bypassSecureBoot, bypassRAMCheck) map to autounattend.xml LabConfig registry entries

**Relationships**:

- References `packages.json` via `postInstall.packagesJsonPath`
- `features` section maps to autounattend.xml bypass registry entries
- `unattended` section maps to autounattend.xml user data and regional settings
- Referenced by `BuildState` to track active configuration

---

### PackageManifest

Application installation manifest loaded from `packages.json`. Defines post-install applications and their installation methods.

**Fields**:

```json
{
  "name": "string",
  "version": "string (semver)",
  "description": "string",
  "author": "string",
  "dependencies": {
    "<package-name>": {
      "url": "string (download URL or 'choco')",
      "download": "boolean"
    }
  },
  "exes": {
    "<executable-name>": {
      "url": "string (download URL)",
      "graphics": "boolean (graphics driver flag)",
      "download": "boolean",
      "install": "boolean"
    }
  }
}
```

**Validation Rules**:

- `name`, `version`, `description`, `author` are required
- `dependencies` and `exes` can be empty objects
- Each dependency must have `url` and `download` boolean
- Each exe entry must have `url`, `graphics`, `download`, and `install` booleans
- URLs must be valid HTTP/HTTPS or special keyword ('choco')

**Relationships**:

- Referenced by `BuildConfiguration.postInstall.packagesJsonPath`
- Used by post-install script after image creation

---

### ConfigurationSchema

JSON Schema definition for validating `BuildConfiguration` and `PackageManifest`.

**Purpose**: Provide compile-time validation of configuration files before build starts.

**Fields** (JSON Schema properties):

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["version", "source", "output"],
  "properties": {
    "version": {"type": "string", "pattern": "^\\d+\\.\\d+\\.\\d+$"},
    "source": {
      "type": "object",
      "required": ["isoPath", "architecture"],
      "properties": {
        "isoPath": {"type": "string"},
        "checksum": {"type": "string", "pattern": "^[a-fA-F0-9]{64}$"},
        "architecture": {"enum": ["amd64", "arm64"]}
      }
    }
    // ... (additional schema definitions)
  }
}
```

**Usage**: Loaded by validation module to check configurations before build

---

### BuildState

Runtime state tracking for the build process. Not persisted in configuration files; maintained in memory during build.

**Fields**:

```json
{
  "buildId": "string (UUID)",
  "startTime": "ISO 8601 datetime",
  "platform": "enum('windows', 'linux')",
  "buildMethod": "enum('native-windows', 'docker-windows', 'wimlib-linux')",
  "configuration": "BuildConfiguration (loaded config)",
  "workspace": {
    "tempDir": "string (path to temp workspace)",
    "scratchDir": "string (path to mounted image)",
    "isoExtractDir": "string (path to extracted ISO)"
  },
  "progress": {
    "currentPhase": "enum('init', 'extract', 'mount', 'customize', 'unmount', 'iso-create', 'complete', 'failed')",
    "completedSteps": ["string (step names)"],
    "errors": ["ErrorDetail"]
  },
  "metrics": {
    "buildDuration": "number (seconds)",
    "imageSizeOriginal": "number (bytes)",
    "imageSizeFinal": "number (bytes)",
    "packagesRemoved": "number"
  }
}
```

**Lifecycle**: Created at build start, updated throughout build, written to log file on completion

---

### ErrorDetail

Structured error information for logging and user feedback.

**Fields**:

```json
{
  "timestamp": "ISO 8601 datetime",
  "severity": "enum('info', 'warning', 'error', 'critical')",
  "code": "string (error code, e.g., 'ERR_MISSING_PREREQ')",
  "message": "string (human-readable description)",
  "context": {
    "module": "string (which module generated error)",
    "operation": "string (what operation failed)",
    "additionalInfo": "object (key-value pairs)"
  },
  "suggestion": "string (how to fix)"
}
```

**Error Codes**:

- `ERR_MISSING_PREREQ`: Required tool not found
- `ERR_ISO_NOT_FOUND`: Source ISO file missing
- `ERR_ISO_CHECKSUM_MISMATCH`: ISO integrity check failed
- `ERR_DISK_SPACE`: Insufficient disk space
- `ERR_INVALID_CONFIG`: Configuration validation failed
- `ERR_MOUNT_FAILED`: WIM image mount operation failed
- `ERR_PACKAGE_REMOVAL`: Package removal failed
- `ERR_DRIVER_INJECTION`: Driver injection failed
- `ERR_ISO_CREATE`: ISO creation failed

---

## Module Interfaces

### Platform Detection Module

**Interface**:

```powershell
function Get-BuildPlatform {
    <#
    .OUTPUTS
    PlatformInfo object with properties:
    - OS: 'Windows' | 'Linux' | 'macOS'
    - Architecture: 'amd64' | 'arm64' | 'x86'
    - PreferredMethod: 'native-windows' | 'docker-windows' | 'wimlib-linux'
    - DockerAvailable: boolean
    - WimlibAvailable: boolean
    #>
}
```

---

### Prerequisites Validator Module

**Interface**:

```powershell
function Test-BuildPrerequisites {
    param(
        [string]$Platform,  # 'windows' or 'linux'
        [string]$Method     # 'native-windows', 'docker-windows', 'wimlib-linux'
    )
    <#
    .OUTPUTS
    PrerequisiteResult object with properties:
    - AllMet: boolean
    - MissingTools: array of ToolInfo
    - Warnings: array of strings
    
    ToolInfo: {Name, Required, Found, InstallCommand}
    #>
}
```

---

### Configuration Loader Module

**Interface**:

```powershell
function Import-BuildConfiguration {
    param(
        [string]$ConfigPath,
        [string]$SchemaPath
    )
    <#
    .OUTPUTS
    BuildConfiguration object or throws ValidationException
    #>
}

function ConvertTo-PlatformPath {
    param(
        [string]$Path
    )
    <#
    .OUTPUTS
    Platform-appropriate path string
    #>
}
```

---

### Logger Module

**Interface**:

```powershell
function Write-BuildLog {
    param(
        [string]$Message,
        [string]$Level = 'Info',  # 'Info', 'Warning', 'Error', 'Debug'
        [hashtable]$Context = @{}
    )
}

function Start-BuildLog {
    param([string]$LogPath)
}

function Stop-BuildLog {
    # Finalizes log, writes summary
}
```

---

### Image Builder Module (Windows Native)

**Interface**:

```powershell
function Invoke-WindowsNativeBuild {
    param(
        [BuildConfiguration]$Config,
        [BuildState]$State
    )
    <#
    .OUTPUTS
    BuildResult object with properties:
    - Success: boolean
    - OutputIsoPath: string
    - Metrics: BuildMetrics
    - Errors: array of ErrorDetail
    #>
}
```

---

### Image Builder Module (Docker-based)

**Interface**:

```bash
#!/bin/bash
function invoke_docker_build() {
    local config_path=$1
    local state_file=$2
    # Builds Windows 11 image using Docker container with DISM
    # Returns: 0 on success, non-zero on failure
    # Output: JSON result written to state_file
}
```

---

### Image Builder Module (wimlib-based)

**Interface**:

```bash
#!/bin/bash
function invoke_wimlib_build() {
    local config_path=$1
    local state_file=$2
    # Builds Windows 11 image using wimlib-imagex
    # Returns: 0 on success, non-zero on failure
    # Output: JSON result written to state_file
    # Note: Limited feature set compared to DISM
}
```

---

## State Transitions

```text
[Start]
   ↓
[Platform Detection] → PlatformInfo
   ↓
[Prerequisite Validation] → Pass/Fail
   ↓ (Pass)
[Load Configuration] → BuildConfiguration
   ↓
[Validate Configuration] → Pass/Fail
   ↓ (Pass)
[Initialize BuildState]
   ↓
[Extract ISO]
   ↓
[Mount Image]
   ↓
[Apply Customizations] (package removal, drivers, etc.)
   ↓
[Unmount Image]
   ↓
[Create ISO]
   ↓
[Validate Output]
   ↓
[Cleanup Workspace]
   ↓
[Complete] → BuildResult
```

**Error Handling**: Any phase failure transitions to [Cleanup Workspace] → [Failed] state

---

## Data Flow

```text
User → configurations.json → Import-BuildConfiguration
                                      ↓
                           Validate against schema.json
                                      ↓
                              BuildConfiguration object
                                      ↓
                              Get-BuildPlatform
                                      ↓
                        Test-BuildPrerequisites
                                      ↓
                      Route to platform-specific builder
                         (Windows/Docker/wimlib)
                                      ↓
                            Execute build phases
                                      ↓
                      Update BuildState at each phase
                                      ↓
                          Write structured logs
                                      ↓
                        Return BuildResult to user
```

---

## Persistence

- **Configuration files**: JSON on disk (configurations.json, packages.json)
- **Build state**: In-memory during build, written to log on completion
- **Logs**: Append-only text files with structured JSON entries
- **Workspace**: Temporary directories, cleaned up after build (unless --keep-workspace flag)
- **Output**: Final ISO file, checksums file, build summary JSON

---

## Configuration Examples

### Minimal Configuration

```json
{
  "version": "1.0.0",
  "source": {
    "isoPath": "/path/to/windows11.iso",
    "architecture": "amd64"
  },
  "output": {
    "imageName": "tiny11-custom.iso",
    "outputPath": "./output"
  }
}
```

### Full Configuration

```json
{
  "version": "1.0.0",
  "metadata": {
    "name": "ROG Ally Optimized Build",
    "description": "Optimized for ASUS ROG Ally handheld",
    "author": "User",
    "created": "2026-01-01T00:00:00Z"
  },
  "source": {
    "isoPath": "/home/user/Win11_23H2_EnglishInternational_x64.iso",
    "checksum": "abc123...",
    "architecture": "amd64"
  },
  "output": {
    "imageName": "TinyHandheld11_ROGAlly.iso",
    "outputPath": "./output",
    "compressionLevel": "max"
  },
  "packages": {
    "removeEdge": true,
    "removeOneDrive": true,
    "removeList": [
      "Microsoft.WindowsAlarms",
      "Microsoft.BingWeather",
      "Microsoft.GetHelp"
    ]
  },
  "features": {
    "bypassSystemRequirements": true,
    "bypassTPM": true,
    "bypassSecureBoot": true
  },
  "optimization": {
    "componentCleanup": true,
    "resetBase": true
  },
  "drivers": {
    "inject": true,
    "driverPath": "./drivers/rog-ally",
    "recursive": true
  }
}
```

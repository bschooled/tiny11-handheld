# CLI Interface Contract

**Feature**: 001-cross-platform-build  
**Version**: 1.0.0  
**Purpose**: Define command-line interface for cross-platform Windows 11 image builder

## Build Command

### Linux Entry Point

```bash
./build.sh [OPTIONS] --config <path> --output <path>
```

### Windows Entry Point

```powershell
.\build.ps1 [OPTIONS] -Config <path> -Output <path>
```

---

## Common Options

| Option | Aliases | Type | Required | Default | Description |
|--------|---------|------|----------|---------|-------------|
| `--config` | `-c` | string | Yes | - | Path to configurations.json |
| `--output` | `-o` | string | No | `./output` | Output directory for ISO |
| `--method` | `-m` | enum | No | auto | Build method: `auto`, `native`, `docker`, `wimlib` |
| `--dry-run` | `-n` | flag | No | false | Show what would be done without making changes |
| `--verbose` | `-v` | flag | No | false | Enable verbose logging |
| `--keep-workspace` | `-k` | flag | No | false | Don't delete temporary workspace after build |
| `--log-file` | `-l` | string | No | `./build.log` | Path to log file |
| `--validate-only` | - | flag | No | false | Only validate configuration, don't build |
| `--parallel` | `-p` | flag | No | false | Enable parallel operations where possible |

---

## Platform-Specific Options

### Linux Only

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--docker-image` | string | `tiny11-builder:windows` | Docker image name for Windows container |
| `--fallback-wimlib` | flag | false | Use wimlib instead of Docker if Docker unavailable |

### Windows Only

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--skip-admin-check` | flag | false | Skip administrator privilege check (not recommended) |
| `--scratch-disk` | string | `$PWD` | Disk/directory for temporary workspace |

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid configuration |
| 3 | Missing prerequisites |
| 4 | ISO file not found or invalid |
| 5 | Insufficient disk space |
| 6 | Mount operation failed |
| 7 | Package removal failed |
| 8 | ISO creation failed |
| 9 | Permission denied |
| 10 | User cancelled operation |

---

## Output Format

### Standard Output (JSON mode)

When `--json` flag is used, output structured JSON:

```json
{
  "success": true,
  "buildId": "uuid-string",
  "duration": 1234.56,
  "output": {
    "isoPath": "/path/to/output.iso",
    "checksum": "sha256-hash",
    "size": 7516192768
  },
  "metrics": {
    "packagesRemoved": 42,
    "driversInjected": 15,
    "imageSizeReduction": 3221225472
  }
}
```

### Standard Output (Human-readable mode)

Default mode with progress indicators:

```
[INFO] Validating configuration...
[INFO] Platform detected: Linux (Docker available)
[INFO] Checking prerequisites...
✅ All prerequisites met
[INFO] Starting build (ID: abc-123-def)
[PROGRESS] Extracting ISO... 25%
[PROGRESS] Mounting image... 50%
[INFO] Removing 42 packages...
[PROGRESS] Applying customizations... 75%
[PROGRESS] Creating ISO... 90%
✅ Build complete: /path/to/output.iso
Build time: 18m 34s
Image size: 7.0 GB (3.0 GB reduction)
```

---

## Configuration File Contract

### configurations.json

See [data-model.md](../data-model.md#buildconfiguration) for complete schema.

**Minimal example**:
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

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TINY11_CONFIG` | Default configuration file path | `./configurations.json` |
| `TINY11_WORKSPACE` | Workspace directory | `./workspace` |
| `TINY11_LOG_LEVEL` | Log level (DEBUG, INFO, WARN, ERROR) | `INFO` |
| `TINY11_DOCKER_IMAGE` | Docker image for Linux builds | `tiny11-builder:windows` |

---

## Usage Examples

### Build with default configuration

```bash
# Linux
./build.sh --config ./configurations.json

# Windows
.\build.ps1 -Config .\configurations.json
```

### Validate configuration without building

```bash
# Linux
./build.sh --config ./config.json --validate-only

# Windows
.\build.ps1 -Config .\config.json -ValidateOnly
```

### Dry run to preview changes

```bash
# Linux
./build.sh -c ./config.json --dry-run --verbose

# Windows
.\build.ps1 -Config .\config.json -DryRun -Verbose
```

### Build with wimlib fallback on Linux

```bash
./build.sh -c ./config.json --method wimlib
```

### Keep workspace for debugging

```bash
# Linux
./build.sh -c ./config.json --keep-workspace

# Windows
.\build.ps1 -Config .\config.json -KeepWorkspace
```

---

## Error Handling Examples

### Missing prerequisite

```
[ERROR] Missing prerequisite: docker
[INFO] Docker is required for DISM operations on Linux
[INFO] Install with: sudo apt install docker.io
[INFO] Or use wimlib fallback: ./build.sh --method wimlib
Exit code: 3
```

### Invalid configuration

```
[ERROR] Configuration validation failed
[ERROR] source.isoPath: File not found: /path/to/missing.iso
[ERROR] packages.removeList[0]: Invalid package name: ""
Exit code: 2
```

### Insufficient disk space

```
[ERROR] Insufficient disk space
[INFO] Required: 20 GB
[INFO] Available: 12 GB
[INFO] Please free up space or choose different workspace location
Exit code: 5
```

---

## Logging Contract

### Log File Format

Structured log entries in JSON Lines format (one JSON object per line):

```json
{"timestamp":"2026-01-01T12:00:00Z","level":"INFO","message":"Build started","context":{"buildId":"abc-123"}}
{"timestamp":"2026-01-01T12:01:30Z","level":"INFO","message":"Package removed","context":{"package":"Microsoft.WindowsAlarms"}}
{"timestamp":"2026-01-01T12:15:00Z","level":"WARN","message":"Driver injection skipped","context":{"reason":"No drivers found"}}
{"timestamp":"2026-01-01T12:18:34Z","level":"INFO","message":"Build complete","context":{"duration":1114,"outputSize":7516192768}}
```

### Log Levels

- **DEBUG**: Detailed trace information (only with --verbose)
- **INFO**: General informational messages
- **WARN**: Warning messages (operation continues)
- **ERROR**: Error messages (operation may fail)
- **CRITICAL**: Critical errors (operation aborted)

---

## Prerequisite Check Command

### Linux

```bash
./check-prereqs.sh [--method docker|wimlib]
```

**Output**:
```
Checking prerequisites for Linux (Docker method)...
✅ docker (20.10.22) - Docker container runtime
✅ p7zip (16.02) - 7-Zip file archiver
✅ sha256sum (8.30) - Checksum utility
⚠️  wimlib-imagex not found - Optional, fallback if Docker unavailable
   Install with: sudo apt install wimtools
✅ genisoimage (1.1.11) - ISO creation tool

All required prerequisites met!
Optional: Install wimlib-imagex for fallback option
```

### Windows

```powershell
.\check-prereqs.ps1
```

**Output**:
```
Checking prerequisites for Windows...
✅ DISM - Deployment Image Servicing and Management
✅ PowerShell 5.1.19041.4522 - PowerShell
✅ 7z (23.01) - 7-Zip
⚠️  oscdimg not found - Required for ISO creation
   Install: Download Windows ADK from Microsoft
   URL: https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install

Missing required prerequisites. Please install oscdimg before continuing.
```

---

## Module Interface Contract (PowerShell)

### PlatformDetection Module

```powershell
Import-Module ./modules/PlatformDetection.psm1

$platform = Get-BuildPlatform
# Returns: @{OS='Windows'; Architecture='amd64'; PreferredMethod='native-windows'; DockerAvailable=$true}
```

### ConfigValidation Module

```powershell
Import-Module ./modules/ConfigValidation.psm1

$config = Import-BuildConfiguration -ConfigPath './config.json' -SchemaPath './schema.json'
$valid = Test-BuildConfiguration -Config $config
# Returns: @{Valid=$true; Errors=@(); Warnings=@()}
```

### Logger Module

```powershell
Import-Module ./modules/Logger.psm1

Start-BuildLog -LogPath './build.log'
Write-BuildLog -Message "Build started" -Level Info -Context @{buildId='abc-123'}
Stop-BuildLog
```

---

## Module Interface Contract (Bash)

### Platform Detection

```bash
source ./platform/linux/detect-platform.sh

detect_platform
# Sets: BUILD_PLATFORM, BUILD_METHOD, DOCKER_AVAILABLE, WIMLIB_AVAILABLE
```

### Prerequisites Check

```bash
source ./platform/linux/check-prereqs.sh

check_prerequisites "docker"
# Returns: 0 if all met, 1 if missing, prints messages to stdout
```

---

## Integration Points

### Docker Container Interface

**Entry point**: `docker run tiny11-builder:windows /workspace/build-in-container.ps1`

**Volume mounts**:
- `/workspace` - Build workspace (read/write)
- `/iso` - Source ISO (read-only)
- `/config` - Configuration files (read-only)

**Environment variables**:
- `TINY11_CONFIG_PATH` - Path to configuration JSON inside container
- `TINY11_LOG_LEVEL` - Logging level

**Exit codes**: Same as CLI exit codes

**Output**: Writes JSON result to `/workspace/build-result.json`

### wimlib Interface

**Commands used**:
- `wimlib-imagex info` - Get WIM information
- `wimlib-imagex mount` - Mount WIM image
- `wimlib-imagex unmount` - Unmount WIM image
- `wimlib-imagex delete` - Delete packages (limited support)
- `wimlib-imagex export` - Export WIM with compression

**Wrapper script**: `./platform/linux/wimlib-builder.sh`

**Input**: Configuration JSON path
**Output**: Exit code + JSON result file

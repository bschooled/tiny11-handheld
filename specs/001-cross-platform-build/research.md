# Research: Cross-Platform Build Support

**Feature**: 001-cross-platform-build  
**Date**: 2026-01-01  
**Purpose**: Resolve technical unknowns and evaluate approaches for building Windows 11 images from Linux

## Research Questions

### Q1: How can DISM operations be performed on Linux?

**Decision**: Use Docker with Windows Server Core container + wimlib-imagex hybrid approach

**Rationale**:
DISM (Deployment Image Servicing and Management) is a Windows-only tool that manipulates WIM (Windows Imaging Format) files. Three approaches investigated:

1. **Docker + Windows Container (CHOSEN)**
   - Pros: Native DISM available, full compatibility, official Microsoft base images
   - Cons: Requires Docker Desktop with Windows containers on Linux (via WSL2 or dedicated Windows VM), larger container size (~1-2GB)
   - Implementation: Use `mcr.microsoft.com/windows/servercore:ltsc2022` base image with DISM cmdlets
   - Performance: Acceptable for infrequent builds (~5-10 min overhead for container)

2. **wimlib-imagex (HYBRID ALTERNATIVE)**
   - Pros: Native Linux tool, faster, no Docker overhead, open source
   - Cons: Not 100% compatible with all DISM operations (some advanced package removal may fail), less tested for Windows 11
   - Implementation: Use wimlib-imagex for image mounting/extraction, limited package operations
   - Use case: Fallback option if Docker approach proves too complex

3. **Wine + DISM (REJECTED)**
   - Pros: No virtualization overhead
   - Cons: DISM relies heavily on Windows kernel APIs; Wine support insufficient
   - Tested: DISM.exe fails to run under Wine due to missing kernel drivers

**Chosen Approach**: Primary - Docker with Windows container; Fallback - wimlib-imagex with limited feature set

**Implementation Notes**:

- Docker approach requires Docker Desktop 4.0+ with WSL2 backend on Linux
- Windows container licensing: Use evaluation images or require users to provide their own
- Fallback to wimlib-imagex for users who cannot use Docker
- Document both paths clearly in prerequisites

### Q2: What are the platform-equivalent tools for each build stage?

**Decision**: Maintain tool parity matrix with graceful degradation

| Build Stage | Windows | Linux (Docker) | Linux (wimlib) |
| ----------- | ------- | -------------- | -------------- |
| ISO Extraction | 7-Zip | p7zip-full | p7zip-full |
| WIM Mounting | DISM | DISM (Docker) | wimlib-imagex |
| Package Removal | DISM /Remove-ProvisionedAppxPackage | DISM (Docker) | Limited support |
| Driver Injection | DISM /Add-Driver | DISM (Docker) | wimlib-imagex --add |
| Registry Modification | reg.exe / PowerShell | DISM (Docker) | wimtools reged |
| WIM Export/Compress | DISM /Export-Image | DISM (Docker) | wimlib-imagex export |
| ISO Creation | oscdimg (Windows ADK) | genisoimage or xorriso | genisoimage or xorriso |
| Checksum Validation | Get-FileHash (PowerShell) | sha256sum | sha256sum |

**Rationale**:

- Docker approach provides 100% tool compatibility via Windows container
- wimlib approach requires feature detection and graceful degradation
- ISO creation tools (oscdimg vs. genisoimage) produce compatible results with proper flags

**Alternatives Considered**:

- **Wine emulation**: Rejected - insufficient API support for DISM
- **Virtual machine**: Rejected - too heavyweight, defeats purpose of cross-platform tool
- **Windows on ARM via QEMU**: Rejected - performance penalty too high

### Q3: How to handle PowerShell scripts cross-platform?

**Decision**: PowerShell Core 7+ for shared logic, Bash wrapper for Linux orchestration

**Rationale**:

- PowerShell Core 7+ runs on Linux and Windows
- Existing tiny11maker.ps1 uses PowerShell 5.1 features (Windows-only)
- Strategy:
  1. **Shared logic**: Refactor reusable functions into PowerShell Core 7+ modules (JSON parsing, configuration validation)
  2. **Platform wrappers**:
     - Linux: Bash script (`build.sh`) detects prerequisites, invokes Docker/wimlib, calls PS Core modules
     - Windows: PowerShell script (`build.ps1`) uses native DISM, calls shared PS Core modules
  3. **Existing code**: Keep tiny11maker.ps1 for Windows-native path, gradually refactor

**Alternatives Considered**:

- **Python**: Rejected - adds another language dependency, team knows PowerShell better
- **Pure Bash**: Rejected - difficult to share logic with existing PowerShell codebase
- **Node.js**: Rejected - JavaScript not suitable for system-level operations

**Implementation Path**:

```text
Repository Structure:
├── build.sh              # Linux entry point (Bash)
├── build.ps1             # Windows entry point (PowerShell 5.1+)
├── modules/
│   ├── Config.psm1       # PowerShell Core 7+ (shared)
│   ├── Validation.psm1   # PowerShell Core 7+ (shared)
│   └── Logger.psm1       # PowerShell Core 7+ (shared)
├── platform/
│   ├── windows/
│   │   └── ImageBuilder.psm1  # Windows-specific DISM operations
│   └── linux/
│       ├── docker-builder.sh  # Docker-based DISM wrapper
│       └── wimlib-builder.sh  # wimlib-based operations
└── tiny11maker.ps1       # Legacy Windows-only (maintained for compatibility)
```

### Q4: How to ensure configuration portability across platforms?

**Decision**: JSON Schema validation with cross-platform path normalization

**Rationale**:

- JSON is platform-neutral
- Existing configurations.json and packages.json are already JSON
- Path separators (\ vs /) need normalization
- PowerShell handles paths cross-platform via `Join-Path` and `[System.IO.Path]::Combine()`

**Implementation**:

- JSON Schema file (schema.json) defines valid configuration structure
- Validation module (PowerShell Core compatible) checks before build starts
- Path normalization function converts all paths to platform-appropriate format
- Configuration migration utility for users with hardcoded Windows paths

**Alternatives Considered**:

- **YAML**: Rejected - no existing code uses it, JSON sufficient
- **TOML**: Rejected - less PowerShell support
- **XML**: Rejected - verbose, harder to edit manually

### Q5: Docker container strategy for Windows DISM on Linux

**Decision**: Build custom Windows container with DISM + required tools, persist as reusable image

**Rationale**:

- Base image: `mcr.microsoft.com/windows/servercore:ltsc2022` (1.5GB)
- Install DISM PowerShell module (included in base)
- Install 7-Zip, oscdimg (from Windows ADK)
- Volume mount: bind host directory for ISO/workspace access
- Container lifecycle: build once, reuse for all builds

**Dockerfile Structure**:

```dockerfile
FROM mcr.microsoft.com/windows/servercore:ltsc2022

# Install PowerShell 7 for cross-platform module compatibility
RUN powershell -Command \
    Invoke-WebRequest -Uri https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/PowerShell-7.4.0-win-x64.msi -OutFile pwsh.msi; \
    Start-Process msiexec.exe -ArgumentList '/i pwsh.msi /quiet' -Wait; \
    Remove-Item pwsh.msi

# Install 7-Zip
RUN powershell -Command \
    Invoke-WebRequest -Uri https://www.7-zip.org/a/7z2301-x64.exe -OutFile 7z-install.exe; \
    Start-Process 7z-install.exe -ArgumentList '/S' -Wait; \
    Remove-Item 7z-install.exe

# Copy shared PowerShell modules
COPY modules/ C:/modules/

# Set working directory
WORKDIR C:/workspace

ENTRYPOINT ["pwsh", "-File"]
```

**Container Usage**:

```bash
# Build container (one-time)
docker build -t tiny11-builder:windows -f Dockerfile.windows .

# Run build (each build)
docker run --rm \
  -v $(pwd):/workspace \
  -v /path/to/iso:/iso:ro \
  tiny11-builder:windows /workspace/platform/windows/ImageBuilder.ps1 -Config /workspace/configurations.json
```

**Alternatives Considered**:

- **Windows VM via Vagrant**: Rejected - too heavyweight, slower startup
- **QEMU Windows ARM**: Rejected - performance issues
- **Remote Windows build server**: Rejected - requires network, defeats offline capability

### Q6: Prerequisite detection and user guidance

**Decision**: Multi-stage prerequisite checker with platform-specific installation instructions

**Implementation**:

```bash
# check-prereqs.sh (Linux)
#!/bin/bash
REQUIRED_TOOLS=(
    "docker:Docker (for DISM support)|https://docs.docker.com/engine/install/"
    "p7zip:7-Zip|apt install p7zip-full"
    "sha256sum:coreutils|apt install coreutils"
)

OPTIONAL_TOOLS=(
    "wimlib-imagex:wimlib (fallback if Docker unavailable)|apt install wimtools"
    "genisoimage:ISO creation|apt install genisoimage"
    "xorriso:ISO creation (alternative)|apt install xorriso"
)

for tool_spec in "${REQUIRED_TOOLS[@]}"; do
    tool="${tool_spec%%:*}"
    desc="${tool_spec#*:}"
    if ! command -v "$tool" &> /dev/null; then
        echo "❌ REQUIRED: $desc"
        exit 1
    else
        echo "✅ Found: $tool"
    fi
done
```

**PowerShell Equivalent**:

```powershell
# check-prereqs.ps1 (Windows)
$requiredCommands = @(
    @{Name='DISM'; Test={Get-Command DISM -ErrorAction SilentlyContinue}; Install='Built-in to Windows'}
    @{Name='oscdimg'; Test={Get-Command oscdimg -ErrorAction SilentlyContinue}; Install='Install Windows ADK'}
    @{Name='7z'; Test={Get-Command 7z -ErrorAction SilentlyContinue}; Install='choco install 7zip'}
)

foreach ($cmd in $requiredCommands) {
    if (& $cmd.Test) {
        Write-Host "✅ Found: $($cmd.Name)"
    } else {
        Write-Host "❌ REQUIRED: $($cmd.Name) - Install: $($cmd.Install)"
        $missingPrereqs = $true
    }
}
```

**Rationale**:

- Early failure saves time if prerequisites missing
- Clear installation instructions reduce support burden
- Platform-specific package managers (apt, choco, etc.) in guidance

## Best Practices Research

### Configuration-Driven Design

- **Source**: PowerShell Best Practices Guide, HashiCorp Configuration Best Practices
- **Pattern**: Separate configuration from code; validate early; fail fast
- **Application**: All build options in JSON; schema validation before any operations

### Docker Best Practices for Windows Containers

- **Source**: Microsoft Docker documentation, Docker best practices
- **Pattern**: Multi-stage builds, minimal layers, .dockerignore
- **Application**: Separate build stage for tools installation; runtime stage minimal

### WIM/DISM Operation Safety

- **Source**: Microsoft DISM documentation, Windows ADK guides
- **Pattern**: Always export to new WIM after modifications; verify checksums
- **Application**: Never modify source WIM in-place; export to new file; validate before ISO creation

### Cross-Platform Script Compatibility

- **Source**: PowerShell Core migration guide
- **Pattern**: Avoid Windows-only cmdlets; use `$IsWindows`/`$IsLinux` built-in variables
- **Application**: Conditional logic based on platform; shared modules use only cross-platform features

## Risks and Mitigations

| Risk | Impact | Mitigation |
| ---- | ------ | ---------- |
| Docker Windows container size (1-2GB) | Slow first-time setup | Document clearly; provide pre-built images on Docker Hub; fallback to wimlib |
| wimlib incomplete DISM parity | Some package removals fail | Document limitations; recommend Docker approach; graceful degradation |
| Windows container licensing | Users unsure about legality | Clear documentation: use eval images or bring-your-own Windows license |
| Build time increase on Linux (Docker overhead) | User frustration | Optimize Dockerfile layers; document expected times; provide benchmarks |
| Configuration path separator differences | Build failures | Automatic path normalization; validate in schema; clear error messages |

## Technology Choices Summary

| Component | Technology | Reason |
| --------- | ---------- | ------ |
| Linux DISM | Docker + Windows Server Core | Native compatibility, official Microsoft base |
| Linux DISM Fallback | wimlib-imagex | No Docker dependency, faster, good enough for basic operations |
| Cross-platform scripting | PowerShell Core 7+ modules | Shares code with existing Windows PowerShell, cross-platform capable |
| Linux orchestration | Bash wrapper | Native to Linux, handles Docker/wimlib switching |
| Windows orchestration | PowerShell 5.1+ | Existing codebase, native tooling |
| Configuration format | JSON + JSON Schema | Existing format, cross-platform, schema validation available |
| ISO creation (Linux) | genisoimage or xorriso | Standard Linux tools, compatible output |
| ISO creation (Windows) | oscdimg (Windows ADK) | Existing dependency, best compatibility |

## Open Questions Resolved

1. **Q**: Should we support macOS?  
   **A**: No - out of scope for initial release. Docker + Windows container should theoretically work on macOS but untested.

2. **Q**: How to handle Windows Updates injection?  
   **A**: Same approach as driver injection - Docker container has DISM /Add-Package capability.

3. **Q**: Can wimlib replace Docker entirely?  
   **A**: Partially - good for basic WIM operations, limited for advanced package management. Offer as fallback option.

4. **Q**: Performance impact of Docker approach?  
   **A**: Acceptable - container startup ~30s, DISM operations same speed as native, total overhead ~2-5 minutes per build.

## Next Steps (Phase 1)

1. Create data model for build configuration schema
2. Define module interfaces (PowerShell and Bash)
3. Design error handling and logging contracts
4. Create quickstart guide with prerequisite installation
5. Update agent context with researched technologies

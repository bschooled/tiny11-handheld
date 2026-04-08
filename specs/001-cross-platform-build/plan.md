# Implementation Plan: Cross-Platform Build Support

**Branch**: `001-cross-platform-build` | **Date**: 2026-01-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-cross-platform-build/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Clarifications Resolved (2026-01-01)

The following critical design decisions were clarified during specification review:

1. **Docker DISM on Linux** (FR-007): Linux builds MUST use Docker with Windows Server Core (mcr.microsoft.com/windows/servercore:ltsc2022) running native DISM for functional equivalence with Windows builds. wimlib approach rejected.

2. **Hybrid Logging** (FR-011): Logger.psm1 uses PowerShell native cmdlets (Write-Error, Write-Warning, Write-Information, Write-Verbose) on Windows while providing cross-platform abstraction with ERROR/WARN/INFO/DEBUG levels for Bash compatibility.

3. **Partial Rollback** (FR-010, SC-005): Build failures undo current failed stage only while preserving earlier completed stages (ISO extraction, WIM mounting) for faster retry. Source ISO always unchanged.

4. **autounattend.xml Parameterization** (FR-009): Existing autounattend.old.xml extracted into JSON config fields (bypassTPM/SecureBoot/RAM, computerName, productKey, timezone, locale). Regenerated during build only if config changes.

5. **Preset Merge Strategy** (FR-016): Presets provide baseline defaults. User config.json overrides preset values via shallow merge at top-level keys (e.g., user "features" replaces preset "features" entirely, not field-by-field).

6. **Memory Constraints** (FR-019, SC-002): Build process MUST limit peak memory usage to 8GB maximum to support 16GB developer workstations.

7. **Sensitive Data Warnings** (FR-020): Config validation detects patterns (password/apikey/token/secret/credential in key/value names) and issues WARN-level alerts without blocking build.

These clarifications align the implementation with constitutional principles while addressing cross-platform challenges.

## Summary

Enable building optimized Windows 11 images from both Windows and Linux platforms using a unified, configuration-driven approach. The technical approach leverages Docker containers running Windows Server Core with DISM tools on Linux hosts, while maintaining native DISM usage on Windows hosts. All customization is exposed through JSON configuration files (configurations.json, packages.json) with a modular PowerShell/Bash wrapper architecture that detects the host platform and routes to appropriate tooling.

## Technical Context

**Language/Version**: Bash 5.0+ (Linux wrapper), PowerShell 5.1+ (Windows native), PowerShell 7+ (cross-platform module logic)  
**Primary Dependencies**: 
- Windows: DISM (built-in), oscdimg (Windows ADK), PowerShell 5.1+
- Linux: Docker 20.10+ with Windows container support (required for DISM), genisoimage/xorriso, bash 5.0+
- Shared: JSON schema validator (ajv-cli or PowerShell-based), 7zip/p7zip
**Configuration**: JSON files - configurations.json (build settings with autounattend parameters), packages.json (post-install apps), schema.json (validation), presets/ (device-specific baseline configs)
**Testing**: Pester 5.x (PowerShell module testing), shellcheck (bash validation), manual VM validation (VirtualBox/QEMU)
**Logging**: Hybrid approach - Logger.psm1 wraps PowerShell native cmdlets (Write-Error, Write-Warning, Write-Information, Write-Verbose) on Windows, provides cross-platform abstraction with ERROR/WARN/INFO/DEBUG levels for Bash compatibility
**Target Platform**: 
- Build host: Windows 10/11 or Linux (Ubuntu 20.04+, Fedora 35+, Arch)
- Build artifact: Windows 11 bootable ISO
**Project Type**: Cross-platform build pipeline/automation tool  
**Performance Goals**: Build time <30min on 16GB RAM/SSD, peak memory usage ≤8GB, Image size <8GB, generated image RAM usage <2.5GB on first boot  
**Constraints**: Docker required for Linux builds (Windows Server Core container with DISM using mcr.microsoft.com/windows/servercore:ltsc2022), offline-capable after initial tool installation, handheld device RAM limitations (2.5GB target), build host RAM limit (8GB peak)  
**Scale/Scope**: Single-user build tool, configurable package removal lists, driver injection support, preset configurations with user override capability for device types
**Security**: Sensitive data detection during validation (warns on password/apikey/token patterns), no credential storage in configs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Configuration-Driven Automation (Principle I)

- [x] All user-facing customizations exposed via JSON configuration
  - Existing configurations.json and packages.json already in place
  - Will add schema.json for validation
- [x] No hard-coded values requiring code modification to change behavior
  - Current tiny11maker.ps1 uses JSON; will extend this pattern
- [x] Configuration schema documented
  - Will create comprehensive JSON schema with inline documentation

### Modular Component Architecture (Principle II)

- [x] Feature decomposed into discrete, independently testable modules
  - Platform detection module (detect-platform.sh/ps1)
  - Prerequisites validator (check-prereqs.sh/ps1)
  - Image builder orchestrator (build-wrapper.sh/ps1)
  - Platform-specific executors (build-windows.ps1, build-linux.sh)
- [x] Each module has single, well-defined responsibility
  - Clear separation: detection → validation → orchestration → execution
- [x] Clear interfaces between modules (parameters/return values)
  - Exit codes: 0=success, 1-10=specific errors
  - JSON output for machine-readable results
  - Shared configuration contract

### Script Idempotency & Safety (Principle III)

- [x] Operations are idempotent where feasible
  - Existing tiny11maker.ps1 creates temp directories; will enhance cleanup
  - Docker container rebuilds are idempotent
- [x] Prerequisites validated before destructive operations
  - Will add comprehensive prerequisite checking before ISO mounting
  - Disk space (20GB min), tool availability, ISO integrity (checksum) checks
  - Sensitive data pattern detection in config files (warns on password/apikey/token)
- [x] Rollback/cleanup procedures implemented
  - Partial rollback strategy: undo current failed stage only, preserve completed stages
  - Trap handlers for cleanup on interruption
  - Source ISO remains unchanged in all scenarios
  - Workspace cleanup module with stage tracking

### User Choice & Transparency (Principle IV)

- [x] All modifications clearly documented and logged
  - Will implement structured logging with timestamps
  - --verbose and --dry-run modes
- [x] Trade-offs (security/performance/footprint) documented
  - Configuration file comments will explain each option's impact
  - README documentation for common scenarios
- [x] Safe defaults for optional features
  - Conservative package removal list by default
  - Optional driver injection, OEM tools, security bypasses
- [x] No silent, irreversible modifications without user consent
  - All operations logged; --dry-run shows what will happen

### Performance & Resource Optimization (Principle V)

- [x] Optimizations are measurable with baseline comparisons
  - Will document default vs. optimized image RAM/disk usage
  - Build time benchmarks for different configs
- [x] Resource constraints of handheld devices considered
  - 2.5GB RAM target already in spec
  - Package removal focused on handheld use cases
- [x] No stability/security compromises without explicit opt-in
  - Security bypasses (TPM, Secure Boot) are opt-in via configuration

**GATE RESULT**: ✅ PASS - All constitutional principles aligned with design

## Project Structure

### Documentation (this feature)

```text
specs/001-cross-platform-build/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output - cross-platform research
├── data-model.md        # Phase 1 output - configuration schemas
├── quickstart.md        # Phase 1 output - user getting started guide
├── contracts/           # Phase 1 output - API/CLI contracts
│   ├── cli-interface.md
│   └── config-schema.json
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# Cross-platform build pipeline structure
tiny11-handheld/
├── build.sh                    # Linux entry point (bash wrapper)
├── build.ps1                   # Windows entry point (PowerShell 5.1+)
├── check-prereqs.sh            # Linux prerequisite checker
├── check-prereqs.ps1           # Windows prerequisite checker
├── configurations.json         # User build configuration (overrides preset)
├── packages.json               # Post-install application manifest
├── schema.json                 # Configuration validation schema
├── tiny11maker.ps1             # Legacy Windows-only script (maintained for compatibility)
├── postInstall.ps1             # Post-install automation
├── bootstrap.ps1               # Bootstrap/first-run script
├── autounattend.old.xml        # Original autounattend template (extracted for parameterization)
├── autounattend.xml            # Generated from config during build (if config changes)
│
├── modules/                    # PowerShell Core 7+ modules (cross-platform shared logic)
│   ├── Config.psm1             # Configuration loading and preset merging (shallow top-level merge)
│   ├── Validation.psm1         # Schema validation, path normalization, sensitive data detection
│   ├── Logger.psm1             # Hybrid logging (PowerShell verbs on Windows, ERROR/WARN/INFO/DEBUG abstraction)
│   ├── Platform.psm1           # Platform detection
│   ├── Autounattend.psm1       # Generate autounattend.xml from config (bypasses, computerName, productKey, timezone, locale)
│   └── Cleanup.psm1            # Workspace cleanup and partial rollback
│
├── platform/                   # Platform-specific implementations
│   ├── windows/
│   │   ├── ImageBuilder.psm1   # Windows native DISM operations
│   │   └── Prerequisites.ps1   # Windows-specific prereq checks
│   └── linux/
│       ├── docker-dism.sh      # Docker-based DISM wrapper (preferred, uses Windows Server Core ltsc2022)
│       ├── prerequisites.sh    # Linux-specific prereq checks (Docker 20.10+ required)
│       └── Dockerfile.dism     # Windows Server Core container with DISM (mcr.microsoft.com/windows/servercore:ltsc2022)
│
├── presets/                    # Pre-configured build templates (baseline defaults)
│   ├── rog-ally.json          # ROG Ally handheld preset
│   ├── handheld-default.json  # Generic handheld preset
│   └── desktop-minimal.json   # Minimal desktop preset
│   # Note: User config.json overrides preset (shallow merge at top-level keys)
│
├── configurations/             # Application-specific configurations
│   ├── memreduct/
│   ├── compactGUI/
│   └── everything/
│
├── docs/                       # End-user documentation
│   ├── README.md
│   ├── CONFIGURATION.md        # Detailed config options
│   ├── TROUBLESHOOTING.md
│   └── CONTRIBUTING.md
│
└── .specify/                   # Development/spec toolkit
    ├── memory/constitution.md
    ├── templates/
    └── scripts/
```

**Structure Decision**: Hybrid PowerShell/Bash architecture chosen to:
1. Maintain existing Windows-native PowerShell codebase (tiny11maker.ps1)
2. Add cross-platform layer via PowerShell Core 7+ modules
3. Provide platform-specific wrappers (build.sh for Linux, build.ps1 for Windows)
4. Use Docker with Windows Server Core (DISM) on Linux for functional equivalence with native Windows DISM
5. Follow Constitution Principle II (Modular Component Architecture)
6. Implement hybrid logging that respects PowerShell conventions on Windows while providing cross-platform abstraction
7. Enable preset configurations with user override (shallow merge strategy at top-level keys)

## Complexity Tracking

> **No violations** - All constitution principles satisfied

The design intentionally maintains moderate complexity due to:
- Cross-platform requirement necessitates platform-specific code paths
- Docker container adds infrastructure but enables true cross-platform DISM support
- Hybrid PowerShell/Bash approach justified by existing codebase and cross-platform goals

**Simplifications considered**:
- Pure PowerShell Core approach: Rejected - DISM not available on Linux even with PS Core
- Pure Bash approach: Rejected - would require complete rewrite, loss of Windows-native efficiency
- Cloud-based build service: Rejected - violates offline-capable requirement

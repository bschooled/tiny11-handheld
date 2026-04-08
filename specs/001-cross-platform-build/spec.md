# Feature Specification: Cross-Platform Build Support

**Feature Branch**: `001-cross-platform-build`  
**Created**: 2026-01-01  
**Status**: Draft  
**Input**: User description: "This repository builds an optimized Windows 11 image. Build out scripts and supporting tooling so that this can be built from either a Windows or Linux desktop. It should be extensible, have a clear central location for changing configurations."

## Clarifications

### Session 2026-01-01

- Q: When FR-010 states "rollback capability if any build step fails," what is the extent of rollback required? → A: Partial rollback - Undo current stage only, preserve earlier completed stages for retry
- Q: FR-011 requires logging "with timestamps and severity levels." What severity levels should the logging system support? → A: 4 levels: ERROR, WARN, INFO, DEBUG
- Q: FR-011 specifies custom logging levels (ERROR/WARN/INFO/DEBUG) but the constitution requires PowerShell conventions. Since this is a cross-platform tool with Bash components, which approach should the logging system use? → A: Hybrid: PowerShell verbs on Windows (Write-Error, Write-Warning, Write-Information, Write-Verbose), custom levels for cross-platform compatibility
- Q: SC-005 states "Build failures result in complete rollback" but FR-010 (clarified) specifies "partial rollback" (preserve earlier stages). Which is correct for the success criteria? → A: Partial rollback (align SC-005 with FR-010)
- Q: FR-009 requires "generate autounattend.xml dynamically based on configuration settings" and T044 implements this, but there's no specification of which configuration fields map to which autounattend.xml settings. What should be configurable in autounattend.xml? → A: TPM/SecureBoot/RAM bypasses + computer name + product key (if provided) + timezone + locale - parameterized from existing autounattend.xml into JSON config, regenerated during build if config changes
- Q: FR-015 states the system must produce "identical functional output" across platforms. What does "functional output" mean for cross-platform verification? → A: Package/feature equivalence (same packages removed, same features enabled, same registry settings)
- Q: SC-002 specifies "build process completes in under 30 minutes," but there's no constraint on memory usage during the build. What is the maximum RAM the build process should consume? → A: 8GB maximum RAM
- Q: The spec doesn't address whether configuration files might contain sensitive data (API keys, credentials, personal information). Should the system handle or warn about sensitive data in configurations? → A: Warn about sensitive data patterns (detect "password", "apikey", "token" in keys/values)
- Q: FR-016 mentions configuration presets for different device types, but doesn't specify how presets interact with user-specified configurations. How should preset loading work? → A: User config overrides preset (preset as defaults) - presets provide baseline, user can selectively override without modifying preset file
- Q: FR-007 states the system "MUST use platform-appropriate tools: DISM on Windows, wimlib-imagex on Linux" but doesn't specify fallback behavior. On Linux, should the system support Docker with Windows Server Core containers (providing native DISM) as an alternative to wimlib? → A: Docker DISM preferred on Linux (require Docker, use native DISM in Windows Server Core container for better functional equivalence)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Build Windows 11 Image from Linux (Priority: P1)

A developer using a Linux workstation wants to build a custom Windows 11 image for their handheld device without needing access to a Windows machine. They configure their desired packages and drivers via JSON files, run the build script, and obtain a bootable ISO.

**Why this priority**: This is the core value proposition - enabling Linux users to build Windows images expands the user base significantly and removes the Windows-only limitation.

**Independent Test**: Can be fully tested by running the build script on a Linux machine (Ubuntu/Fedora/Arch) with a valid Windows 11 ISO and verifying a bootable image is produced.

**Acceptance Scenarios**:

1. **Given** a Linux machine with necessary dependencies installed, **When** user runs the build script with default configuration, **Then** a Windows 11 ISO is generated successfully
2. **Given** a valid configurations.json file, **When** user executes the build on Linux, **Then** only selected packages are removed from the image
3. **Given** driver files in the specified directory, **When** build runs on Linux, **Then** drivers are injected into the Windows image correctly
4. **Given** an incomplete or missing dependency, **When** build starts, **Then** clear error message indicates which tool is missing and how to install it

---

### User Story 2 - Build Windows 11 Image from Windows (Priority: P1)

A developer using a Windows workstation wants to build a custom Windows 11 image. They use the same JSON configuration files and build commands as Linux users, ensuring consistent results across platforms.

**Why this priority**: Maintaining Windows support is essential since many users already have working Windows-based workflows. Cross-platform consistency is key.

**Independent Test**: Can be fully tested by running the build script on Windows 10/11 with PowerShell and verifying the same configuration produces identical results as Linux.

**Acceptance Scenarios**:

1. **Given** a Windows machine with PowerShell 5.1+, **When** user runs the build script with default configuration, **Then** a Windows 11 ISO is generated successfully
2. **Given** the same configurations.json used on Linux, **When** build executes on Windows, **Then** output ISO has identical package removals and configurations
3. **Given** both Linux and Windows builds with same config, **When** comparing package lists, enabled features, and registry settings, **Then** functional equivalence is verified (same packages removed, same features enabled, same settings applied)

---

### User Story 3 - Centralized Configuration Management (Priority: P2)

A user wants to customize their Windows 11 build by editing simple JSON files without touching any script code. They modify configurations.json to change package removal settings, packages.json to add/remove software installations, and optionally create preset configurations for different device types.

**Why this priority**: Configuration-driven design (Constitution Principle I) enables non-developers to safely customize builds and supports the extensibility requirement.

**Independent Test**: Can be fully tested by modifying JSON files only, running the build, and verifying changes are applied without any script modifications.

**Acceptance Scenarios**:

1. **Given** configurations.json with specific packages marked for removal, **When** build executes, **Then** only those packages are removed from the image
2. **Given** packages.json with application installation entries, **When** post-install runs, **Then** all specified applications are installed on first boot
3. **Given** invalid JSON syntax in configuration file, **When** build starts, **Then** validation fails with clear error message indicating line/column of JSON error
4. **Given** a new preset configuration file (e.g., configurations/rog-ally.json), **When** user specifies the preset, **Then** build applies all preset-specific settings

---

### User Story 4 - Extensible Tool Architecture (Priority: P3)

A developer wants to add support for a new feature (e.g., additional driver injection source, new post-install customization) by creating a new module without modifying core build scripts. The module follows documented interfaces and is automatically discovered by the build system.

**Why this priority**: Extensibility enables community contributions and future enhancements without increasing complexity of core codebase (Constitution Principle II).

**Independent Test**: Can be fully tested by creating a new module following the documented interface, placing it in the modules directory, and verifying it's called during the build process.

**Acceptance Scenarios**:

1. **Given** a new module file in the modules/ directory following the standard interface, **When** build executes, **Then** module is discovered and executed at the appropriate build stage
2. **Given** module documentation with interface requirements, **When** developer creates a compliant module, **Then** no modifications to core scripts are needed
3. **Given** a module that fails during execution, **When** error occurs, **Then** build rolls back changes and reports module-specific error without corrupting the image

---

### Edge Cases

- What happens when the source Windows ISO is corrupted or has incorrect checksum?
- How does the system handle insufficient disk space during image building?
- What occurs when a required dependency (DISM, oscdimg, genisoimage) is not available on the system?
- How does the build behave when JSON configuration contains references to non-existent packages?
- What happens when driver files are incompatible with the Windows version being built?
- How does the system handle concurrent builds in the same directory?
- What occurs when the build process is interrupted (Ctrl+C, system crash)? Partial rollback preserves completed stages; user can resume or clean workspace manually.
- How does the system behave when autounattend.xml contains invalid XML?
- What happens if configuration files contain sensitive data (API keys, passwords)? System warns user during validation but does not block build; user responsible for security.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support building Windows 11 images on both Linux (Ubuntu 20.04+, Fedora 35+, Arch) and Windows (10/11) platforms
- **FR-002**: System MUST use declarative JSON configuration files for all customization options (package removal, software installation, image settings)
- **FR-003**: System MUST validate all configuration files against schemas before beginning any destructive operations
- **FR-004**: System MUST verify Windows 11 source ISO integrity via checksum before mounting
- **FR-005**: System MUST check for required dependencies (DISM/wimlib, oscdimg/genisoimage, PowerShell/bash) at build start and report missing tools with installation instructions
- **FR-006**: System MUST provide a unified command-line interface that works identically on both Windows and Linux
- **FR-007**: System MUST use platform-appropriate tools for WIM manipulation: native DISM on Windows, Docker with Windows Server Core containers running DISM on Linux (preferred for functional equivalence). Docker 20.10+ with Windows container support required on Linux. System MUST use mcr.microsoft.com/windows/servercore:ltsc2022 base image with DISM module available.
- **FR-008**: System MUST support driver injection from a specified directory with validation of driver compatibility
- **FR-009**: System MUST generate autounattend.xml dynamically from configuration settings during build. Configurable fields include: security bypasses (bypassTPM, bypassSecureBoot, bypassRAMCheck from features section), computer name, product key (optional), timezone, locale settings. Template extracted from existing autounattend.xml; regenerated only if configuration changes.
- **FR-010**: System MUST provide partial rollback capability if any build step fails: undo operations of the current failed stage only while preserving earlier completed stages (ISO extraction, WIM mounting), enabling faster retry without full workspace deletion. Source ISO remains unchanged.
- **FR-011**: System MUST log all operations with timestamps and severity levels to both console and log file. Console displays INFO and above by default; log file captures all levels. Logger.psm1 MUST use PowerShell native cmdlets on Windows (Write-Error, Write-Warning, Write-Information, Write-Verbose) while providing cross-platform abstraction with standardized levels (ERROR, WARN, INFO, DEBUG) for Bash compatibility.
- **FR-012**: System MUST validate available disk space before operations (minimum 20GB free recommended)
- **FR-013**: System MUST support modular architecture where new features can be added as separate modules without core script modification
- **FR-014**: System MUST document all configuration file options with descriptions, valid values, and implications
- **FR-015**: System MUST produce functionally equivalent output regardless of build platform: same packages removed, same Windows features enabled/disabled, same registry settings applied, and same drivers injected. Note: Byte-for-byte ISO identity is not required due to platform-specific compression/tooling differences.
- **FR-016**: System MUST support multiple configuration presets for different device types (handheld devices, desktops, tablets). Presets provide baseline defaults; user-specified configuration values override corresponding preset values without modifying preset file. Merge strategy: shallow merge at top-level keys (e.g., user's "features" replaces preset's "features" entirely, not field-by-field).
- **FR-017**: System MUST implement idempotent operations where running the same build with same inputs produces same output
- **FR-018**: System MUST provide -WhatIf/--dry-run mode showing what would be done without making changes
- **FR-019**: System MUST limit peak memory usage to 8GB maximum during build operations to support typical 16GB developer workstations
- **FR-020**: System MUST scan configuration files during validation and issue warnings (WARN level) when detecting potential sensitive data patterns (key/value names containing "password", "apikey", "api_key", "token", "secret", "credential") to prevent accidental credential exposure in version control

### Key Entities

- **Build Configuration**: JSON file containing package removal lists, security settings, performance optimizations, and feature toggles
- **Package Manifest**: JSON file listing applications to install post-deployment with download URLs, installation arguments, and dependencies
- **Source ISO**: Original Windows 11 installation media used as base for customization
- **Target ISO**: Generated bootable Windows 11 image with all customizations applied
- **Driver Package**: Collection of device drivers to be injected into the Windows image
- **Build Module**: Self-contained script component implementing a specific build stage or feature
- **Autounattend Configuration**: Settings that control unattended Windows installation behavior
- **Build Workspace**: Temporary directory containing mounted images, extracted files, and intermediate build artifacts

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can successfully build a bootable Windows 11 ISO on both Linux and Windows platforms using the same configuration files
- **SC-002**: Build process completes in under 30 minutes on hardware with 16GB RAM and SSD (for typical configurations), consuming no more than 8GB RAM at peak
- **SC-003**: Generated Windows 11 images consume less than 2.5GB of RAM on first boot with default optimizations
- **SC-004**: 100% of configuration changes can be made via JSON files without any script modification
- **SC-005**: Build failures result in partial rollback (failed stage only) with no corruption of source ISO; completed stages preserved for retry
- **SC-006**: All required dependencies are detected and reported within 10 seconds of starting build
- **SC-007**: Configuration validation detects 100% of JSON syntax errors before any file modifications occur
- **SC-008**: Documentation covers all JSON configuration options with clear explanations and examples
- **SC-009**: Users can create custom build modules by following documented interface without touching core scripts

## Assumptions

- Users have legitimate Windows 11 ISO files obtained through official Microsoft channels
- Linux users have sudo/root access for installing required dependencies (wimlib, genisoimage, etc.)
- Windows users have PowerShell 5.1 or later available
- Adequate disk space (minimum 20GB free) is available for build operations
- Users understand basic command-line operations and can follow installation instructions
- Default package removal and optimization settings provide reasonable balance of functionality and performance for handheld devices
- Driver packages provided by users are compatible with the Windows version being built
- Build process has network access for validating checksums and downloading tools if needed during setup

## Out of Scope

- Automatic Windows ISO downloading (users must provide their own legitimate ISO)
- GUI interface for configuration (command-line only)
- Cross-compilation (building x86 images on ARM, or vice versa)
- Support for Windows versions other than Windows 11
- Built-in driver repository or automated driver downloading
- Real-time build progress visualization beyond console logging
- Multi-ISO batch processing
- Automated testing of generated ISOs (users must test in VM or hardware)
- Integration with cloud storage or build services
- Automatic Windows activation or license management

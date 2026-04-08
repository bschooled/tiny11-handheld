# Tasks: Cross-Platform Build Support

**Feature**: 001-cross-platform-build  
**Input**: Design documents from `/specs/001-cross-platform-build/`  
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/cli-interface.md

**Tests**: No test tasks included (not requested in specification)

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

**Clarifications Applied** (2026-01-01):
- Docker DISM required on Linux (FR-007) - removed wimlib tasks
- Hybrid logging with PowerShell verbs (FR-011)
- Partial rollback strategy (FR-010)
- autounattend.xml parameterization (FR-009)
- Preset merge strategy - shallow top-level merge (FR-016)
- 8GB memory limit enforcement (FR-019)
- Sensitive data pattern detection (FR-020)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure that both platforms need

- [X] T001 Create project directory structure per plan.md (modules/, platform/, presets/, docs/)
- [X] T002 [P] Create JSON schema file at schema.json with validation rules from data-model.md
- [X] T003 [P] Create preset configuration files (presets/handheld-default.json, presets/rog-ally.json, presets/desktop-minimal.json)
- [X] T004 [P] Update .gitignore to exclude build artifacts (output/, *.log, workspace/)
- [X] T005 [P] Create docs/README.md with project overview and architecture diagram
- [X] T006 [P] Create docs/CONFIGURATION.md documenting all configuration options from schema.json

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T007 Implement Platform.psm1 module with Get-BuildPlatform function in modules/Platform.psm1
- [X] T008 [P] Implement Logger.psm1 module with hybrid logging (PowerShell verbs on Windows, ERROR/WARN/INFO/DEBUG abstraction for Bash) in modules/Logger.psm1
- [X] T009 [P] Implement Config.psm1 module with Import-BuildConfiguration and preset merging (shallow top-level key merge) in modules/Config.psm1
- [X] T010 [P] Implement Validation.psm1 module with schema validation, path normalization, and sensitive data detection (password/apikey/token patterns) in modules/Validation.psm1
- [X] T011 [P] Implement Cleanup.psm1 module with workspace cleanup and partial rollback (preserve completed stages) in modules/Cleanup.psm1
- [X] T012 Create shared error codes and ErrorDetail structure in modules/Common.psm1
- [X] T013 [P] Implement Autounattend.psm1 module to generate autounattend.xml from config (bypasses, computerName, productKey, timezone, locale) in modules/Autounattend.psm1
- [X] T014 [P] Create Windows prerequisite checker at check-prereqs.ps1 with DISM/oscdimg/7-Zip checks
- [X] T015 [P] Create Linux prerequisite checker at check-prereqs.sh with Docker 20.10+/genisoimage/p7zip checks

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Build Windows 11 Image from Linux (Priority: P1) 🎯 MVP

**Goal**: Enable Linux users to build custom Windows 11 images using Docker with Windows Server Core DISM

**Independent Test**: Run build.sh on Ubuntu 22.04 with valid Windows 11 ISO and verify bootable ISO is produced

### Implementation for User Story 1

- [X] T016 [P] [US1] Create Dockerfile.dism at platform/linux/Dockerfile.dism with Windows Server Core ltsc2022 base image and DISM module
- [X] T017 [P] [US1] Create docker-dism.sh at platform/linux/docker-dism.sh with Docker container orchestration for DISM operations
- [X] T018 [P] [US1] Create prerequisites.sh at platform/linux/prerequisites.sh with Docker 20.10+ and Windows container support checks
- [X] T019 [US1] Create Linux entry point build.sh with platform detection and prerequisite checking
- [X] T020 [US1] Implement ISO extraction logic in build.sh using p7zip
- [X] T021 [US1] Implement WIM mounting via Docker DISM in docker-dism.sh
- [X] T022 [US1] Implement package removal operations via Docker DISM in docker-dism.sh
- [X] T023 [US1] Implement driver injection via Docker DISM in docker-dism.sh
- [X] T024 [US1] Implement autounattend.xml generation from config (call Autounattend.psm1) in build.sh
- [X] T025 [US1] Implement ISO creation using genisoimage/xorriso in build.sh
- [X] T026 [US1] Add error handling and partial rollback (preserve completed stages) for Linux build failures
- [X] T027 [US1] Implement memory usage monitoring to enforce 8GB limit (FR-019)
- [X] T028 [US1] Add logging integration with Logger.psm1 module from build.sh

**Checkpoint**: User Story 1 complete - Linux builds functional with Docker DISM support

---

## Phase 4: User Story 2 - Build Windows 11 Image from Windows (Priority: P1) 🎯 MVP

**Goal**: Maintain Windows native build capability with same configuration files as Linux

**Independent Test**: Run build.ps1 on Windows 11 with PowerShell 5.1+ and verify functional equivalence with Linux build

### Implementation for User Story 2

- [X] T029 [P] [US2] Create ImageBuilder.psm1 at platform/windows/ImageBuilder.psm1 with native DISM operations
- [X] T030 [P] [US2] Create Prerequisites.ps1 at platform/windows/Prerequisites.ps1 with Windows-specific checks
- [X] T031 [US2] Create Windows entry point build.ps1 with platform detection and prerequisite checking
- [X] T032 [US2] Implement ISO extraction logic in build.ps1 using 7-Zip
- [X] T033 [US2] Implement WIM mounting via native DISM in ImageBuilder.psm1
- [X] T034 [US2] Implement package removal operations via native DISM in ImageBuilder.psm1
- [X] T035 [US2] Implement driver injection via native DISM in ImageBuilder.psm1
- [X] T036 [US2] Implement autounattend.xml generation from config (call Autounattend.psm1) in build.ps1
- [X] T037 [US2] Implement ISO creation using oscdimg in build.ps1
- [X] T038 [US2] Add error handling and partial rollback (preserve completed stages) for Windows build failures
- [X] T039 [US2] Implement memory usage monitoring to enforce 8GB limit (FR-019)
- [X] T040 [US2] Add logging integration with Logger.psm1 module from build.ps1
- [ ] T041 [US2] Implement functional equivalence verification script (compare package lists, features, registry settings)

**Checkpoint**: User Story 2 complete - Windows builds functional with native DISM, cross-platform equivalence verified

---

## Phase 5: User Story 3 - Centralized Configuration Management (Priority: P2)

**Goal**: Enable all customizations via JSON files without code changes, support preset configurations with user overrides

**Independent Test**: Modify only configurations.json and packages.json, run build, verify changes applied without script edits

### Implementation for User Story 3

- [ ] T042 [P] [US3] Enhance schema.json to include all configuration options from data-model.md including unattended section
- [ ] T043 [P] [US3] Add JSON Schema validation to Config.psm1 Import-BuildConfiguration function
- [ ] T044 [US3] Implement configuration preset loading with shallow top-level merge in Config.psm1 (user config overrides preset)
- [ ] T045 [US3] Add path normalization for cross-platform compatibility in Validation.psm1
- [ ] T046 [US3] Implement autounattend.xml template extraction from autounattend.old.xml in Autounattend.psm1
- [ ] T047 [US3] Implement autounattend.xml regeneration logic (only if config changes) in Autounattend.psm1
- [ ] T048 [US3] Add validation error reporting with line/column numbers for JSON syntax errors
- [ ] T049 [US3] Implement --validate-only mode in build.sh and build.ps1
- [ ] T050 [US3] Create configuration migration utility for users with Windows-specific paths
- [ ] T051 [P] [US3] Update docs/CONFIGURATION.md with all available options, preset merge behavior, and examples
- [ ] T052 [P] [US3] Create example configurations for common scenarios in presets/ with device-specific settings

**Checkpoint**: User Story 3 complete - All build options configurable via JSON, presets support user override, validation prevents errors

---

## Phase 6: User Story 4 - Extensible Tool Architecture (Priority: P3)

**Goal**: Enable custom modules without modifying core build scripts

**Independent Test**: Create new module following interface documentation, place in modules/, verify auto-discovery and execution

### Implementation for User Story 4

- [ ] T053 [P] [US4] Create module interface documentation at docs/MODULE_INTERFACE.md
- [ ] T054 [US4] Implement module discovery mechanism in build.sh and build.ps1
- [ ] T055 [US4] Add module lifecycle hooks (pre-build, post-package-removal, pre-iso-creation, post-build)
- [ ] T056 [US4] Implement module error handling with partial rollback in Cleanup.psm1
- [ ] T057 [US4] Add module validation (check for required functions/parameters)
- [ ] T058 [P] [US4] Create example custom module at modules/examples/CustomDriverSource.psm1
- [ ] T059 [P] [US4] Update docs/CONTRIBUTING.md with module development guide
- [ ] T060 [US4] Implement module logging integration with hybrid Logger.psm1 (modules can write to build log)

**Checkpoint**: User Story 4 complete - Extensible architecture supports community contributions

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final enhancements, performance optimization, and documentation completion

- [ ] T061 [P] Implement --dry-run mode showing all planned operations without execution (FR-018)
- [ ] T062 [P] Add --parallel flag support for parallelizable operations (ISO extraction + checksum validation)
- [ ] T063 [P] Implement disk space validation before build starts (FR-012 - minimum 20GB)
- [ ] T064 [P] Add ISO checksum verification before extraction (FR-004)
- [ ] T065 [P] Implement build time tracking and reporting (<30 min target from SC-002)
- [ ] T066 [P] Create docs/TROUBLESHOOTING.md with common issues and solutions
- [ ] T067 [P] Add --keep-workspace flag implementation for debugging failed builds
- [ ] T068 [P] Implement --verbose flag for DEBUG level logging
- [ ] T069 Optimize Docker image build for Linux (multi-stage Dockerfile.dism, layer caching)
- [ ] T070 [P] Create quickstart guide at docs/QUICKSTART.md with platform-specific instructions
- [ ] T071 [P] Add example build commands for common scenarios to README.md
- [ ] T072 Test build on Ubuntu 22.04, Fedora 39, Arch Linux (User Story 1 validation)
- [ ] T073 Test build on Windows 10 and Windows 11 (User Story 2 validation)
- [ ] T074 Verify functional equivalence between Linux and Windows builds (FR-015 - package/feature/registry parity)
- [ ] T075 Benchmark build time and memory usage (SC-002 <30min, FR-019 ≤8GB peak)
- [ ] T076 Test generated ISO RAM usage on first boot (<2.5GB target from SC-003)
- [ ] T077 [P] Add CI/CD configuration file (.github/workflows/build-test.yml) for automated testing
- [ ] T078 [P] Document hybrid logging approach in docs/ARCHITECTURE.md (PowerShell verbs + cross-platform abstraction)

**Checkpoint**: All features complete, tested, and documented

---

## Implementation Strategy

### MVP Definition (Recommended First Delivery)

**Scope**: User Story 1 (Linux build) + User Story 2 (Windows build)  
**Tasks**: T001-T039 (Phases 1-4)  
**Outcome**: Cross-platform builds working with basic configuration support

This MVP proves the core technical approach (Docker/wimlib for Linux, native DISM for Windows) and delivers immediate value.

### Incremental Delivery Order

1. **Phase 1-2** (T001-T015): Foundation - enables all subsequent work
2. **Phase 3** (T016-T027): Linux build capability - high-value feature
3. **Phase 4** (T028-T039): Windows build capability - completes core functionality
4. **Phase 5** (T040-T049): Configuration enhancements - improves usability
5. **Phase 6** (T050-T057): Extensibility - enables community contributions
6. **Phase 7** (T058-T074): Polish and testing - production readiness

### Parallel Execution Opportunities

**Within Phase 1 (Setup)**: T002, T003, T004, T005, T006 can run in parallel  
**Within Phase 2 (Foundational)**: T008, T009, T010, T011, T013, T014, T015 can run in parallel after T007  
**Within Phase 3 (US1)**: T016, T017, T018 can run in parallel  
**Within Phase 4 (US2)**: T029, T030 can run in parallel  
**Within Phase 5 (US3)**: T042, T043, T051, T052 can run in parallel  
**Within Phase 6 (US4)**: T053, T058, T059 can run in parallel  
**Within Phase 7 (Polish)**: Most tasks (T061-T071, T077, T078) can run in parallel except T072-T076 (sequential testing)

**Cross-Story Parallelism**: After Phase 2 complete, Phase 3 (US1) and Phase 4 (US2) can be developed in parallel by different team members since they work on different file paths.

---

## Dependencies

### User Story Completion Order

```text
Phase 1 (Setup)
    ↓
Phase 2 (Foundational) ← MUST complete before any user story
    ↓
    ├─→ Phase 3 (US1: Linux Build) ← Can run in parallel
    └─→ Phase 4 (US2: Windows Build) ← Can run in parallel
           ↓
    Both US1 and US2 complete
           ↓
    Phase 5 (US3: Configuration) ← Depends on working builds
           ↓
    Phase 6 (US4: Extensibility) ← Depends on configuration system
           ↓
    Phase 7 (Polish) ← Final integration
```

### Critical Path

T001 → T007 → T008-T015 → T019 → T021 → T022 → T024 → T030 → T032 → T033 → T035 → T042 → T051 → Testing

**Estimated Duration**:

- Phase 1: 2-3 hours
- Phase 2: 8-10 hours
- Phase 3 (US1): 12-16 hours
- Phase 4 (US2): 10-12 hours
- Phase 5 (US3): 6-8 hours
- Phase 6 (US4): 6-8 hours
- Phase 7 (Polish): 8-10 hours
- **Total**: ~52-67 hours of development time

With 2 developers working in parallel: ~30-40 hours elapsed time

---

## Task Count Summary

- **Total Tasks**: 78
- **Phase 1 (Setup)**: 6 tasks
- **Phase 2 (Foundational)**: 9 tasks (includes Autounattend.psm1)
- **Phase 3 (US1 - Linux Build)**: 13 tasks (removed wimlib, added autounattend generation)
- **Phase 4 (US2 - Windows Build)**: 13 tasks (added autounattend generation)
- **Phase 5 (US3 - Configuration)**: 11 tasks (added preset merge, autounattend template extraction)
- **Phase 6 (US4 - Extensibility)**: 8 tasks
- **Phase 7 (Polish)**: 18 tasks (added architecture documentation)
- **Parallelizable Tasks**: 34 tasks marked with [P]

---

## Independent Test Criteria by User Story

### User Story 1 (Linux Build)

**Test**: On Ubuntu 22.04, run `./build.sh --config configurations.json`, verify:

- Prerequisites check passes (Docker 20.10+, genisoimage, p7zip)
- Docker container builds from Dockerfile.dism with Windows Server Core ltsc2022
- Docker DISM operations execute successfully
- ISO extraction completes
- Package removal executes via Docker DISM
- autounattend.xml generated from config (bypasses, timezone, locale)
- Output ISO created in output/
- ISO boots in QEMU/VirtualBox
- Memory usage stays ≤8GB peak

### User Story 2 (Windows Build)

**Test**: On Windows 11, run `.\build.ps1 -Config configurations.json`, verify:

- Prerequisites check passes (DISM, oscdimg, 7-Zip available)
- ISO extraction completes
- Native DISM operations execute
- autounattend.xml generated from config (bypasses, timezone, locale)
- Output ISO created in output/
- ISO boots in Hyper-V/VirtualBox
- Memory usage stays ≤8GB peak
- Compare with US1 output: functional equivalence (same packages removed, same features configured, same registry settings)

### User Story 3 (Configuration)

**Test**: Edit only configurations.json to change packages, timezone, and bypasses, run build, verify:

- JSON validation passes with schema.json
- Preset configuration loads correctly (if --preset specified)
- User config overrides preset values (shallow top-level merge)
- Only specified packages removed
- autounattend.xml regenerated with new timezone/locale/bypasses
- Sensitive data patterns detected (warns if password/apikey/token in config)
- No script modifications needed
- Invalid JSON detected with line/column error

### User Story 4 (Extensibility)

**Test**: Create new module CustomDriverSource.psm1, place in modules/, run build, verify:

- Module discovered automatically
- Module executed at appropriate lifecycle hook
- Module can use hybrid Logger.psm1 (PowerShell verbs on Windows, ERROR/WARN/INFO/DEBUG on Linux)
- Module error triggers partial rollback (preserves completed stages)
- Core scripts unchanged

---

## Format Validation

✅ All tasks follow required format: `- [ ] [TaskID] [P?] [Story?] Description with file path`  
✅ Task IDs sequential (T001-T078)  
✅ [P] markers only on parallelizable tasks (different files, no dependencies)  
✅ [Story] labels present for US phases only (US1, US2, US3, US4)  
✅ No [Story] labels on Setup, Foundational, or Polish phases  
✅ Exact file paths included in task descriptions  
✅ Tasks organized by user story for independent implementation  
✅ Each user story phase has independent test criteria  
✅ Dependencies section shows story completion order  
✅ Clarifications from spec.md integrated (Docker DISM, hybrid logging, partial rollback, autounattend parameterization, preset merge, memory limits, sensitive data detection)  
✅ Parallel execution examples provided per phase

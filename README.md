# tiny11-handheld

Cross-platform Windows 11 image customization toolkit focused on handheld and low-footprint installs.

This repository builds a customized Windows 11 ISO from a legitimate source ISO using JSON-driven configuration, modular scripts, and unattended install generation.

## Build Entry Points

- Linux: `platform/linux/build.sh`
- Windows: `platform/windows/build.ps1`

## Quick Start

### Linux

```bash
./platform/linux/build.sh --source ./Win11.iso --preset ./presets/handheld.json
```

Validation-mode build (use known-good template unattended XML):

```bash
./platform/linux/build.sh --source ./Win11.iso --validation
```

### Windows

```powershell
.\platform\windows\build.ps1 -SourceIso .\Win11.iso -PresetPath .\presets\handheld.json
```

## Configuration

- Presets live in `presets/`
- Schema is `schema.json`
- Optional script/config inputs live in `scripts/`

## Repository Layout

- `platform/`: OS-specific build orchestration
- `modules/`: shared PowerShell modules (config, validation, logging, unattended generation)
- `presets/`: build profiles
- `templates/`: unattended and preset schema templates
- `scripts/`: utility and post-install scripts
- `docs/`: all project documentation except this README

## Logging and Artifacts

- Build logs are written under `output/logs/`
- Build workspaces and generated artifacts are gitignored
- Source ISOs are never committed

## Validation Utilities

- Validation scripts are in `scripts/validation/`
- Built-in post-install verification script: `scripts/validation/verify-settings.ps1`

## Notes

- Driver injection support differs by platform. See [docs/DRIVER_INJECTION_LINUX.md](docs/DRIVER_INJECTION_LINUX.md).
- Additional historical/reorg notes are under `docs/notes/`.


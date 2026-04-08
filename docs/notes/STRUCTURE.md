# Repository Structure

## Overview
This repository has been reorganized for clarity and maintainability. All configuration is template-based and schema-driven.

## Directory Structure

```
tiny11-handheld/
├── templates/              # Source of truth - Schema templates
│   ├── autounattend/
│   │   └── schema.xml      # Autounattend.xml template with all options
│   └── presets/
│       └── schema.json     # Preset schema showing all available options
│
├── presets/                # Active preset configurations
│   ├── ultra-minimal.json  # Absolute minimum (TPM bypass + user only)
│   ├── minimal-desktop.json# Lightweight desktop with privacy tweaks
│   └── handheld.json       # Optimized for gaming handhelds
│
├── platform/linux/
│   ├── build.sh            # Main build script
│   ├── lib/                # Modular function libraries
│   │   ├── template-functions.sh    # Template loading/population
│   │   ├── validation-functions.sh  # Input validation
│   │   └── cleanup-functions.sh     # Cleanup utilities
│   └── generate-autounattend.ps1    # PowerShell autounattend generator
│
├── modules/                # PowerShell modules
│   ├── Autounattend.psm1   # Autounattend XML generation
│   ├── Logger.psm1         # Logging utilities
│   └── ScriptBuilder.psm1  # Script generation helpers
│
├── docs/                   # Documentation
│   ├── BOOT_FAILURE_ANALYSIS.md
│   ├── BOOT_FAILURE_FIX.md
│   └── PRESET_SCHEMA.md
│
├── archive/                # Deprecated/old files
│   ├── autounattend.*.xml  # Old autounattend variants
│   └── *.json              # Old preset files
│
├── output/                 # Build outputs (ISOs, logs)
└── workspace/              # Temporary build workspace (auto-created)
```

## Template System

### How It Works

1. **Schema Templates** (in `templates/`) define ALL available options with documentation
2. **Preset Files** (in `presets/`) contain ONLY the options you want to change
3. **Build Process** merges preset with schema defaults and generates final files

### Autounattend Template

`templates/autounattend/schema.xml` contains:
- Template variables: `{{LOCALE}}`, `{{USERNAME}}`, etc.
- Optional blocks: `{{BYPASS_COMMANDS}}`, `{{DISK_CONFIG}}`, etc.
- Full documentation of every pass and component

### Preset Schema

`templates/presets/schema.json` documents:
- All configuration options with descriptions
- Possible values for each field
- Examples and best practices
- Default values

## Usage

### Quick Start

```bash
# Build with ultra-minimal preset (recommended for testing)
./platform/linux/build.sh --preset ./presets/ultra-minimal.json --source Win11.iso

# Build with minimal desktop preset
./platform/linux/build.sh --preset ./presets/minimal-desktop.json --source Win11.iso

# Build with handheld gaming preset
./platform/linux/build.sh --preset ./presets/handheld.json --source Win11.iso
```

### Creating Custom Presets

1. **Copy a template:**
   ```bash
   cp presets/minimal-desktop.json presets/my-custom.json
   ```

2. **Edit your preset:**
   - Reference `templates/presets/schema.json` for all available options
   - Only include options you want to change (not defaults)
   - Add meaningful metadata (name, description)

3. **Build with your preset:**
   ```bash
   ./platform/linux/build.sh --preset ./presets/my-custom.json --source Win11.iso
   ```

## File Responsibilities

### Templates (Source of Truth)

- **`templates/autounattend/schema.xml`**
  - Defines autounattend.xml structure
  - Shows ALL possible configuration passes and components
  - Used as base for generation

- **`templates/presets/schema.json`**
  - Documents all preset options
  - Provides examples and defaults
  - Reference for creating custom presets

### Presets (User Configuration)

- **`ultra-minimal.json`** - Bare minimum for testing
  - Only TPM bypass and user account
  - NO customizations
  - Best for troubleshooting

- **`minimal-desktop.json`** - Balanced desktop config
  - Essential privacy settings
  - Bloatware removal
  - UI improvements
  - Good default for most users

- **`handheld.json`** - Gaming handheld optimized
  - Aggressive optimization
  - Performance tweaks
  - Storage savings
  - For Steam Deck, ROG Ally, etc.

### Build Scripts

- **`platform/linux/build.sh`** - Main orchestrator
  - Coordinates build process
  - Sources modular libraries
  - Handles error cleanup

- **`platform/linux/lib/*.sh`** - Modular functions
  - `template-functions.sh` - Template loading
  - `validation-functions.sh` - Input validation
  - `cleanup-functions.sh` - Resource cleanup

### Modules

- **`modules/Autounattend.psm1`** - Core XML generator
  - Loads template
  - Populates variables
  - Generates final autounattend.xml

## Build Process Flow

```
1. Load preset JSON
   ↓
2. Validate against schema
   ↓
3. Merge with template defaults
   ↓
4. Extract Windows ISO
   ↓
5. Mount WIM image
   ↓
6. Remove packages (if specified)
   ↓
7. Generate autounattend.xml from template
   ↓
8. Inject autounattend.xml into ISO
   ↓
9. Unmount WIM
   ↓
10. Create bootable ISO
```

## Migration from Old Structure

Old files have been moved to `archive/`:
- `autounattend.xml` → `archive/autounattend.xml`
- `desktop-minimal.json` → `archive/desktop-minimal.json`
- etc.

New equivalent presets:
- `bare-bones.json` → `ultra-minimal.json`
- `desktop-minimal.json` → `minimal-desktop.json`
- `handheld-default.json` → `handheld.json`

## Best Practices

1. **Never edit schema templates directly** - They're documentation
2. **Keep presets minimal** - Only specify what you need to change
3. **Use meaningful names** - Make preset purpose clear
4. **Test incrementally** - Start with ultra-minimal, add features
5. **Document changes** - Update metadata when customizing

## Troubleshooting

### ISO fails to boot
- Start with `ultra-minimal.json` to isolate the issue
- Check `docs/BOOT_FAILURE_ANALYSIS.md`
- Review build log in `output/build-*.log`

### Build fails
- Check dependencies: `pwsh`, `7z`, `wimlib-imagex`, `genisoimage`
- Verify source ISO exists and is readable
- Check disk space (need ~15GB free)
- Review log file for specific error

### Can't find old files
- Check `archive/` directory
- Old structure is preserved there

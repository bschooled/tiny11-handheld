# Quick Reference - Repository Structure

## 📁 Directory Layout

```
templates/          → Schema/documentation (DON'T EDIT builds)
  ├── autounattend/schema.xml   # Complete XML template
  └── presets/schema.json        # All available options

presets/            → Your configurations (EDIT THESE)
  ├── ultra-minimal.json         # Testing/troubleshooting
  ├── minimal-desktop.json       # Most users
  └── handheld.json              # Gaming devices

platform/linux/lib/ → Build functions (reusable code)
  ├── template-functions.sh      # Template loading
  ├── validation-functions.sh    # Input checks
  └── cleanup-functions.sh       # Cleanup helpers

archive/            → Old/deprecated files (reference only)
```

## 🚀 Quick Start

### Build Commands

```bash
# Ultra minimal (for testing)
./platform/linux/build.sh --preset ./presets/ultra-minimal.json --source Win11.iso

# Desktop (recommended)
./platform/linux/build.sh --preset ./presets/minimal-desktop.json --source Win11.iso

# Handheld gaming
./platform/linux/build.sh --preset ./presets/handheld.json --source Win11.iso
```

### Create Custom Preset

```bash
# 1. Copy existing preset
cp presets/minimal-desktop.json presets/my-config.json

# 2. Edit (see templates/presets/schema.json for all options)
nano presets/my-config.json

# 3. Build
./platform/linux/build.sh --preset ./presets/my-config.json --source Win11.iso
```

## 📋 Preset Comparison

| Feature | ultra-minimal | minimal-desktop | handheld |
|---------|--------------|-----------------|----------|
| **Use Case** | Testing | Daily driver | Gaming device |
| **Size** | ~8 lines | ~40 lines | ~70 lines |
| **Package Removal** | None | 13 packages | 22 packages |
| **Privacy Tweaks** | None | Yes | Yes |
| **Performance Opts** | None | Basic | Aggressive |
| **Disk Usage** | Same as Windows | -500MB | -1GB+ |

## 🔍 Finding Options

### Want to know what you can configure?

**👉 Look at:** `templates/presets/schema.json`

Shows ALL options organized by category:
- `packages` - What to remove/keep
- `privacy` - Telemetry, Copilot, app suggestions
- `security` - UAC, SmartScreen, encryption
- `ui` - File extensions, widgets, Start menu
- `performance` - Long paths, hibernation, restore
- `unattended` - User account, timezone, locale

### Want to see autounattend.xml structure?

**👉 Look at:** `templates/autounattend/schema.xml`

Shows complete XML with:
- All configuration passes
- Template variables
- Optional blocks
- Full documentation

## 📝 Preset Best Practices

### ✅ DO
- Start with ultra-minimal when troubleshooting
- Only include options you want to change
- Use meaningful preset names
- Add descriptive metadata
- Reference schema.json for options

### ❌ DON'T
- Edit schema templates directly
- Include every option (only what you need)
- Leave out metadata (name, description)
- Forget to test after changes

## 🐛 Troubleshooting

### Build fails?
```bash
# 1. Check dependencies
pwsh --version  # Need PowerShell 7+
7z              # Need p7zip
wimlib-imagex   # Need wimtools
genisoimage     # Need ISO tools

# 2. Check disk space
df -h .  # Need ~15GB free

# 3. Check logs
tail -100 output/build-*.log
```

### ISO won't boot?
```bash
# Start with absolute minimum
./platform/linux/build.sh \
  --preset ./presets/ultra-minimal.json \
  --source Win11.iso

# If ultra-minimal works, issue is in your customizations
# Add features one at a time to find the problem
```

### Can't find old files?
```bash
# Check archive directory
ls -la archive/

# Old structure preserved there
```

## 📚 Documentation

| File | Purpose |
|------|---------|
| `STRUCTURE.md` | Complete structure guide |
| `../REORGANIZATION.md` | Migration guide |
| `../BOOT_FAILURE_ANALYSIS.md` | Boot issues |
| `../../templates/presets/schema.json` | All options reference |

## 🎯 Common Tasks

### Add package removal
```json
{
  "packages": {
    "removeList": [
      "Microsoft.BingNews",
      "Microsoft.YourPhone"
    ]
  }
}
```

### Disable telemetry
```json
{
  "privacy": {
    "disableTelemetry": true,
    "disableCopilot": true
  }
}
```

### Show file extensions
```json
{
  "ui": {
    "showFileExtensions": true
  }
}
```

### Change username/password
```json
{
  "unattended": {
    "userAccount": {
      "username": "YourName",
      "password": "YourPassword"
    }
  }
}
```

## 💡 Tips

- **Testing?** Use `ultra-minimal.json`
- **Desktop?** Use `minimal-desktop.json`
- **Gaming?** Use `handheld.json`
- **Custom?** Copy and modify any preset
- **Stuck?** Check `templates/presets/schema.json`
- **Errors?** Review `output/build-*.log`

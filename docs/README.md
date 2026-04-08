# Tiny11 Handheld - Cross-Platform Windows 11 Image Builder

Build minimal, optimized Windows 11 installation images from both Linux and Windows environments. Perfect for handheld gaming PCs, tablets, and resource-constrained devices.

## Overview

Tiny11 Handheld is a cross-platform build system that creates customized Windows 11 installation ISOs with:

- **Minimal footprint**: Remove bloatware and unnecessary Windows components
- **System requirement bypasses**: Skip TPM 2.0, Secure Boot, and RAM checks
- **Device-specific presets**: Pre-configured settings for ROG Ally, Steam Deck, and other handhelds
- **Custom drivers & updates**: Inject device drivers and Windows updates during image creation
- **Automated post-install**: Configure applications and settings on first boot
- **Cross-platform**: Build on Linux (Docker-based) or Windows (native DISM)

## Quick Start

### Prerequisites

**On Linux:**
- Docker 20.10+ (for DISM operations)
- Bash 5.0+
- PowerShell 7+ (for configuration modules)
- `genisoimage` or `xorriso` (for ISO creation)

**On Windows:**
- Windows 10/11
- PowerShell 5.1+
- DISM (built-in)
- Administrator privileges

### Basic Usage

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/tiny11-handheld.git
   cd tiny11-handheld
   ```

2. **Place your Windows 11 ISO:**
   ```bash
   # Download from Microsoft and place in the project root
   # Example: Win11_23H2_English_x64.iso
   ```

3. **Build with a preset:**

   **On Linux:**
   ```bash
   ./platform/linux/build.sh --preset presets/handheld-default.json --source Win11_23H2_English_x64.iso
   ```

   **On Windows:**
   ```powershell
   .\platform\windows\build.ps1 -Preset presets\handheld-default.json -Source Win11_23H2_English_x64.iso
   ```

4. **Find your ISO:**
   - Output will be in `./output/` directory
   - Default name: `tiny11-handheld.iso`

## Available Presets

| Preset | Description | Use Case |
|--------|-------------|----------|
| `handheld-default.json` | Aggressive debloating, all bypasses enabled | Generic handheld gaming devices |
| `rog-ally.json` | ROG Ally optimized with Xbox services | ASUS ROG Ally |
| `desktop-minimal.json` | Conservative removal, no bypasses | Standard desktop/laptop PCs |

## Custom Configuration

Create your own `configurations.json`:

```json
{
  "version": "1.0.0",
  "source": {
    "isoPath": "Win11_23H2_English_x64.iso",
    "architecture": "amd64"
  },
  "output": {
    "imageName": "my-custom-tiny11.iso",
    "outputPath": "./output",
    "compressionLevel": "max"
  },
  "packages": {
    "removeEdge": true,
    "removeOneDrive": true,
    "removeList": ["Microsoft.BingNews", "Microsoft.BingWeather"]
  },
  "features": {
    "bypassSystemRequirements": true
  }
}
```

See [CONFIGURATION.md](CONFIGURATION.md) for complete configuration reference.

## Features

### Package Removal
- Remove Microsoft Edge, OneDrive, Xbox services
- Selective Windows app removal with keep/remove lists
- Automatic dependency resolution

### System Requirement Bypasses
- TPM 2.0 requirement bypass
- Secure Boot bypass
- RAM requirement bypass (4GB minimum → any amount)
- CPU compatibility bypass

### Optimization
- Component cleanup (`/StartComponentCleanup`)
- Reset base (`/ResetBase`)
- WinSxS backup removal (advanced)
- WIM compression options: none, fast, max, recovery

### Extensibility
- Driver injection from local directories
- Windows Update (.msu/.cab) injection
- OEM customization file injection
- Post-install package automation via `packages.json`
- Custom PowerShell module support

### Unattended Installation
- Pre-configure computer name, timezone, locale
- Automatic OOBE (Out-of-Box Experience) configuration
- Product key injection (optional)
- Keyboard layout customization

## Project Structure

```
tiny11-handheld/
├── platform/
│   ├── linux/          # Linux-specific implementations (Docker DISM)
│   └── windows/        # Windows-specific implementations (native DISM)
├── modules/            # PowerShell Core 7+ cross-platform modules
├── presets/            # Device-specific baseline configurations
├── docs/               # User documentation
├── configurations.json # Build configuration (user-created)
├── packages.json       # Post-install application manifest
├── schema.json         # JSON Schema for configuration validation
└── README.md           # This file
```

## Documentation

- **[CONFIGURATION.md](CONFIGURATION.md)**: Complete configuration reference
- **[Architecture](../specs/001-cross-platform-build/plan.md)**: Technical implementation details
- **[Specification](../specs/001-cross-platform-build/spec.md)**: Feature requirements and user stories

## Memory Requirements

Peak memory usage during build: **~8GB**
- WIM extraction and modification is memory-intensive
- Ensure adequate RAM on build machine
- Consider `compressionLevel: "fast"` for lower memory usage

## Troubleshooting

**"DISM failed with exit code X"**
- Verify source ISO integrity (check SHA256)
- Ensure adequate disk space (20GB+ free recommended)
- Run with administrator/root privileges

**"Package removal failed"**
- Some packages have dependencies, check logs for details
- Use `keepList` to preserve dependent packages

**"Docker container timeout" (Linux only)**
- DISM operations can take 30+ minutes
- Check Docker daemon status: `docker ps`
- Review container logs: `docker logs <container_id>`

**"Schema validation failed"**
- Validate your configuration: `pwsh -Command "Test-Json -SchemaFile schema.json -Path configurations.json"`
- Check for missing required fields or typos

## Contributing

Contributions welcome! See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

## License

MIT License - See [LICENSE](../LICENSE) for details.

## Credits

Based on the original [tiny11builder](https://github.com/ntdevlabs/tiny11builder) project by ntdevlabs.

## Disclaimer

This tool modifies official Windows 11 installation media. Use at your own risk. Always keep backups and verify image integrity before deployment.

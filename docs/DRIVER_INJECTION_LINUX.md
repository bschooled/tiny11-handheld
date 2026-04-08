# Driver Injection Workarounds for Linux Builds

## Problem

wimlib-imagex on Linux cannot properly inject drivers into Windows WIM images because:
- FUSE-mounted WIM filesystems are read-only when modifications are attempted
- Driver injection requires Windows-specific operations (INF processing, registry updates)
- wimlib's `update` command only copies files, doesn't register drivers

## Workarounds

### Option 1: Use Windows for Driver Injection (RECOMMENDED)

Build the base ISO on Linux, then inject drivers on Windows:

```bash
# On Linux: Build base ISO
./platform/linux/build.sh --preset ./presets/handheld-default.json --source ./Win1125H2.iso

# Transfer ISO to Windows machine
# On Windows: Inject drivers using DISM
Dism /Mount-Image /ImageFile:"install.wim" /Index:1 /MountDir:mount
Dism /Image:mount /Add-Driver /Driver:"drivers" /Recurse
Dism /Unmount-Image /MountDir:mount /Commit
```

### Option 2: Manual Driver Addition During Windows Install

The built ISO can boot and install Windows. Add drivers manually after installation:

1. Boot from the tiny11-handheld.iso
2. Install Windows normally
3. After installation, use Device Manager or:
   ```cmd
   pnputil /add-driver C:\path\to\drivers\*.inf /subdirs /install
   ```

### Option 3: Include Drivers in Autounattend.xml

Modify the autounattend.xml to reference drivers on a USB drive:

```xml
<DriverPaths>
    <PathAndCredentials wcm:action="add" wcm:keyValue="1">
        <Path>E:\drivers</Path>
    </PathAndCredentials>
</DriverPaths>
```

Then during installation, have the drivers on a second USB drive.

### Option 4: Pre-install Drivers in Source ISO (Windows Only)

Before running the Linux build, prepare the Windows ISO with drivers:

```powershell
# On Windows:
Dism /Mount-Image /ImageFile:"install.wim" /Index:1 /MountDir:mount
Dism /Image:mount /Add-Driver /Driver:"drivers" /Recurse  
Dism /Unmount-Image /MountDir:mount /Commit

# Create new ISO with drivers
# Use this modified ISO as --source for Linux build
```

## Current Implementation

The `drivers.inject` option in presets is **not functional on Linux** due to wimlib limitations.

To avoid build failures:
- Keep `drivers.inject: false` in Linux builds
- Use one of the workarounds above

## Future Enhancement

A hybrid approach could be implemented:
1. Build base ISO on Linux
2. Auto-trigger Windows WSL/VM for driver injection
3. Return completed ISO

This would require:
- WSL with Windows DISM
- OR automated VM with Windows
- OR cross-platform abstraction layer

For now, manual driver injection post-build is the most reliable approach.

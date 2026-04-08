# Quickstart Guide: Cross-Platform Windows 11 Image Builder

**Feature**: 001-cross-platform-build  
**Last Updated**: 2026-01-01  
**Estimated Time**: 30-60 minutes (first build)

## Prerequisites

### For Linux Users

**Required Tools**:
- Docker 20.10+ with Windows container support
- p7zip-full (7-Zip)
- bash 5.0+
- 20GB free disk space minimum

**Optional Tools** (fallback if Docker unavailable):
- wimlib-tools (wimlib-imagex)
- genisoimage or xorriso

**Installation (Ubuntu/Debian)**:
```bash
# Install required tools
sudo apt update
sudo apt install docker.io p7zip-full

# Install optional tools (fallback)
sudo apt install wimtools genisoimage

# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in for group change to take effect
```

**Installation (Fedora/RHEL)**:
```bash
sudo dnf install docker p7zip wimlib-utils genisoimage
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

**Installation (Arch)**:
```bash
sudo pacman -S docker p7zip wimlib cdrtools
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

### For Windows Users

**Required Tools**:
- Windows 10/11 (build 19041+)
- PowerShell 5.1+ (included)
- Windows ADK (for oscdimg)
- 7-Zip
- 20GB free disk space minimum

**Installation (PowerShell as Administrator)**:
```powershell
# Install Chocolatey package manager
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install 7-Zip
choco install 7zip -y

# Download Windows ADK (manual step)
Write-Host "Download Windows ADK from:"
Write-Host "https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install"
Write-Host "Install only 'Deployment Tools' component (includes oscdimg)"
```

---

## Step 1: Verify Prerequisites

### Linux

```bash
# Run prerequisite check
./check-prereqs.sh

# Example output:
# ✅ docker (20.10.22) - Docker container runtime
# ✅ p7zip (16.02) - 7-Zip file archiver
# ✅ sha256sum (8.30) - Checksum utility
# All required prerequisites met!
```

### Windows

```powershell
# Run prerequisite check
.\check-prereqs.ps1

# Example output:
# ✅ DISM - Deployment Image Servicing and Management
# ✅ PowerShell 5.1.19041 - PowerShell
# ✅ 7z (23.01) - 7-Zip
# ✅ oscdimg (10.1.22621.1) - ISO creation tool
# All required prerequisites met!
```

---

## Step 2: Obtain Windows 11 ISO

1. Download legitimate Windows 11 ISO from Microsoft:
   - **Media Creation Tool**: https://www.microsoft.com/software-download/windows11
   - **Direct Download**: Available for registered users
   - **MSDN Subscriber**: Download from subscription portal

2. Verify the ISO (optional but recommended):
   ```bash
   # Linux
   sha256sum Win11_23H2_EnglishInternational_x64.iso
   
   # Windows
   Get-FileHash .\Win11_23H2_EnglishInternational_x64.iso -Algorithm SHA256
   ```

3. Place ISO in accessible location:
   - Linux: `/home/user/iso/windows11.iso`
   - Windows: `C:\ISO\windows11.iso`

---

## Step 3: Configure Your Build

### Option A: Use Default Configuration

1. Copy example configuration:
   ```bash
   # Linux
   cp configurations.example.json configurations.json
   
   # Windows
   Copy-Item configurations.example.json configurations.json
   ```

2. Edit `configurations.json` with your ISO path:
   ```json
   {
     "version": "1.0.0",
     "source": {
       "isoPath": "/home/user/iso/windows11.iso",
       "architecture": "amd64"
     },
     "output": {
       "imageName": "Tiny11Handheld.iso",
       "outputPath": "./output"
     }
   }
   ```

### Option B: Use Preset Configuration

For ROG Ally handheld:
```bash
# Linux
cp presets/rog-ally.json configurations.json

# Windows
Copy-Item presets\rog-ally.json configurations.json
```

For general handheld devices:
```bash
# Linux
cp presets/handheld-default.json configurations.json

# Windows
Copy-Item presets\handheld-default.json configurations.json
```

### Option C: Create Custom Configuration

See [Configuration Options](#configuration-options) below for detailed explanations.

---

## Step 4: Validate Configuration

```bash
# Linux
./build.sh --config ./configurations.json --validate-only

# Windows
.\build.ps1 -Config .\configurations.json -ValidateOnly
```

**Expected output**:
```
[INFO] Validating configuration...
✅ Configuration valid
[INFO] Source ISO: /home/user/iso/windows11.iso (4.2 GB)
[INFO] Output path: ./output (writable)
[INFO] Estimated disk space needed: 15 GB
[INFO] Available disk space: 42 GB
✅ All validation checks passed
```

---

## Step 5: Run Build (Dry Run)

Preview what will be done without making changes:

```bash
# Linux
./build.sh --config ./configurations.json --dry-run --verbose

# Windows
.\build.ps1 -Config .\configurations.json -DryRun -Verbose
```

**Expected output**:
```
[DRY RUN] Would perform the following actions:
  1. Extract ISO to workspace
  2. Mount install.wim (index 1)
  3. Remove 42 packages
  4. Bypass system requirements
  5. Enable component cleanup
  6. Unmount and commit changes
  7. Create bootable ISO
[DRY RUN] No changes made. Remove --dry-run to execute build.
```

---

## Step 6: Run Build

Execute the actual build:

```bash
# Linux (Docker method - recommended)
./build.sh --config ./configurations.json

# Linux (wimlib fallback)
./build.sh --config ./configurations.json --method wimlib

# Windows
.\build.ps1 -Config .\configurations.json
```

**Expected duration**: 15-30 minutes depending on:
- Disk speed (SSD recommended)
- CPU performance
- Number of packages to remove
- Driver/update injection

**Progress output**:
```
[INFO] Build started (ID: abc-123-def)
[INFO] Platform: Linux (Docker method)
[INFO] Extracting ISO... 10%
[INFO] Mounting WIM image... 25%
[INFO] Removing packages... 40%
  - Removed: Microsoft.WindowsAlarms
  - Removed: Microsoft.BingWeather
  [... 40 more packages ...]
[INFO] Applying optimizations... 60%
[INFO] Unmounting image... 75%
[INFO] Creating bootable ISO... 90%
✅ Build complete!
   Output: ./output/Tiny11Handheld.iso
   Size: 7.2 GB (3.1 GB reduction from original)
   Build time: 18m 34s
   Checksum: abc123...def
```

---

## Step 7: Verify Output

```bash
# Check output ISO exists
ls -lh ./output/Tiny11Handheld.iso

# Verify checksum
sha256sum ./output/Tiny11Handheld.iso
# Compare with checksum in build log
```

---

## Step 8: Test in VM (Recommended)

Before deploying to physical hardware, test in a virtual machine:

### Using VirtualBox (Linux/Windows)

```bash
# Create VM
VBoxManage createvm --name "Tiny11Test" --register
VBoxManage modifyvm "Tiny11Test" --memory 4096 --vram 128 --cpus 2
VBoxManage createhd --filename "Tiny11Test.vdi" --size 32768
VBoxManage storagectl "Tiny11Test" --name "SATA" --add sata
VBoxManage storageattach "Tiny11Test" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "Tiny11Test.vdi"
VBoxManage storageattach "Tiny11Test" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium ./output/Tiny11Handheld.iso

# Start VM
VBoxManage startvm "Tiny11Test"
```

### Using QEMU (Linux)

```bash
# Create disk image
qemu-img create -f qcow2 tiny11test.qcow2 32G

# Boot from ISO
qemu-system-x86_64 \
  -m 4G \
  -cdrom ./output/Tiny11Handheld.iso \
  -hda tiny11test.qcow2 \
  -boot d \
  -enable-kvm
```

---

## Step 9: Deploy to Physical Hardware

Once tested in VM:

1. **Create bootable USB** (using Rufus on Windows, `dd` on Linux):
   ```bash
   # Linux (CAUTION: Verify device name!)
   sudo dd if=./output/Tiny11Handheld.iso of=/dev/sdX bs=4M status=progress
   
   # Windows: Use Rufus GUI
   # Download from: https://rufus.ie/
   ```

2. **Boot from USB** on target handheld device
3. **Follow Windows installation** (automated via autounattend.xml)
4. **Post-install apps** will install automatically (if configured in packages.json)

---

## Configuration Options

### Essential Options

```json
{
  "version": "1.0.0",  // Required
  "source": {
    "isoPath": "path/to/iso",  // Required
    "architecture": "amd64"     // Required: amd64 or arm64
  },
  "output": {
    "imageName": "output.iso",  // Required
    "outputPath": "./output"    // Required
  }
}
```

### Package Removal

```json
{
  "packages": {
    "removeEdge": true,         // Remove Microsoft Edge
    "removeOneDrive": true,     // Remove OneDrive
    "removeList": [
      "Microsoft.WindowsAlarms",
      "Microsoft.BingWeather",
      "Microsoft.WindowsMaps"
      // See full list in documentation
    ]
  }
}
```

### System Requirement Bypasses

**⚠️ CAUTION**: Bypassing security features may expose system to vulnerabilities

```json
{
  "features": {
    "bypassTPM": true,          // Allow install without TPM 2.0
    "bypassSecureBoot": true,   // Allow install without Secure Boot
    "bypassRAMCheck": true,     // Allow <4GB RAM
    "bypassCPUCheck": true      // Allow unsupported CPUs
  }
}
```

### Driver Injection

```json
{
  "drivers": {
    "inject": true,
    "driverPath": "./drivers/rog-ally",
    "recursive": true
  }
}
```

### Optimization (Recommended for handhelds)

```json
{
  "optimization": {
    "componentCleanup": true,   // Remove superseded components
    "resetBase": true           // Reduces image size further
  }
}
```

---

## Troubleshooting

### Build fails with "Missing prerequisite: docker"

**Linux**: Install Docker and add user to docker group
```bash
sudo apt install docker.io
sudo usermod -aG docker $USER
# Log out and back in
```

**Alternative**: Use wimlib fallback
```bash
./build.sh --method wimlib
```

### Build fails with "Permission denied"

**Linux**: Ensure user is in docker group
```bash
groups  # Should show 'docker'
newgrp docker  # Refresh group membership
```

**Windows**: Run PowerShell as Administrator

### Build fails with "Insufficient disk space"

Free up space or change workspace location:
```bash
# Linux
./build.sh --config ./config.json --workspace /path/to/large/disk

# Windows
.\build.ps1 -Config .\config.json -ScratchDisk D:\workspace
```

### ISO won't boot in VM

- Verify ISO checksum matches build log
- Use BIOS (not UEFI) mode in VM for initial test
- Check VM has adequate RAM (4GB minimum)

### Packages not removed as expected

- Verify package names in `removeList` are correct
- Use `--verbose` flag to see detailed package removal log
- Some packages may have dependencies preventing removal

---

## Next Steps

- **Customize further**: Edit configurations.json to add/remove more packages
- **Create presets**: Save your configuration as a preset for future builds
- **Automate**: Use in CI/CD for reproducible image builds
- **Contribute**: Share your preset configurations with the community

---

## Getting Help

- **Documentation**: See full documentation in `/docs`
- **Issues**: Report bugs on GitHub Issues
- **Discussions**: Ask questions in GitHub Discussions
- **Logs**: Check `./build.log` for detailed error information

---

## Build Time Optimization Tips

1. **Use SSD**: 3-5x faster than HDD
2. **Allocate more RAM**: Enable Docker to use more memory
3. **Parallel operations**: Use `--parallel` flag (experimental)
4. **Reuse workspace**: Use `--keep-workspace` for iterative testing
5. **Reduce compression**: Use `"compressionLevel": "fast"` for faster builds (larger ISO)

---

## Security Considerations

1. **TPM/Secure Boot bypass**: Only use on isolated/air-gapped systems
2. **Package removal**: Some packages may be required for security updates
3. **Driver injection**: Only inject drivers from trusted sources
4. **ISO verification**: Always verify checksums of source ISO
5. **Testing**: Test thoroughly in VM before physical deployment

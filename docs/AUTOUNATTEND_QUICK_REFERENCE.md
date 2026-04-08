# Windows 11 Autounattend.xml Quick Reference

## 🚨 Most Common Failure Causes

| Symptom | Cause | Fix |
|---------|-------|-----|
| **Immediate reboot after setup starts** | `<UseConfigurationSet>true</UseConfigurationSet>` | Remove this element |
| **Reboot during specialize phase** | PowerShell scripts referencing missing files | Remove script RunSynchronous commands |
| **Hang at "Getting ready" screen** | FirstLogonCommands with failed scripts | Remove or simplify FirstLogonCommands |
| **Boot failure after install** | `<Compact>true</Compact>` on virtual disk | Remove Compact element |
| **"Windows cannot be installed to this disk"** | Wrong PartitionID or disk format | Match PartitionID to DiskConfiguration |

---

## ✅ Minimal Working Structure

```xml
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    
    <!-- PASS 1: windowsPE -->
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" ...>
            <UILanguage>en-US</UILanguage>
        </component>
        
        <component name="Microsoft-Windows-Setup" ...>
            <UserData>
                <AcceptEula>true</AcceptEula>
            </UserData>
            
            <!-- TPM Bypass (for QEMU/VMs) -->
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <Path>reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>3</Order>
                    <Path>reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassRAMCheck /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
    
    <!-- PASS 2: oobeSystem -->
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" ...>
            <UILanguage>en-US</UILanguage>
        </component>
        
        <component name="Microsoft-Windows-Shell-Setup" ...>
            <!-- Skip OOBE -->
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <ProtectYourPC>3</ProtectYourPC>
                <SkipUserOOBE>true</SkipUserOOBE>
                <SkipMachineOOBE>true</SkipMachineOOBE>
            </OOBE>
            
            <!-- Create Admin User -->
            <UserAccounts>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Name>Admin</Name>
                        <Group>Administrators</Group>
                        <Password>
                            <Value>Password123</Value>
                            <PlainText>true</PlainText>
                        </Password>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
        </component>
    </settings>
    
</unattend>
```

---

## 🔑 Essential Elements Only

### windowsPE Pass
| Element | Required? | Purpose |
|---------|-----------|---------|
| `UILanguage` | ✅ Yes | Setup language |
| `AcceptEula` | ✅ Yes | Auto-accept license |
| `RunSynchronous` (TPM bypass) | ⚠️ For VMs only | Bypass hardware checks |
| `DiskConfiguration` | ⚠️ For full automation | Auto-partition disk |
| `ImageInstall` | ⚠️ For edition selection | Choose Windows edition |
| `ProductKey` | ❌ Optional | Edition selection key |

### oobeSystem Pass
| Element | Required? | Purpose |
|---------|-----------|---------|
| `OOBE/HideEULAPage` | ✅ Yes | Skip license screen |
| `OOBE/HideOnlineAccountScreens` | ✅ Yes | Skip MS account |
| `OOBE/ProtectYourPC` | ✅ Yes | Disable privacy settings |
| `UserAccounts/LocalAccounts` | ✅ Yes | Create user |
| `AutoLogon` | ❌ Optional | Auto-login after install |

### specialize Pass
| Element | Required? | Purpose |
|---------|-----------|---------|
| `ComputerName` | ❌ Optional | Set PC name |
| `TimeZone` | ❌ Optional | Set timezone |

---

## ⛔ Elements to AVOID

| Element | Why to Avoid |
|---------|--------------|
| `<UseConfigurationSet>` | Expects provisioning packages → immediate reboot |
| `<Compact>true</Compact>` | Can cause boot failures on VMs |
| `<Extensions>...</Extensions>` | Complex, prone to parsing errors |
| PowerShell in specialize | Execution policy issues, script failures |
| VBScript disk assertions | Syntax errors, unnecessary complexity |
| `FirstLogonCommands` with scripts | Can hang system if script fails |
| Registry hive loading (HKU\DefaultUser) | Timing issues, can corrupt profile |

---

## 📋 Generic Product Keys (Edition Selection)

| Edition | Key |
|---------|-----|
| Windows 11 Pro | `VK7JG-NPHTM-C97JM-9MPGT-3V66T` |
| Windows 11 Home | `YTMG3-N6DKC-DKB77-7M9GH-8HVX7` |

*These do NOT activate Windows, only select the edition during setup*

---

## 🛠️ Disk Partitioning Quick Reference

### Simple GPT Layout (Recommended)
```xml
<DiskConfiguration>
    <Disk wcm:action="add">
        <DiskID>0</DiskID>
        <WillWipeDisk>true</WillWipeDisk>
        <CreatePartitions>
            <CreatePartition wcm:action="add">
                <Order>1</Order>
                <Type>EFI</Type>
                <Size>300</Size>
            </CreatePartition>
            <CreatePartition wcm:action="add">
                <Order>2</Order>
                <Type>MSR</Type>
                <Size>128</Size>
            </CreatePartition>
            <CreatePartition wcm:action="add">
                <Order>3</Order>
                <Type>Primary</Type>
                <Extend>true</Extend>
            </CreatePartition>
        </CreatePartitions>
        <ModifyPartitions>
            <ModifyPartition wcm:action="add">
                <Order>1</Order>
                <PartitionID>1</PartitionID>
                <Format>FAT32</Format>
            </ModifyPartition>
            <ModifyPartition wcm:action="add">
                <Order>2</Order>
                <PartitionID>3</PartitionID>
                <Letter>C</Letter>
                <Format>NTFS</Format>
            </ModifyPartition>
        </ModifyPartitions>
    </Disk>
</DiskConfiguration>
```

### Partition Types
| Type | Size | Purpose |
|------|------|---------|
| EFI | 300 MB | Boot partition (FAT32) |
| MSR | 16-128 MB | Microsoft Reserved (no format) |
| Primary | Remaining | Windows installation (NTFS) |
| Recovery | 1000 MB | Optional recovery partition |

---

## 🐛 Debugging

### Log Files (after installation)
```
C:\Windows\Panther\setupact.log    # Main log
C:\Windows\Panther\setuperr.log    # Errors only
C:\Windows\Panther\unattend.xml    # Copy of answer file used
```

### Common Error Messages
| Log Message | Meaning | Fix |
|-------------|---------|-----|
| `Failed to run action: <ExtractScript>` | PowerShell script extraction failed | Remove Extensions section |
| `Configuration set not found` | UseConfigurationSet without packages | Remove UseConfigurationSet |
| `Cannot find file: C:\Windows\Setup\Scripts\` | Missing script file | Remove script reference |
| `Unattended setup failed in pass [specialize]` | Error in specialize commands | Simplify/remove specialize |

### Debug During Setup
- **Shift + F10** → Opens Command Prompt during setup
- Check X:\Windows\Panther\ for live logs
- Use `notepad X:\Windows\Panther\setupact.log` to view logs

---

## 🚀 Quick Start

### Test Ultra-Minimal
```bash
cd /home/bschooley/local-dev/tiny11-handheld
cp autounattend.ultra-minimal.xml autounattend.xml
# Rebuild ISO and test
```

### Test Minimal (with partitioning)
```bash
cp autounattend.minimal.xml autounattend.xml
# Rebuild ISO and test
```

### Add Features Incrementally
1. Start with ultra-minimal
2. Verify it boots without rebooting
3. Add ONE feature at a time
4. Test after each addition

---

## 📊 Configuration Pass Order

```
Installation Timeline:
  1. windowsPE      → Disk setup, EULA, TPM bypass
  2. offlineServicing → (Skipped - for WIM servicing only)
  3. generalize     → (Skipped - for SysPrep only)
  4. specialize     → Computer name, timezone
  5. auditSystem    → (Skipped - for audit mode only)
  6. auditUser      → (Skipped - for audit mode only)
  7. oobeSystem     → User creation, OOBE bypass
```

**Only windowsPE and oobeSystem are required for basic installation**

---

## 🎯 Your Specific Issue

**Problem:** Immediate reboot during Windows 11 installation  
**Root Cause:** `<UseConfigurationSet>true</UseConfigurationSet>` in line 31 of autounattend.xml  
**Solution:** Use autounattend.minimal.xml or autounattend.ultra-minimal.xml  

**Secondary Issues:**
- ExtractScript PowerShell execution failures
- References to non-existent Specialize.ps1, DefaultUser.ps1, FirstLogon.ps1
- Complex VBScript disk assertions
- CompactOS on virtual disk

**All fixed in the minimal files provided.**

---

## 📚 Files Created for You

| File | Description | Use Case |
|------|-------------|----------|
| `autounattend.minimal.xml` | Full automation with disk partitioning | Production deployments |
| `autounattend.ultra-minimal.xml` | No disk partitioning, simplest possible | Troubleshooting, testing |
| `docs/AUTOUNATTEND_MINIMAL_GUIDE.md` | Complete guide with explanations | Reference documentation |
| `docs/AUTOUNATTEND_COMPARISON.md` | Side-by-side comparison with current file | Understanding differences |
| `docs/AUTOUNATTEND_QUICK_REFERENCE.md` | This file | Quick lookup |

---

## ✨ Key Principles

1. **Simpler is Better** - Fewer elements = fewer failure points
2. **Native XML Over Scripts** - Use built-in elements, avoid PowerShell
3. **Test Incrementally** - Start minimal, add features one at a time
4. **Check Logs** - setupact.log and setuperr.log are your friends
5. **No UseConfigurationSet** - Unless you have actual .ppkg files

---

**Quick Test Command:**
```bash
cp autounattend.minimal.xml autounattend.xml && \
./platform/linux/build.sh --preset ./presets/minimal-build.json --source ./Win1125H2.iso
```

**Expected Result:** Windows 11 installs without rebooting, creates Admin user, skips OOBE ✅

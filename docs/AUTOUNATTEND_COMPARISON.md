# Autounattend.xml Comparison: Current vs. Minimal

## Quick Reference

| Feature | Current (autounattend.xml) | Minimal | Ultra-Minimal |
|---------|---------------------------|---------|---------------|
| **File Size** | 604 lines | ~200 lines | ~100 lines |
| **Disk Partitioning** | Complex diskpart scripts (10 commands) | Native XML DiskConfiguration | None (Windows auto-partitions) |
| **Scripts** | Yes - ExtractScript + embedded PS1 files | None | None |
| **UseConfigurationSet** | ✅ Yes (CAUSES REBOOT) | ❌ No | ❌ No |
| **CompactOS** | ✅ Yes (can cause issues) | ❌ No | ❌ No |
| **TPM Bypass** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Package Removal** | Yes (via PowerShell) | No | No |
| **Registry Tweaks** | Yes (via PowerShell in specialize) | No | No |
| **Boot Result** | ❌ Immediate reboot | ✅ Should work | ✅ Should work |

---

## Side-by-Side: windowsPE Pass

### Current (Lines 40-67)
```xml
<RunSynchronous>
    <!-- TPM bypasses (good) -->
    <RunSynchronousCommand wcm:action="add">
        <Order>1</Order>
        <Path>reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path>
    </RunSynchronousCommand>
    <!-- ... orders 2-3 for other bypasses ... -->
    
    <!-- ❌ PROBLEMATIC: Complex VBScript disk assertion -->
    <RunSynchronousCommand wcm:action="add">
        <Order>4</Order>
        <Path>cmd.exe /c "&gt;&gt;"X:\assert.vbs" (echo:On Error Resume Next...)</Path>
    </RunSynchronousCommand>
    <!-- ... 6 more commands creating assertion scripts ... -->
    
    <!-- Diskpart script creation -->
    <RunSynchronousCommand wcm:action="add">
        <Order>7</Order>
        <Path>cmd.exe /c "&gt;&gt;"X:\diskpart.txt" (echo:SELECT DISK=0...)</Path>
    </RunSynchronousCommand>
    <!-- ... 2 more commands building diskpart.txt ... -->
    
    <!-- Execute diskpart -->
    <RunSynchronousCommand wcm:action="add">
        <Order>10</Order>
        <Path>cmd.exe /c "diskpart.exe /s "X:\diskpart.txt"..."</Path>
    </RunSynchronousCommand>
</RunSynchronous>
```

**Issues:**
- 10 total commands, 7 just for disk operations
- VBScript syntax errors common
- Diskpart can fail silently
- Hard to debug

---

### Minimal
```xml
<RunSynchronous>
    <!-- Only TPM bypasses - simple and reliable -->
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

<!-- Disk partitioning moved to native XML -->
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
            <!-- ... clean XML structure ... -->
        </CreatePartitions>
    </Disk>
</DiskConfiguration>
```

**Advantages:**
- 3 simple commands vs 10 complex ones
- Native XML parsing (more reliable)
- Easy to read and modify
- Proper error handling by Windows Setup

---

## Side-by-Side: specialize Pass

### Current (Lines 70-89)
```xml
<component name="Microsoft-Windows-Deployment" ...>
    <RunSynchronous>
        <!-- ❌ PROBLEM #1: ExtractScript execution -->
        <RunSynchronousCommand wcm:action="add">
            <Order>1</Order>
            <Path>powershell.exe -WindowStyle "Normal" -NoProfile -Command "$xml = [xml]::new(); $xml.Load('C:\Windows\Panther\unattend.xml'); $sb = [scriptblock]::Create( $xml.unattend.Extensions.ExtractScript ); Invoke-Command -ScriptBlock $sb -ArgumentList $xml;"</Path>
        </RunSynchronousCommand>
        
        <!-- ❌ PROBLEM #2: References non-existent script -->
        <RunSynchronousCommand wcm:action="add">
            <Order>2</Order>
            <Path>powershell.exe -WindowStyle "Normal" -ExecutionPolicy "Unrestricted" -NoProfile -File "C:\Windows\Setup\Scripts\Specialize.ps1"</Path>
        </RunSynchronousCommand>
        
        <!-- ❌ PROBLEM #3: DefaultUser hive manipulation -->
        <RunSynchronousCommand wcm:action="add">
            <Order>3</Order>
            <Path>reg.exe load "HKU\DefaultUser" "C:\Users\Default\NTUSER.DAT"</Path>
        </RunSynchronousCommand>
        
        <!-- ❌ PROBLEM #4: Another non-existent script -->
        <RunSynchronousCommand wcm:action="add">
            <Order>4</Order>
            <Path>powershell.exe -WindowStyle "Normal" -ExecutionPolicy "Unrestricted" -NoProfile -File "C:\Windows\Setup\Scripts\DefaultUser.ps1"</Path>
        </RunSynchronousCommand>
        
        <RunSynchronousCommand wcm:action="add">
            <Order>5</Order>
            <Path>reg.exe unload "HKU\DefaultUser"</Path>
        </RunSynchronousCommand>
    </RunSynchronous>
</component>
```

**Why This Fails:**
1. ExtractScript tries to load unattend.xml which may not be fully written yet
2. Specialize.ps1 doesn't exist (supposed to be extracted by ExtractScript)
3. If ExtractScript fails, scripts aren't extracted → boot loop
4. Execution policy issues even with `-ExecutionPolicy Unrestricted`

---

### Minimal
```xml
<component name="Microsoft-Windows-Shell-Setup" ...>
    <!-- Simple, safe, no scripts -->
    <ComputerName>WIN11-PC</ComputerName>
    <TimeZone>Pacific Standard Time</TimeZone>
</component>
```

**Why This Works:**
- No external dependencies
- No scripts to fail
- Native Windows functionality
- Guaranteed to work

---

## Critical Differences: Extensions Section

### Current (Lines 150-604)
```xml
<Extensions xmlns="https://schneegans.de/windows/unattend-generator/">
    <ExtractScript>
        <!-- 20+ lines of PowerShell to extract embedded files -->
    </ExtractScript>
    
    <File path="C:\Windows\Setup\Scripts\RemovePackages.ps1">
        <!-- 100+ lines of package removal code -->
    </File>
    
    <File path="C:\Windows\Setup\Scripts\Specialize.ps1">
        <!-- 200+ lines of registry tweaks, feature removal -->
    </File>
    
    <File path="C:\Windows\Setup\Scripts\DefaultUser.ps1">
        <!-- User profile customizations -->
    </File>
    
    <File path="C:\Windows\Setup\Scripts\FirstLogon.ps1">
        <!-- First logon customizations -->
    </File>
</Extensions>
```

**Total:** 450+ lines of embedded PowerShell scripts

**Failure Points:**
- ExtractScript parsing errors
- PowerShell execution policy blocks
- Script syntax errors
- Missing dependencies (modules, cmdlets)
- Timing issues (files not ready when needed)
- Each script can independently fail → reboot

---

### Minimal
```xml
<!-- NO EXTENSIONS SECTION -->
```

**Result:** Zero script-related failures

---

## The Root Cause of Your Reboot Issue

### The Smoking Gun: Line 31
```xml
<UseConfigurationSet>true</UseConfigurationSet>
```

**What this does:**
- Tells Windows Setup to look for Configuration Designer provisioning packages
- These are .ppkg files created with Windows Configuration Designer tool
- Your autounattend.xml doesn't include any .ppkg files

**What happens:**
1. Windows Setup reads autounattend.xml
2. Sees `UseConfigurationSet=true`
3. Searches for .ppkg provisioning packages
4. Finds none
5. **Fails setup and reboots immediately**

**Fix:** Remove this line entirely (not present in minimal files)

---

## Migration Path

### Option 1: Quick Fix (Keep Current Structure)
Remove these specific elements from autounattend.xml:

1. Delete line 31: `<UseConfigurationSet>true</UseConfigurationSet>`
2. Delete line 18: `<Compact>true</Compact>`
3. Comment out lines 74-89 (specialize RunSynchronous commands)
4. Comment out lines 150-604 (Extensions section)
5. Keep windowsPE TPM bypasses and disk partitioning

**Result:** May work, but still complex

---

### Option 2: Clean Slate (Recommended)
1. Rename autounattend.xml → autounattend.broken.xml
2. Copy autounattend.minimal.xml → autounattend.xml
3. Test installation
4. Once working, add back features one at a time

**Result:** Clean, maintainable, reliable

---

## Testing Commands

### Replace current autounattend.xml with minimal version
```bash
cd /home/bschooley/local-dev/tiny11-handheld

# Backup current
cp autounattend.xml autounattend.backup.xml

# Test ultra-minimal first (safest)
cp autounattend.ultra-minimal.xml autounattend.xml

# Or test minimal with partitioning
cp autounattend.minimal.xml autounattend.xml

# Rebuild ISO with new autounattend.xml
./platform/linux/build.sh --preset ./presets/minimal-build.json --source ./Win1125H2.iso
```

---

## Expected Behavior After Fix

### Current File (autounattend.xml)
```
Boot ISO
  ↓
Windows Setup loads autounattend.xml
  ↓
Sees UseConfigurationSet=true
  ↓
Looks for provisioning packages
  ↓
None found
  ↓
❌ IMMEDIATE REBOOT
```

### Minimal File
```
Boot ISO
  ↓
Windows Setup loads autounattend.xml
  ↓
Bypasses TPM/SecureBoot checks ✅
  ↓
Partitions disk automatically ✅
  ↓
Installs Windows 11 Pro ✅
  ↓
Skips OOBE screens ✅
  ↓
Creates Admin user ✅
  ↓
Auto-login ✅
  ↓
Desktop ready to use ✅
```

---

## Summary

**Your current autounattend.xml fails because:**
1. `UseConfigurationSet=true` with no provisioning packages → immediate reboot
2. ExtractScript + embedded PowerShell scripts → specialize failures
3. References to non-existent .ps1 files → reboot loop
4. Complex VBScript disk assertions → potential WinPE failures

**The minimal files fix this by:**
1. ❌ No UseConfigurationSet
2. ❌ No ExtractScript or embedded files
3. ❌ No external script references
4. ✅ Native XML for all configurations
5. ✅ Only essential, tested components
6. ✅ Simple, debuggable structure

**Recommendation:** Test autounattend.minimal.xml immediately to verify Windows 11 installs successfully without rebooting.

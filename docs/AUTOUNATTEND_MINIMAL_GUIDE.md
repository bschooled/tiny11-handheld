# Windows 11 Minimal Autounattend.xml Guide

## Overview
This guide explains the minimal requirements for a working Windows 11 autounattend.xml file for automated installation, specifically addressing common pitfalls that cause installation failures and boot loops.

## Critical Findings

### Problem: Immediate Reboot During Installation
**Root Causes Identified:**
1. `<UseConfigurationSet>true</UseConfigurationSet>` - Expects Configuration Designer packages that don't exist
2. PowerShell scripts in specialize pass referencing non-existent files (Specialize.ps1, FirstLogon.ps1, DefaultUser.ps1)
3. ExtractScript XML parsing and execution failures
4. Complex VBScript disk assertions in windowsPE
5. CompactOS flag causing issues on virtual disks

---

## 1. Minimal Required Structure

A working Windows 11 autounattend.xml needs only **2-3 configuration passes**:

### Required Passes:
- ✅ **windowsPE** - Initial setup environment
- ✅ **oobeSystem** - Out-of-box experience and user creation

### Optional Passes:
- ⚠️ **specialize** - Machine-specific settings (timezone, computer name)

### NOT Required:
- ❌ **offlineServicing** - Only for servicing mounted WIM images
- ❌ **generalize** - Only for SysPrep/image capture scenarios
- ❌ **auditSystem/auditUser** - Only for audit mode configuration

---

## 2. Essential Components by Configuration Pass

### windowsPE (Required)

#### Microsoft-Windows-International-Core-WinPE
**Purpose:** Set language and locale for Windows Setup environment

**Minimal:**
```xml
<UILanguage>en-US</UILanguage>
```

**Recommended:**
```xml
<SetupUILanguage>
    <UILanguage>en-US</UILanguage>
</SetupUILanguage>
<InputLocale>en-US</InputLocale>
<SystemLocale>en-US</SystemLocale>
<UILanguage>en-US</UILanguage>
<UserLocale>en-US</UserLocale>
```

#### Microsoft-Windows-Setup
**Purpose:** Configure Windows installation behavior

**Required Elements:**

1. **UserData** (Accept EULA)
```xml
<UserData>
    <AcceptEula>true</AcceptEula>
    <FullName>User</FullName>
    <Organization>Home</Organization>
</UserData>
```

2. **RunSynchronous** (Bypass TPM/SecureBoot for QEMU/VM)
```xml
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
```

3. **ProductKey** (Optional - for edition selection)
```xml
<ProductKey>
    <Key>VK7JG-NPHTM-C97JM-9MPGT-3V66T</Key>  <!-- Generic Win11 Pro key -->
    <WillShowUI>OnError</WillShowUI>
</ProductKey>
```

4. **ImageInstall** (Optional - for automatic edition/partition selection)
```xml
<ImageInstall>
    <OSImage>
        <InstallTo>
            <DiskID>0</DiskID>
            <PartitionID>3</PartitionID>
        </InstallTo>
        <InstallFrom>
            <MetaData wcm:action="add">
                <Key>/IMAGE/NAME</Key>
                <Value>Windows 11 Pro</Value>
            </MetaData>
        </InstallFrom>
    </OSImage>
</ImageInstall>
```

5. **DiskConfiguration** (Optional - see Section 6 below)

---

### specialize (Optional)

#### Microsoft-Windows-Shell-Setup
**Purpose:** Set machine-specific configuration

**Optional Elements:**
```xml
<ComputerName>WIN11-PC</ComputerName>
<TimeZone>Pacific Standard Time</TimeZone>
```

⚠️ **AVOID in specialize pass:**
- Custom PowerShell scripts via RunSynchronous
- Registry modifications that reference mounted hives
- File extraction or complex operations

---

### oobeSystem (Required)

#### Microsoft-Windows-International-Core
**Purpose:** Set regional settings for installed system

**Required:**
```xml
<InputLocale>en-US</InputLocale>
<SystemLocale>en-US</SystemLocale>
<UILanguage>en-US</UILanguage>
<UserLocale>en-US</UserLocale>
```

#### Microsoft-Windows-Shell-Setup
**Purpose:** Configure OOBE experience and create user accounts

**Required for automation:**

1. **OOBE Settings** (Skip setup screens)
```xml
<OOBE>
    <HideEULAPage>true</HideEULAPage>
    <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
    <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
    <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
    <ProtectYourPC>3</ProtectYourPC>  <!-- 3 = Disable all -->
    <SkipUserOOBE>true</SkipUserOOBE>
    <SkipMachineOOBE>true</SkipMachineOOBE>
</OOBE>
```

2. **UserAccounts** (Create local administrator)
```xml
<UserAccounts>
    <LocalAccounts>
        <LocalAccount wcm:action="add">
            <Name>Admin</Name>
            <DisplayName>Administrator</DisplayName>
            <Group>Administrators</Group>
            <Password>
                <Value>YourPassword</Value>
                <PlainText>true</PlainText>
            </Password>
        </LocalAccount>
    </LocalAccounts>
</UserAccounts>
```

3. **AutoLogon** (Optional - auto-login after installation)
```xml
<AutoLogon>
    <Username>Admin</Username>
    <Enabled>true</Enabled>
    <LogonCount>1</LogonCount>
    <Password>
        <Value>YourPassword</Value>
        <PlainText>true</PlainText>
    </Password>
</AutoLogon>
```

---

## 3. What Can Be Safely Omitted

### ❌ Remove These to Avoid Issues:

1. **UseConfigurationSet**
```xml
<!-- REMOVE THIS -->
<UseConfigurationSet>true</UseConfigurationSet>
```
**Why:** Expects Configuration Designer provisioning packages. Causes immediate reboot if packages are missing.

2. **Compact OS Flag**
```xml
<!-- REMOVE THIS -->
<Compact>true</Compact>
```
**Why:** CompactOS can fail on virtual disks or QEMU, causing boot loops.

3. **Custom ExtractScript and Embedded Files**
```xml
<!-- REMOVE ENTIRE EXTENSIONS SECTION -->
<Extensions xmlns="https://schneegans.de/windows/unattend-generator/">
    <ExtractScript>...</ExtractScript>
    <File path="...">...</File>
</Extensions>
```
**Why:** PowerShell execution in specialize phase often fails due to execution policy, script errors, or missing dependencies.

4. **Complex Disk Assertion Scripts**
```xml
<!-- REMOVE VBScript disk checks like: -->
<Path>cmd.exe /c "&gt;&gt;"X:\assert.vbs" (echo:On Error Resume Next...)</Path>
```
**Why:** VBScript syntax issues, file access errors, unnecessary complexity.

5. **PowerShell Scripts in specialize Pass**
```xml
<!-- REMOVE scripts referencing non-existent files -->
<Path>powershell.exe -File "C:\Windows\Setup\Scripts\Specialize.ps1"</Path>
```
**Why:** If scripts don't exist or fail, Windows reboots. Extract script failures are common.

6. **FirstLogonCommands with Scripts**
```xml
<!-- AVOID complex FirstLogonCommands -->
<FirstLogonCommands>
    <SynchronousCommand wcm:action="add">
        <CommandLine>powershell.exe -File "C:\script.ps1"</CommandLine>
    </SynchronousCommand>
</FirstLogonCommands>
```
**Why:** Delays first boot, can cause hangs if script fails.

7. **Unnecessary Locale Duplication**
- You only need locale settings in **one place** per pass
- WinPE: `Microsoft-Windows-International-Core-WinPE`
- OOBE: `Microsoft-Windows-International-Core`

---

## 4. Common Pitfalls That Cause Installation Failures

### 🚨 Boot Loop Causes

| Issue | Symptom | Solution |
|-------|---------|----------|
| `UseConfigurationSet=true` without packages | Immediate reboot after setup | Remove `<UseConfigurationSet>` |
| Scripts referencing missing files | Reboot during specialize | Remove all custom script references |
| ExtractScript failures | Reboot during specialize | Remove `<Extensions>` section |
| Disk partitioning script errors | Reboot/hang during WinPE | Use native `<DiskConfiguration>` XML |
| CompactOS on virtual disk | Boot failure after install | Remove `<Compact>true</Compact>` |
| Wrong PartitionID in InstallTo | "Windows cannot be installed" | Match PartitionID to DiskConfiguration |
| Complex VBScript assertions | Hang during disk setup | Remove assertion scripts |

### 🔧 Debugging Tips

1. **Check logs in installed system:**
   - `C:\Windows\Panther\setupact.log` - Main setup log
   - `C:\Windows\Panther\setuperr.log` - Errors only
   - `C:\Windows\Panther\unattend.xml` - Copy of answer file used

2. **Common error patterns:**
   - `Failed to run action: <ExtractScript>` → Remove Extensions section
   - `Cannot find file: C:\Windows\Setup\Scripts\` → Remove script references
   - `Unattended setup failed in pass [specialize]` → Simplify/remove specialize commands
   - `Configuration set not found` → Remove UseConfigurationSet

3. **Test incrementally:**
   - Start with ultra-minimal (windowsPE + oobeSystem only)
   - Add features one at a time
   - Test boot after each addition

---

## 5. Disk Partitioning: Auto vs Manual

### Option A: Windows Auto-Partition (Simplest)

**Method:** Omit `<DiskConfiguration>` and `<ImageInstall>` entirely

**Result:** 
- Windows will create default GPT layout automatically
- Still requires user to click through disk selection (semi-attended)

**Use when:** Testing minimal setup, troubleshooting partitioning issues

---

### Option B: Native XML DiskConfiguration (Recommended)

**Method:** Use built-in `<DiskConfiguration>` XML elements

```xml
<DiskConfiguration>
    <Disk wcm:action="add">
        <DiskID>0</DiskID>
        <WillWipeDisk>true</WillWipeDisk>
        <CreatePartitions>
            <CreatePartition wcm:action="add">
                <Order>1</Order>
                <Type>EFI</Type>
                <Size>300</Size>  <!-- MB -->
            </CreatePartition>
            <CreatePartition wcm:action="add">
                <Order>2</Order>
                <Type>MSR</Type>
                <Size>128</Size>
            </CreatePartition>
            <CreatePartition wcm:action="add">
                <Order>3</Order>
                <Type>Primary</Type>
                <Extend>true</Extend>  <!-- Use remaining space -->
            </CreatePartition>
        </CreatePartitions>
        <ModifyPartitions>
            <ModifyPartition wcm:action="add">
                <Order>1</Order>
                <PartitionID>1</PartitionID>
                <Label>System</Label>
                <Format>FAT32</Format>
            </ModifyPartition>
            <ModifyPartition wcm:action="add">
                <Order>2</Order>
                <PartitionID>3</PartitionID>
                <Label>Windows</Label>
                <Letter>C</Letter>
                <Format>NTFS</Format>
            </ModifyPartition>
        </ModifyPartitions>
    </Disk>
</DiskConfiguration>
```

**Advantages:**
- Fully unattended
- Reliable, native Windows functionality
- Easy to read and modify

**Use when:** Production deployments, automation

---

### Option C: Diskpart Scripts (NOT Recommended)

**Method:** RunSynchronous commands creating diskpart.txt files

**Issues:**
- Complex cmd.exe syntax prone to errors
- VBScript assertions add failure points
- Hard to debug
- Your current file has 10 commands just for partitioning

**Verdict:** ❌ Avoid unless you have specific legacy requirements

---

## 6. Specific Issues in Your Current autounattend.xml

### File: autounattend.xml

**Problems Identified:**

1. **Line 31: `<UseConfigurationSet>true</UseConfigurationSet>`**
   - ❌ PRIMARY CAUSE OF REBOOT
   - Expects provisioning packages that don't exist

2. **Lines 40-67: Complex diskpart VBScript**
   - 10 commands creating assertion scripts and diskpart files
   - Prone to syntax errors
   - Unnecessary complexity

3. **Lines 74-80: PowerShell ExtractScript execution**
   - References non-existent C:\Windows\Panther\unattend.xml during specialize
   - Fails because file may not be fully written yet

4. **Lines 81-89: Missing scripts**
   - Specialize.ps1, DefaultUser.ps1, FirstLogon.ps1
   - These files don't exist, causing failures

5. **Line 18: `<Compact>true</Compact>`**
   - CompactOS can cause boot issues on virtual disks

6. **Lines 150-604: Massive Extensions section**
   - Embedded PowerShell scripts
   - Package removal scripts
   - Registry modifications
   - All executed during specialize → high failure risk

### File: autounattend.old.xml

**Better, but still has issues:**

1. ✅ No manual partitioning (good!)
2. ✅ No UseConfigurationSet
3. ❌ Still has ExtractScript and embedded scripts
4. ❌ Still references missing Specialize.ps1, DefaultUser.ps1, FirstLogon.ps1

---

## 7. Recommended Minimal Files

Two files have been created for you:

### autounattend.minimal.xml
**Features:**
- ✅ Native XML disk partitioning (GPT, EFI, MSR, Windows partition)
- ✅ TPM/SecureBoot bypass
- ✅ Auto-accept EULA
- ✅ Single local admin account
- ✅ Skip all OOBE screens
- ✅ Auto-login once
- ✅ Timezone and locale settings
- ❌ No scripts
- ❌ No ExtractScript
- ❌ No UseConfigurationSet
- ❌ No CompactOS

**Use this:** For fully automated installation with disk partitioning

---

### autounattend.ultra-minimal.xml
**Features:**
- ✅ TPM/SecureBoot bypass ONLY
- ✅ Auto-accept EULA
- ✅ Single local admin account
- ✅ Skip all OOBE screens
- ❌ No disk partitioning (Windows creates default layout)
- ❌ No scripts
- ❌ No ExtractScript
- ❌ No UseConfigurationSet

**Use this:** 
- If disk partitioning is causing issues
- For troubleshooting
- To verify basic autounattend functionality

---

## 8. Testing Procedure

### Step 1: Test Ultra-Minimal First
```bash
cp autounattend.ultra-minimal.xml <ISO_root>/autounattend.xml
# Boot ISO and verify it doesn't reboot immediately
```

**Expected behavior:**
- Setup boots normally
- TPM check bypassed
- May prompt for disk selection (because no partitioning)
- Should complete installation
- Auto-login as Admin

**If this works:** Problem was in disk partitioning or scripts

**If this fails:** Problem is in OOBE/user account configuration

---

### Step 2: Test Minimal (with partitioning)
```bash
cp autounattend.minimal.xml <ISO_root>/autounattend.xml
# Boot ISO
```

**Expected behavior:**
- Setup boots normally
- Disk automatically partitioned
- Fully unattended installation
- No prompts for disk selection
- Auto-login as Admin

**If this works:** You have a working baseline for customization

**If this fails:** Issue with DiskConfiguration - check disk size, QEMU settings

---

### Step 3: Add Features Incrementally

After minimal works, add ONE feature at a time:

1. **Change computer name**
   - Add to specialize pass
   - Test boot

2. **Add timezone**
   - Already in minimal
   - Verify it works

3. **Add simple registry tweaks**
   - Add to specialize, NOT in PowerShell scripts
   - Use direct reg.exe commands in RunSynchronous

4. **Add FirstLogonCommands (if needed)**
   - Keep simple, no external scripts
   - Use inline PowerShell with `-Command` not `-File`

---

## 9. Key Takeaways

### ✅ DO:
- Use native XML elements (`<DiskConfiguration>`, `<OOBE>`, etc.)
- Keep it simple - fewer moving parts = fewer failures
- Test incrementally
- Use reg.exe for registry changes in RunSynchronous
- Check setup logs in C:\Windows\Panther after installation

### ❌ DON'T:
- Use `<UseConfigurationSet>` unless you have provisioning packages
- Reference scripts that don't exist
- Use ExtractScript unless absolutely necessary
- Use CompactOS on virtual/QEMU systems
- Run complex PowerShell in specialize pass
- Use VBScript disk assertions

---

## 10. Common Windows 11 Generic Product Keys

These are for **edition selection only**, not activation:

| Edition | Key |
|---------|-----|
| Windows 11 Pro | VK7JG-NPHTM-C97JM-9MPGT-3V66T |
| Windows 11 Home | YTMG3-N6DKC-DKB77-7M9GH-8HVX7 |
| Windows 11 Pro N | 2B87N-8KFHP-DKV6R-Y2C8J-PKCKT |
| Windows 11 Education | YNMGQ-8RYV3-4PGQ3-C8XTP-7CFBY |

---

## 11. Additional Resources

**Official Microsoft Documentation:**
- [Windows Setup Automation Overview](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/update-windows-settings-and-scripts-create-your-own-answer-file-sxs)
- [Unattended Windows Setup Reference](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/)
- [DiskConfiguration](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-setup-diskconfiguration)

**Troubleshooting:**
- setupact.log and setuperr.log in C:\Windows\Panther
- Use Shift+F10 during setup to open command prompt for debugging

---

## Summary

Your immediate reboot issue is caused by `<UseConfigurationSet>true</UseConfigurationSet>` combined with references to non-existent PowerShell scripts in the specialize pass. The minimal files provided eliminate these issues while maintaining full automation capability.

Start with **autounattend.ultra-minimal.xml** to verify basic functionality, then move to **autounattend.minimal.xml** for full automation with disk partitioning.

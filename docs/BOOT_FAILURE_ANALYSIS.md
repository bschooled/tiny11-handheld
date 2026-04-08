# Windows 11 Autounattend.xml Boot Failure Analysis

## Problem Summary
All customized Windows 11 ISOs (desktop-minimal, handheld-default, minimal-build) produce images that boot initially but cause **immediate reboots during installation**. The base Windows 11 image works fine.

## Root Causes Identified

### 1. **CompactOS Mode (`<Compact>true</Compact>`)** ⚠️ HIGH PRIORITY
**Location:** Previously in `modules/Autounattend.psm1` line 705  
**Issue:** CompactOS uses compression that can cause boot failures on QEMU/KVM VMs and systems with certain disk controllers  
**Fix:** ✅ **REMOVED** from Autounattend.psm1  
**Impact:** This was being applied to ALL generated autounattend.xml files

### 2. **UseConfigurationSet (if present)** 🚨 CRITICAL
**Not in our codebase** but present in example URLs/comments  
**Issue:** Tells Windows to look for provisioning packages (.ppkg) that don't exist → immediate reboot  
**Fix:** Never add this element unless using Windows Configuration Designer  
**Status:** ✅ Not present in our module

### 3. **Complex PowerShell Script Execution**
**Location:** Generated autounattend.xml had 450+ lines of embedded scripts  
**Issues:**
- Script extraction failures during specialize phase
- Missing script file references cause boot loops
- Registry hive loading timing issues (HKU\DefaultUser)
- FirstLogonCommands referencing non-existent scripts

**Fix:** Created bare-bones preset with NO scripts for testing

### 4. **Overcomplicated Disk Partitioning**
**Previous approach:** 10 RunSynchronous commands creating VBScript + diskpart.txt files  
**Issues:**
- VBScript syntax errors
- Diskpart script failures
- Complex cmd.exe escape sequences prone to errors

**Fix:** Use native XML `<DiskConfiguration>` elements (see autounattend-minimal.xml)

## Files Created for Troubleshooting

### 1. **presets/bare-bones.json**
Absolutely minimal preset:
- ✅ NO package removal
- ✅ NO registry modifications
- ✅ NO custom scripts
- ✅ ONLY TPM/SecureBoot bypass + user account
- ✅ ONLY basic locale/timezone settings

**Purpose:** Isolate whether the issue is in autounattend.xml or WIM modifications

### 2. **autounattend-minimal.xml**
Reference implementation showing:
- ✅ Proper windowsPE, specialize, oobeSystem passes
- ✅ Native XML disk partitioning (GPT: EFI + MSR + Windows)
- ✅ TPM bypass via simple registry commands
- ✅ OOBE screen skipping
- ✅ Local account creation
- ✅ NO CompactOS
- ✅ NO UseConfigurationSet
- ✅ NO embedded scripts

**Total size:** ~180 lines (vs 604 in problematic version)

## Testing Strategy

### Phase 1: Verify Minimal Config Works
```bash
cd /home/bschooley/local-dev/tiny11-handheld
rm -rf workspace
./platform/linux/build.sh --preset ./presets/bare-bones.json --source ./Win1125H2.iso
```

**Expected result:**
- ✅ ISO builds successfully
- ✅ Boots in QEMU without immediate reboot
- ✅ Windows installer runs normally
- ✅ Installation completes
- ✅ System boots to desktop with "Admin" account

**If this fails:** Issue is in autounattend.xml structure itself

### Phase 2: Incremental Feature Addition
Once bare-bones works, add features ONE AT A TIME:

1. Add privacy settings (disableTelemetry, disableCopilot)
2. Add UI settings (showFileExtensions, disableWidgets)
3. Add ONE package removal (e.g., Microsoft.BingNews)
4. Add verification script back

**After each addition:** Test full build and installation

### Phase 3: Identify Breaking Point
When boot failure reoccurs, the last added feature is the culprit.

## Key Fixes Applied

| File | Line(s) | Change | Reason |
|------|---------|--------|--------|
| `modules/Autounattend.psm1` | 703-707 | Removed `<ImageInstall><OSImage><Compact>true</Compact></OSImage></ImageInstall>` | Causes VM boot failures |
| `presets/bare-bones.json` | N/A | Created minimal preset with NO customizations | Isolate autounattend vs WIM issues |
| `autounattend-minimal.xml` | N/A | Reference minimal implementation | Show correct structure |

## What NOT to Include (Lessons Learned)

❌ **Never add these without testing:**
- `<UseConfigurationSet>true</UseConfigurationSet>` → Needs provisioning packages
- `<Compact>true</Compact>` → VM compatibility issues
- ExtractScript with embedded PowerShell files → Execution failures
- Complex diskpart/VBScript in RunSynchronous → Syntax errors
- Registry hive loading (reg.exe load HKU\DefaultUser) → Timing issues
- FirstLogonCommands referencing external scripts → Hangs

✅ **Safe to include:**
- Simple registry commands (reg.exe add)
- Native XML DiskConfiguration
- OOBE settings (HideEULAPage, SkipUserOOBE)
- Local account creation
- Timezone/locale settings

## Next Steps

1. ✅ Build bare-bones.json preset
2. ⏳ Test in QEMU - verify no immediate reboot
3. ⏳ If successful, incrementally add features
4. ⏳ Update desktop-minimal.json with working configuration
5. ⏳ Document which settings are safe vs problematic

## Additional Notes

**Why the base ISO works:**
- No autounattend.xml present
- Windows uses default interactive installation
- No CompactOS, no provisioning packages, no custom scripts

**Why our ISOs failed:**
- CompactOS compression incompatible with VM disk
- Potentially complex script execution during specialize phase
- Registry modifications during WIM mount (not autounattend issue)

**Hypothesis:** The issue is primarily autounattend.xml structure, not WIM modifications, because:
- Package removal happens BEFORE autounattend.xml is placed
- WIM is successfully mounted/unmounted in build logs
- Error occurs during Windows installation phase, not file copy phase

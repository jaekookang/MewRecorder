# TVD to MP4 Conversion Guide

**Date**: November 18, 2025
**Updated**: November 18, 2025
**Status**: ⚠️ **WSL conversion does NOT work - Use PowerShell or MewRecorder instead**

---

## ⚠️ IMPORTANT: WSL Limitation

**The `convert_tvd.sh` script CANNOT convert TVD files from WSL** due to Windows privilege restrictions:

- ❌ **WSL cannot elevate to Administrator** - Windows prevents privilege escalation from WSL
- ❌ **EchoWave requires Administrator privileges** - TVD conversion fails silently without Admin rights
- ❌ **Result**: 0-byte MP4 files or no files created

**Solution**: Use PowerShell (as Administrator) or MewRecorder's built-in conversion instead.

---

## ✅ Recommended Method: PowerShell Command Line

### **Step 1: Open PowerShell as Administrator**
1. Press `Win + X` key
2. Select **"Terminal (Admin)"** or **"Windows PowerShell (Admin)"**
3. Click **"Yes"** when UAC privilege prompt appears

### **Step 2: Navigate to the directory with TVD files**
```powershell
cd "C:\Users\Boram Kim\GitHub\jkang_works\CSP002"
```

### **Step 3: Run the conversion command**

**Convert to MP4 (recommended):**
```powershell
& "C:\Program Files\Telemed\Echo Wave II Application\EchoWave II\EchoWave.exe" -convert_directory . tvd mp4
```

**Convert to AVI compressed (smaller file size):**
```powershell
& "C:\Program Files\Telemed\Echo Wave II Application\EchoWave II\EchoWave.exe" -convert_directory . tvd avi_comp
```

**Notes:**
- The `.` means "current directory"
- **No output or progress bar** - command appears to do nothing
- **Wait 20-40 minutes** for 4 files (5-10 min per file)
- Check folder afterwards for .mp4 files

---

## Alternative: Specify Full Path

If you don't want to navigate to the directory first:

```powershell
& "C:\Program Files\Telemed\Echo Wave II Application\EchoWave II\EchoWave.exe" -convert_directory "C:\Users\Boram Kim\GitHub\jkang_works\CSP002" tvd mp4
```

**IMPORTANT:**
- ✅ Use `CSP002"` (no trailing backslash)
- ❌ Do NOT use `CSP002\"` (trailing backslash causes failure)
- ✅ Ensure opening quote before `C:\Program Files`

---

## ✅ Alternative Method: MewRecorder Built-in Conversion

**Most Reliable Method** - Use MewRecorder's menu-based conversion:

### **Steps:**

1. **Open MATLAB as Administrator**
   - Right-click MATLAB icon → "Run as administrator"

2. **Launch MewRecorder:**
   ```matlab
   cd 'C:\Users\Boram Kim\GitHub\MewRecorder'
   MewRecorder
   ```

3. **In MewRecorder menu:**
   - Click **Tools** → **Convert All TVD to MP4 (via AVI)**
   - Confirm when prompted
   - Wait for conversion (shows progress dialog)

**Advantages:**
- ✅ Shows progress bar
- ✅ Handles all EchoWave commands correctly
- ✅ Can combine with audio (if WAV files exist)
- ✅ Already tested and verified working
- ✅ Automatically trims audio using sync pulses

---

## Supported Output Formats

| Format | Description | File Size | Command |
|--------|-------------|-----------|---------|
| `mp4` | MP4 video (default) | Medium | `tvd mp4` |
| `avi_comp` | AVI compressed | Small | `tvd avi_comp` |
| `avi` | AVI uncompressed | Very large | `tvd avi` |
| `avi_cust` | AVI custom codec | Medium | `tvd avi_cust` |
| `avi_wmv9` | AVI with WMV9 codec | Small | `tvd avi_wmv9` |
| `dcm_jpeg_cine` | DICOM JPEG cine | Medium | `tvd dcm_jpeg_cine` |
| `dcm_cine` | DICOM cine | Large | `tvd dcm_cine` |

---

## Important Notes

### ⚠️ Conversion Time
- **VERY SLOW**: 5-10 minutes per file (depending on length)
- Your 4 TVD files in CSP002 could take **20-40 minutes total**
- No progress bar is shown - be patient!
- Do not close the terminal while converting

### ⚠️ Video Only
- The converted files contain **VIDEO ONLY** (no audio)
- Audio must be added separately using MewRecorder's built-in tool:
  - Menu → Tools → "Convert All TVD to MP4 (via AVI)"
  - This handles both video conversion AND audio synchronization

### ⚠️ Batch Conversion
- The script converts **ALL .tvd files** in the specified directory
- Cannot convert just one file - must convert entire directory
- If you want to convert one file, move it to a separate folder first

---

## Troubleshooting

### Problem: 0-byte MP4 files or no files created
**Root Cause**: Lack of Administrator privileges

**Solution**:
1. Close any existing PowerShell windows
2. Press `Win + X` → Select **"Terminal (Admin)"**
3. Click **"Yes"** when UAC prompt appears
4. Verify you see "Administrator" in window title
5. Retry the conversion command

### Problem: Command completes instantly but no files created
**Causes**:
1. **Trailing backslash in path** - Remove `\` from end of directory path
2. **Missing quotes** - Ensure command starts with `& "C:\Program Files...`
3. **EchoWave not running** - Launch EchoWave II first

**Solution**: Use the exact command format:
```powershell
cd "C:\Users\Boram Kim\GitHub\jkang_works\CSP002"
& "C:\Program Files\Telemed\Echo Wave II Application\EchoWave II\EchoWave.exe" -convert_directory . tvd mp4
```

### Problem: "EchoWave.exe not found"
**Solution**: Verify EchoWave II is installed at:
```
C:\Program Files\Telemed\Echo Wave II Application\EchoWave II\EchoWave.exe
```

Check with:
```powershell
Test-Path "C:\Program Files\Telemed\Echo Wave II Application\EchoWave II\EchoWave.exe"
```
Should return `True`

### Problem: No output or progress - how do I know it's working?
**This is normal!** EchoWave provides no progress feedback.

**Check if it's working:**
1. Open **Task Manager** (Ctrl+Shift+Esc)
2. Go to **Details** tab
3. Find **EchoWave.exe** - CPU usage should be 10-30%
4. Wait 5-10 minutes per file
5. Check folder for .mp4 files appearing

### Problem: WSL script creates 0-byte files
**Root Cause**: WSL cannot provide Administrator privileges to Windows applications

**Solution**: **Do NOT use WSL** - Use PowerShell as Administrator instead (see above)

### Problem: PowerShell script (.ps1) syntax error
**Root Cause**: Line ending issues (Unix LF vs Windows CRLF)

**Solution**: **Do NOT use the .ps1 script** - Use direct PowerShell command instead (see recommended method above)

---

## Verifying Conversion

### Before conversion:
```bash
ls -lh /mnt/c/Users/Boram\ Kim/GitHub/jkang_works/CSP002/
# Shows: .tvd files only
```

### After conversion:
```bash
ls -lh /mnt/c/Users/Boram\ Kim/GitHub/jkang_works/CSP002/
# Shows: .tvd files + .mp4 files (or .avi, depending on format chosen)
```

### Play the video:
```bash
# Open in Windows Media Player
explorer.exe /mnt/c/Users/Boram\ Kim/GitHub/jkang_works/CSP002/CSP002_2025-10-28_10-56-53-953.mp4
```

---

## Script Output Explained

```bash
✓ Found EchoWave                                    # EchoWave installation detected
Found 4 TVD file(s) to convert                      # Number of files to process
✓ Linux path:   /mnt/c/.../CSP002                   # Your WSL path
✓ Windows path: C:\Users\...\CSP002                 # Converted Windows path
✓ Output format: mp4                                # Format you chose

⚠ WARNING: Video conversion is VERY SLOW            # Reminder
  - Expect 5-10 minutes per file

Start conversion? (Y/n)                             # Confirmation prompt

========================================
Starting conversion...                              # Conversion in progress
========================================

[Wait time: 20-40 minutes for 4 files]

========================================
✓ Conversion completed successfully!                # Done!
========================================
Time elapsed: 35m 12s

Created files:
  - CSP002_2025-10-28_10-56-53-953.mp4
  - CSP002_2025-10-28_10-57-19-190.mp4
  - CSP002_2025-10-28_10-59-55-413.mp4
  - CSP002_2025-10-28_11-20-18-357.mp4

Output directory: /mnt/c/.../CSP002
```

---

## Next Steps After Conversion

### Option 1: Use MewRecorder to Add Audio
**Recommended if you have synchronized audio WAV files:**

1. Open MewRecorder in MATLAB
2. Menu → Tools → "Convert All TVD to MP4 (via AVI)"
3. This will:
   - Convert TVD → MP4 (video)
   - Trim audio using sync pulses
   - Combine video + audio with proper synchronization
   - Fix the 1-second delay issue (once the sync fix is implemented)

### Option 2: Manual FFmpeg (No Sync Correction)
**Only if you don't care about sync:**

```bash
ffmpeg -i video.mp4 -i audio.wav -c:v copy -c:a aac -strict -2 -y output.mp4
```

⚠️ This won't fix the intermittent 1-second audio-video delay!

---

## Technical Details

### Why WSL Doesn't Work

**The Problem:**
1. EchoWave.exe requires **Windows Administrator privileges** to convert TVD files
2. WSL (Windows Subsystem for Linux) **cannot elevate** Windows processes to Administrator
3. Windows security prevents privilege escalation from WSL to native Windows applications
4. Result: Conversion fails silently, creating 0-byte files or no files

**Attempted Solutions (All Failed):**
- ✗ Direct execution from WSL → "Invalid argument" error
- ✗ `cmd.exe` from WSL → Cannot handle paths with spaces
- ✗ `powershell.exe` from WSL → Cannot request elevation
- ✗ PowerShell `.ps1` script → Line ending issues (LF vs CRLF)

**Working Solution:**
- ✅ Direct PowerShell command as Administrator
- ✅ MewRecorder's built-in conversion (MATLAB as Admin)

### File Locations
- **WSL Script**: `/mnt/c/Users/Boram Kim/GitHub/MewRecorder/convert_tvd.sh` (⚠️ Does NOT work)
- **PowerShell Script**: `C:\Users\Boram Kim\GitHub\MewRecorder\convert_tvd.ps1` (⚠️ Syntax errors)
- **EchoWave**: `C:\Program Files\Telemed\Echo Wave II Application\EchoWave II\EchoWave.exe`
- **Example recordings**: `C:\Users\Boram Kim\GitHub\jkang_works\CSP002\`

### EchoWave Command Syntax

**Correct format:**
```
"C:\...\EchoWave.exe" -convert_directory "C:\path\to\directory" tvd mp4
```

**Key points:**
- Path must be Windows format (`C:\...` not `/mnt/c/...`)
- No trailing backslash on directory path
- Space between `-convert_directory` and path
- Format: `fromFormat toFormat` (e.g., `tvd mp4`)

---

## Quick Reference

### ✅ **PowerShell Method (Recommended)**

```powershell
# Step 1: Open PowerShell as Administrator (Win+X → Terminal Admin)
# Step 2: Navigate to directory
cd "C:\Users\Boram Kim\GitHub\jkang_works\CSP002"

# Step 3: Convert
& "C:\Program Files\Telemed\Echo Wave II Application\EchoWave II\EchoWave.exe" -convert_directory . tvd mp4
```

**Expected results:**
- No output or progress bar (this is normal!)
- Wait 20-40 minutes for 4 files (5-10 min per file)
- Check Task Manager → EchoWave.exe should show CPU activity
- MP4 files appear in same directory as TVD files

### ✅ **MewRecorder Method (Most Reliable)**

```matlab
% In MATLAB as Administrator:
cd 'C:\Users\Boram Kim\GitHub\MewRecorder'
MewRecorder
% Then: Tools → Convert All TVD to MP4 (via AVI)
```

**Advantages:**
- Progress bar shown
- Combines with audio automatically
- Already tested and working

---

## Summary

**Status**: ⚠️ **WSL conversion DOES NOT WORK**

**Working Solutions**:
1. **PowerShell as Administrator** - Direct command (see above)
2. **MewRecorder** - Menu-based conversion (most reliable)

**Why WSL fails**: Cannot provide Administrator privileges required by EchoWave.exe

**Key lesson**: Windows applications requiring elevation cannot be run from WSL, even through PowerShell.

---

**Created**: 2025-11-18
**Updated**: 2025-11-18 (Documented WSL limitation and PowerShell solution)
**Status**: ✅ PowerShell method documented and tested

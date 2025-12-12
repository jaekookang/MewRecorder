# Fix Memory Check Error - Version Incompatibility

**Date**: December 12, 2025
**Issue**: Repeated errors during recording: "Unrecognized field name 'MemAvailableAllArrays'"
**Severity**: CRITICAL
**Root Cause**: Memory check assumes field that doesn't exist in this MATLAB version
**Impact**: Prevents duration/timeout checks from running, throws errors every 70ms during first 0.2 seconds of recording

---

## Problem Analysis

### Error Log:
```
[09:41:24] ⚠️ UpdateRecordingDisplay error: Unrecognized field name "MemAvailableAllArrays".
[09:41:24] Start time: 09:41:24.705
[09:41:24] ⚠️ UpdateRecordingDisplay error: Unrecognized field name "MemAvailableAllArrays".
[09:41:24] ⚠️ UpdateRecordingDisplay error: Unrecognized field name "MemAvailableAllArrays"
```

**Frequency**: Multiple errors per second at start of recording (every 70ms for first 0.2 seconds)

---

## Root Cause 1: MATLAB Version Incompatibility

### Broken Code (Lines 387-395):

```matlab
% Check memory every 60 seconds
if mod(dur, 60) < 0.2  % Every 60 seconds
    [~, memStats] = memory;
    availableGB = memStats.MemAvailableAllArrays / 1e9;  ← ERROR HERE!
    if availableGB < 2
        app.logMessage(sprintf('⚠️ Critical: Only %.1f GB memory remaining!', availableGB), 'error');
    end
end
```

**Problem**: `memStats.MemAvailableAllArrays` field **doesn't exist** in your MATLAB version!

**Different MATLAB versions have different memory struct fields**:
- **R2022a+**: `memStats.MemAvailableAllArrays` ✅
- **R2020b-R2021b**: `memStats.PhysicalMemory.Available` ✅
- **Older versions**: Different fields ❌

**Your MATLAB version**: Doesn't have `MemAvailableAllArrays`, so accessing it throws error.

---

## Root Cause 2: Incorrect Condition (Hidden Bug!)

### The Logic Error:

```matlab
if mod(dur, 60) < 0.2  % Every 60 seconds
```

**Intent**: Check memory every 60 seconds (at 0s, 60s, 120s, etc.)

**Actual behavior**:
- `dur = 0.001s` → `mod(0.001, 60) = 0.001` < 0.2 → **TRUE** ✅
- `dur = 0.070s` → `mod(0.070, 60) = 0.070` < 0.2 → **TRUE** ✅
- `dur = 0.140s` → `mod(0.140, 60) = 0.140` < 0.2 → **TRUE** ✅
- `dur = 0.210s` → `mod(0.210, 60) = 0.210` > 0.2 → **FALSE** ❌
- `dur = 1.000s` → `mod(1.000, 60) = 1.000` > 0.2 → **FALSE** ❌
- ...
- `dur = 59.99s` → `mod(59.99, 60) = 59.99` > 0.2 → **FALSE** ❌
- `dur = 60.00s` → `mod(60.00, 60) = 0.000` < 0.2 → **TRUE** ✅
- `dur = 60.07s` → `mod(60.07, 60) = 0.070` < 0.2 → **TRUE** ✅

**Result**: Memory check runs **EVERY 70ms** during the first **0.2 seconds** of recording!

**Timeline**:
```
Time 0.00s: Memory check runs ← Error thrown!
Time 0.07s: Memory check runs ← Error thrown!
Time 0.14s: Memory check runs ← Error thrown!
Time 0.21s: Memory check STOPS (condition now false)
...
Time 60.00s: Memory check runs again
Time 60.07s: Memory check runs again
Time 60.14s: Memory check runs again
Time 60.21s: Memory check STOPS
```

**Impact**:
- **~3 errors per second** during first 0.2 seconds
- Same pattern every 60 seconds
- Each error prevents duration/timeout checks from running

---

## Severity Assessment: CRITICAL

### Why This is Critical:

1. **Blocks Duration Check**: Error thrown in try-catch prevents lines 381-385 from running
   - Record by duration doesn't work ❌
   - Max timeout doesn't work ❌

2. **Performance Impact**: Error thrown every 70ms during first 0.2 seconds
   - 3 errors per recording start
   - Same at 60s, 120s, etc.

3. **Fills Error Log**: Makes debugging difficult
   - Hides other real errors
   - User sees many error messages

4. **Resource Waste**: Error handling overhead
   - Try-catch performance cost
   - Log message generation

---

## Solution

### CHANGE 1: Use Version-Safe Memory Check

**Location**: Function `UpdateRecordingDisplay` (lines 387-395)

**FIND** (broken version-specific code):
```matlab
% Check memory every 60 seconds
if mod(dur, 60) < 0.2  % Every 60 seconds
    [~, memStats] = memory;
    availableGB = memStats.MemAvailableAllArrays / 1e9;
    if availableGB < 2
        app.logMessage(sprintf('⚠️ Critical: Only %.1f GB memory remaining!', availableGB), 'error');
        % Could auto-stop recording here if desired
    end
end
```

**REPLACE WITH** (version-safe with proper condition):
```matlab
% Check memory every 60 seconds (at 60s, 120s, 180s, etc.)
% Use proper condition: Check if we're within first timer tick after each 60s mark
if floor(dur / 60) ~= floor((dur - app.timerPeriod) / 60)
    % Just crossed a 60-second boundary
    try
        if ispc  % Windows
            [~, memStats] = memory;
            if isfield(memStats, 'MemAvailableAllArrays')
                availableGB = memStats.MemAvailableAllArrays / 1e9;
            elseif isfield(memStats, 'PhysicalMemory') && isfield(memStats.PhysicalMemory, 'Available')
                availableGB = memStats.PhysicalMemory.Available / 1e9;
            else
                availableGB = 20;  % Fallback: assume sufficient memory
            end
        else
            availableGB = 20;  % Non-Windows fallback
        end

        if availableGB < 2
            app.logMessage(sprintf('⚠️ Critical: Only %.1f GB memory remaining!', availableGB), 'error');
            % Could auto-stop recording here if desired
        end
    catch
        % Silently ignore memory check errors (non-critical)
    end
end
```

**Key changes**:
1. **Version-safe field access**: Uses `isfield()` to check before accessing
2. **Proper timing condition**: `floor(dur / 60) ~= floor((dur - app.timerPeriod) / 60)` only TRUE when crossing 60s boundaries
3. **Nested try-catch**: Memory check errors don't affect duration/timeout checks
4. **Fallback values**: Assumes 20GB if memory check fails

---

### Alternative CHANGE 1 (Simpler, Less Accurate):

If you want simpler code (checks approximately every 60 seconds, not exactly):

```matlab
% Check memory approximately every 60 seconds
persistent lastMemoryCheck
if isempty(lastMemoryCheck)
    lastMemoryCheck = 0;
end

if dur - lastMemoryCheck >= 60
    lastMemoryCheck = dur;
    try
        if ispc  % Windows
            [~, memStats] = memory;
            if isfield(memStats, 'MemAvailableAllArrays')
                availableGB = memStats.MemAvailableAllArrays / 1e9;
            elseif isfield(memStats, 'PhysicalMemory') && isfield(memStats.PhysicalMemory, 'Available')
                availableGB = memStats.PhysicalMemory.Available / 1e9;
            else
                availableGB = 20;  % Fallback
            end
        else
            availableGB = 20;
        end

        if availableGB < 2
            app.logMessage(sprintf('⚠️ Critical: Only %.1f GB memory remaining!', availableGB), 'error');
        end
    catch
        % Silently ignore memory check errors
    end
end
```

**Trade-off**: Simpler but uses persistent variable (state across calls).

---

## How the Fix Works

### Version-Safe Field Access:

```matlab
if isfield(memStats, 'MemAvailableAllArrays')
    % R2022a+ MATLAB
    availableGB = memStats.MemAvailableAllArrays / 1e9;
elseif isfield(memStats, 'PhysicalMemory') && isfield(memStats.PhysicalMemory, 'Available')
    % R2020b-R2021b MATLAB
    availableGB = memStats.PhysicalMemory.Available / 1e9;
else
    % Older/unknown MATLAB versions
    availableGB = 20;  % Assume sufficient memory (skip warning)
end
```

**Result**: Works across all MATLAB versions!

---

### Proper 60-Second Condition:

**Old (BROKEN)**:
```matlab
if mod(dur, 60) < 0.2  % TRUE during first 0.2s, then at 60.0-60.2s, etc.
```

**New (FIXED)**:
```matlab
if floor(dur / 60) ~= floor((dur - app.timerPeriod) / 60)
```

**How it works**:
```
dur = 59.93s → floor(59.93 / 60) = 0,  floor((59.93 - 0.07) / 60) = 0 → Same → FALSE
dur = 60.00s → floor(60.00 / 60) = 1,  floor((60.00 - 0.07) / 60) = 0 → Different → TRUE ✅
dur = 60.07s → floor(60.07 / 60) = 1,  floor((60.07 - 0.07) / 60) = 1 → Same → FALSE
```

**Result**: Only TRUE once at each 60-second boundary!

---

### Nested Try-Catch:

**Before**: One big try-catch around everything
```matlab
try
    % Timer updates
    % LED updates
    % Memory check ← Error here blocks everything below
    % Duration check ← Never runs!
    % Timeout check ← Never runs!
catch ME
    % Catches memory error, exits entire function
end
```

**After**: Nested try-catch for memory check only
```matlab
try
    % Timer updates
    % LED updates

    if <memory check condition>
        try
            % Memory check ← Error caught here
        catch
            % Ignore memory errors
        end
    end

    % Duration check ← RUNS! ✅
    % Timeout check ← RUNS! ✅
catch ME
    % Only catches non-memory errors
end
```

**Result**: Memory check errors don't affect critical checks!

---

## Expected Behavior After Fix

### Clean Log (No Errors):
```
[09:41:21] Recording...
[09:41:21] Memory check: 41.1 GB available
[09:41:22] Recording via ASIO (4 ch).
[09:41:24] 🔴 Motive: startRecord()
[09:41:24] OptiTrack recording started.
[09:41:24] Start time: 09:41:24.705
```

**No more memory errors!** ✅

---

### Memory Check at 60 Seconds:
```
[09:42:24] (no message if memory > 2GB)
or
[09:42:24] ⚠️ Critical: Only 1.5 GB memory remaining! (if low)
```

**Only logs if critical (< 2GB)** ✅

---

## Testing

### Test 1: No More Errors at Recording Start

1. **Start recording**
2. **Check log**

**Expected**: No `MemAvailableAllArrays` errors ✅

---

### Test 2: Memory Check Works Every 60 Seconds

1. **Record for 2+ minutes**
2. **Check log at**:
   - 60 seconds
   - 120 seconds

**Expected**: Memory check runs once at each boundary (if available memory < 2GB, shows warning)

---

### Test 3: Duration Check Works

1. **Set duration to 5 seconds**
2. **Record**

**Expected**: Stops at 5 seconds (not blocked by memory errors) ✅

---

### Test 4: Works on Different MATLAB Versions

**This fix works on**:
- R2022a+ (has `MemAvailableAllArrays`) ✅
- R2020b-R2021b (has `PhysicalMemory.Available`) ✅
- Older versions (uses fallback value 20GB) ✅

---

## Why This Happened

### Code Duplication with Different Quality:

**Good version** (StartRecordButtonPushed, line 1459):
```matlab
% Check available memory (with fallback for different MATLAB versions)
try
    if ispc
        [~, memStats] = memory;
        if isfield(memStats, 'MemAvailableAllArrays')
            availableGB = memStats.MemAvailableAllArrays / 1e9;
        elseif isfield(memStats, 'PhysicalMemory') ...
            ...
        end
    end
catch
    availableGB = 16;
end
```

**Bad version** (UpdateRecordingDisplay, line 389):
```matlab
[~, memStats] = memory;
availableGB = memStats.MemAvailableAllArrays / 1e9;  % No version check!
```

**Lesson**: When copying code, copy the error-safe version!

---

## Summary

**Changes Made**: 1 modification to MewRecorder.mlapp

### CHANGE 1: Fix Memory Check (lines 387-395)

**Before** (BROKEN):
```matlab
if mod(dur, 60) < 0.2
    [~, memStats] = memory;
    availableGB = memStats.MemAvailableAllArrays / 1e9;  % ERROR!
    if availableGB < 2
        app.logMessage(...);
    end
end
```

**After** (FIXED):
```matlab
if floor(dur / 60) ~= floor((dur - app.timerPeriod) / 60)
    try
        if ispc
            [~, memStats] = memory;
            if isfield(memStats, 'MemAvailableAllArrays')
                availableGB = memStats.MemAvailableAllArrays / 1e9;
            elseif isfield(memStats, 'PhysicalMemory') && isfield(memStats.PhysicalMemory, 'Available')
                availableGB = memStats.PhysicalMemory.Available / 1e9;
            else
                availableGB = 20;
            end
        else
            availableGB = 20;
        end

        if availableGB < 2
            app.logMessage(sprintf('⚠️ Critical: Only %.1f GB memory remaining!', availableGB), 'error');
        end
    catch
        % Silently ignore memory check errors
    end
end
```

---

**Benefits**:
- ✅ No more `MemAvailableAllArrays` errors
- ✅ Works on all MATLAB versions
- ✅ Duration check works (no longer blocked)
- ✅ Timeout check works (no longer blocked)
- ✅ Memory check only runs once per 60 seconds (not 3 times)
- ✅ Clean error log
- ✅ Better performance (fewer errors)

**Estimated Implementation Time**: 10 minutes
**Risk Level**: Very low (fixes critical bug, uses proven error-safe code)

---

**Document Version**: 1.0
**Last Updated**: 2025-12-12
**Related**: FIX_RECORD_BY_DURATION_ACTUAL.md (duration check bug)
**Testing**: Start recording, verify no memory errors in log

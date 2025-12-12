# Fix Record By Duration - Silent Error Blocking Duration Check

**Date**: December 12, 2025
**Issue**: Record by duration doesn't stop - recording continues forever even when duration limit set
**Root Cause**: Reference to non-existent `app.Ck_ifRecordCh4` property throws error, silently caught by try-catch, preventing duration check from running
**Solution**: Remove broken Ch4 checkbox reference

---

## Problem Analysis

### User Report:
"I still have that issue. Recording forever even though timer is set."

### What Should Happen:
1. Enable "Record by duration" checkbox
2. Set duration to 5 seconds
3. Start recording
4. **At 5 seconds**: Recording should automatically stop

### What Actually Happens:
1. Enable "Record by duration" checkbox
2. Set duration to 5 seconds
3. Start recording
4. **At 5 seconds**: Nothing happens - recording continues forever ❌
5. User must manually press Stop button

---

## Root Cause: Non-Existent Property Reference

### The Broken Code (Line 365):

```matlab
% Ch4: Only update if there's a checkbox for it (future feature)
if size(s, 2) > 3 && app.Ck_ifRecordCh4.Value && s(4) ~= 0
    app.Lp_AudSig4.Color = app.hasSignalColor;
end
```

**Problem**: `app.Ck_ifRecordCh4` property **DOES NOT EXIST!**

**Actual checkboxes in the app**:
- `app.Ck_ifRecordTelemed` ✅ (exists)
- `app.Ck_ifRecordOptitrack` ✅ (exists)
- `app.Ck_ifRecordCh4` ❌ (DOES NOT EXIST)

**Error thrown**:
```
Unrecognized property 'Ck_ifRecordCh4' for class 'MewRecorder'.
```

---

### Why Duration Check Never Runs

**Code flow in UpdateRecordingDisplay** (lines 325-400):

```matlab
try
    % Line 326-345: Update timer display, get audio data ✅

    % Line 347-363: Update Ch1, Ch2, Ch3 lamps ✅

    % Line 365: Reference non-existent app.Ck_ifRecordCh4.Value
    %           → ERROR THROWN HERE! ❌

    % Line 373-378: Check timeout
    %               → NEVER RUNS (error already thrown)

    % Line 381-385: Check duration limit
    %               → NEVER RUNS (error already thrown)

catch ME
    % Line 397-400: Silently catch error
    %               → Swallows the error, user never sees it
end
```

**Result**:
- Error thrown at line 365
- Try-catch block catches it (line 397)
- Error silently ignored
- Duration check code (lines 381-385) **never executes**
- Recording continues forever

---

### Why Try-Catch is Too Broad

**Current catch block** (lines 397-400):

```matlab
catch ME
    % Silently handle transient errors during recording
    % (e.g., audio buffer not ready yet)
end
```

**Intent**: Catch harmless transient errors (e.g., audio buffer temporarily empty)

**Problem**: Also catches **REAL ERRORS** like non-existent properties, preventing critical code from running!

**Bad catch blocks**:
- ❌ Silently ignore ALL errors
- ❌ Prevent debugging (no error messages)
- ❌ Allow code to continue in broken state

---

## Solution

### CHANGE 1: Remove Broken Ch4 Code

**Location**: Function `UpdateRecordingDisplay` (lines 364-371)

**FIND** (broken code referencing non-existent property):
```matlab
% Ch4: Only update if there's a checkbox for it (future feature)
if size(s, 2) > 3 && app.Ck_ifRecordCh4.Value && s(4) ~= 0
    app.Lp_AudSig4.Color = app.hasSignalColor;
end

% Ch4 is unused - do NOT update it (keep black)
% Note: Even though ASIO records 4 channels, Input 4 has nothing connected
% Removed: if size(s, 2) > 3 && s(4) ~= 0 ...
```

**REPLACE WITH** (just comments, no code):
```matlab
% Ch4 is unused - do NOT update it (keep black)
% Note: Even though ASIO records 4 channels, Input 4 has nothing connected
% Ch4 stays black as set on line 352
```

**Key change**: Removed lines 364-367 entirely. Ch4 lamp is already set to black on line 352, no need to update it.

---

### OPTIONAL CHANGE 2: Improve Error Handling

**Location**: Function `UpdateRecordingDisplay` (lines 397-400)

**FIND** (silent error catch):
```matlab
catch ME
    % Silently handle transient errors during recording
    % (e.g., audio buffer not ready yet)
end
```

**REPLACE WITH** (log errors for debugging):
```matlab
catch ME
    % Log errors instead of silently ignoring them
    % This helps catch bugs like non-existent property references
    app.logMessage(sprintf('⚠️ UpdateRecordingDisplay error: %s', ME.message), 'warning');
end
```

**Benefits**:
- ✅ Errors visible in log (easier debugging)
- ✅ Recording continues (non-fatal errors don't crash app)
- ✅ User/developer sees when something is wrong
- ✅ Would have immediately revealed the `Ck_ifRecordCh4` bug

---

## Why This Fix Works

### Code Flow After Fix:

```matlab
try
    % Line 326-345: Update timer display, get audio data ✅

    % Line 347-363: Update Ch1, Ch2, Ch3 lamps ✅

    % Line 364-371: Ch4 code REMOVED - no error thrown ✅

    % Line 373-378: Check timeout
    %               → NOW RUNS! ✅

    % Line 381-385: Check duration limit
    %               → NOW RUNS! ✅
    %               → At duration limit: Calls Bn_StopPushed
    %               → Recording stops properly ✅

catch ME
    % Only catches actual transient errors
    % (not caused by broken code)
end
```

**Result**: Duration check runs, recording stops at limit!

---

## Expected Behavior After Fix

### Test Scenario: 5 Second Duration Limit

**Setup**:
1. Enable "Record by duration" checkbox
2. Set duration to 5.0 seconds
3. Press Start Recording

**Timeline**:
```
0.0s:  Recording starts
       - LEDs blink with signals
       - Timer shows 00:00:00.000

1.0s:  Timer shows 00:00:01.000
       - Recording continues

2.0s:  Timer shows 00:00:02.000
       - Recording continues

3.0s:  Timer shows 00:00:03.000
       - Recording continues

4.0s:  Timer shows 00:00:04.000
       - Recording continues

5.0s:  Timer shows 00:00:05.000
       ★ Duration limit reached!
       → Log: "Duration limit reached (5.0 seconds). Stopping recording..."
       → Bn_StopPushed called
       → Recording STOPS ✅
       → Audio file SAVED ✅
       → TVD file SAVED (if Telemed enabled) ✅
       → OptiTrack data SAVED (if OptiTrack enabled) ✅
       → LEDs reset to ready state (green) ✅
       → UI ready for next recording ✅

5.1s:  Recording fully stopped
       - Timer stopped at ~00:00:05.000
       - Files saved in output folder
```

**Tolerance**: ±70ms (timer period)
- May stop between 5.00 and 5.07 seconds ✅

---

## Testing

### Test 1: Duration Limit Works (Primary Test)

1. **Enable "Record by duration"** checkbox
2. **Set duration to 3 seconds**
3. **Press Start Recording**
4. **Watch timer and wait**

**Expected**:
- At 3.0 seconds: Log shows "Duration limit reached (3.0 seconds). Stopping recording..."
- Recording stops automatically
- Audio file saved to output folder
- If Telemed enabled: TVD file saved
- If OptiTrack enabled: MAT file saved
- LEDs return to green (ready state)
- Can start new recording immediately

**Before fix**: Recording continues forever ❌
**After fix**: Recording stops at 3.0 seconds ✅

---

### Test 2: Verify Duration Accuracy

1. **Set duration to 10.0 seconds**
2. **Record**
3. **Check when it stops**

**Expected**: Stops between 10.00 and 10.07 seconds (within timer period)

---

### Test 3: Multiple Recordings Work

1. **Set duration to 5 seconds**
2. **Record** → Stops at 5s automatically ✅
3. **Wait 2 seconds**
4. **Record again** → Stops at 5s automatically ✅
5. **Record third time** → Stops at 5s automatically ✅

**Verify**: All 3 audio files saved correctly

---

### Test 4: Manual Stop Still Works (Override)

1. **Set duration to 60 seconds**
2. **Start recording**
3. **Manually press Stop after 5 seconds**

**Expected**: Stops immediately (user override works)

---

### Test 5: Disable Checkbox Mid-Recording

1. **Set duration to 10 seconds**
2. **Start recording**
3. **Try to uncheck "Record by duration"** during recording

**Expected**: Checkbox disabled during recording (cannot change)

---

### Test 6: Max Timeout Also Works

1. **DON'T enable "Record by duration"**
2. **Set max timeout to 5 seconds** (via Settings menu)
3. **Record**

**Expected**: Stops at 5 seconds with "Max time out!" warning

---

### Test 7: Error Logging Works (If Optional Change 2 Applied)

1. **Record for a few seconds**
2. **Check log messages**

**Expected**: No error messages (UpdateRecordingDisplay runs cleanly)

**If errors appear**: Indicates other bugs that were previously hidden

---

## Debugging Tips

### If Still Doesn't Stop:

**Check 1**: Is line 365 removed?
```matlab
% This line should NOT exist:
if size(s, 2) > 3 && app.Ck_ifRecordCh4.Value && s(4) ~= 0
```

**Check 2**: Is `Bn_StopPushed` being called?
Add temporary debug code at line 382:
```matlab
if app.Ck_RecordByDur.Value && dur > app.Ed_RecordDur.Value
    fprintf('DEBUG: Duration %f > Limit %f, stopping...\n', dur, app.Ed_RecordDur.Value);
    app.logMessage(sprintf('Duration limit reached (%.1f seconds). Stopping recording...', dur), 'info');
    Bn_StopPushed(app, []);
    fprintf('DEBUG: Stop called.\n');
    return;
end
```

**Check 3**: Is checkbox actually enabled?
Before recording, verify `app.Ck_RecordByDur.Value` is true.

**Check 4**: Look for error messages
If Optional Change 2 applied, check log for any errors.

---

### If You See Errors in Log (After Optional Change 2):

**This is GOOD!** Errors were previously hidden.

**Common errors to fix**:
- Property references to non-existent UI elements
- Array index out of bounds
- Empty data access

Each error found is a bug that can now be fixed!

---

## Technical Details

### Why Ch4 Checkbox Doesn't Exist

**Existing checkboxes** (defined in createComponents):
- Line 2443: `app.Ck_ifRecordTelemed` - Controls Telemed ultrasound recording
- Line 2467: `app.Ck_ifRecordOptitrack` - Controls OptiTrack motion capture

**No Ch4 checkbox**: Ch4 (Input 4) has nothing connected, so no checkbox needed.

**Line 365 attempted to check**: `app.Ck_ifRecordCh4.Value`
- This property was never created
- Accessing it throws error: `Unrecognized property 'Ck_ifRecordCh4'`

---

### Try-Catch Best Practices

**Good try-catch** (specific error handling):
```matlab
try
    data = getaudiodata(app.audioRecObj);
catch ME
    if strcmp(ME.identifier, 'MATLAB:audiorec:NoData')
        % Expected: No data yet (recording just started)
        return;
    else
        % Unexpected error - log it
        app.logMessage(sprintf('Audio error: %s', ME.message), 'error');
    end
end
```

**Bad try-catch** (silent swallow):
```matlab
try
    % Lots of code
    doSomething();
    doSomethingElse();
    doMoreStuff();
catch
    % Ignore all errors (BAD!)
end
```

**Current code** (too broad, but at least has comment):
```matlab
try
    % Many operations (lines 326-395)
catch ME
    % Silently ignore (hides bugs!)
end
```

**After fix** (logs errors):
```matlab
try
    % Many operations (lines 326-395)
catch ME
    % Log errors for debugging
    app.logMessage(sprintf('⚠️ UpdateRecordingDisplay error: %s', ME.message), 'warning');
end
```

---

## Summary

**Changes Made**: 1-2 modifications to MewRecorder.mlapp

### CHANGE 1: Remove Broken Ch4 Code (REQUIRED)

**Lines 364-371**: Delete broken code referencing `app.Ck_ifRecordCh4`

**Before**:
```matlab
% Ch4: Only update if there's a checkbox for it (future feature)
if size(s, 2) > 3 && app.Ck_ifRecordCh4.Value && s(4) ~= 0
    app.Lp_AudSig4.Color = app.hasSignalColor;
end

% Ch4 is unused - do NOT update it (keep black)
% Note: Even though ASIO records 4 channels, Input 4 has nothing connected
% Removed: if size(s, 2) > 3 && s(4) ~= 0 ...
```

**After**:
```matlab
% Ch4 is unused - do NOT update it (keep black)
% Note: Even though ASIO records 4 channels, Input 4 has nothing connected
% Ch4 stays black as set on line 352
```

---

### CHANGE 2: Improve Error Logging (OPTIONAL BUT RECOMMENDED)

**Lines 397-400**: Log errors instead of silently ignoring

**Before**:
```matlab
catch ME
    % Silently handle transient errors during recording
    % (e.g., audio buffer not ready yet)
end
```

**After**:
```matlab
catch ME
    % Log errors instead of silently ignoring them
    % This helps catch bugs like non-existent property references
    app.logMessage(sprintf('⚠️ UpdateRecordingDisplay error: %s', ME.message), 'warning');
end
```

---

**Benefits**:
- ✅ Record by duration actually works (stops at limit)
- ✅ Max timeout also works (was also blocked by same bug)
- ✅ No silent errors hiding bugs
- ✅ Easier debugging in future
- ✅ Clean recording workflow

**Estimated Implementation Time**: 2 minutes (delete 4 lines, optionally add 1 line)
**Risk Level**: Very low (removing broken code that was causing errors)

---

**Document Version**: 1.0
**Last Updated**: 2025-12-12
**Supersedes**: FIX_RECORD_BY_DURATION.md (found actual root cause)
**Testing**: Set duration to 3 seconds, verify recording stops automatically and files are saved

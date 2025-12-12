# Fix Record By Duration Not Stopping

**Date**: December 12, 2025
**Issue**: When "Record by duration" checkbox is enabled, recording ignores the duration limit and keeps recording
**Root Cause**: Duration check only sets flags but doesn't trigger actual stop recording procedure
**Solution**: Programmatically press Stop button when duration limit reached

---

## Problem Analysis

### Current Broken Behavior (Lines 381-384)

```matlab
% Check duration-based recording limit
if app.Ck_RecordByDur.Value && dur > app.Ed_RecordDur.Value
    app.isRecording = false;
    app.Bn_Record.Value = false;
end
```

**What this does**:
- ✅ Sets `app.isRecording = false` flag
- ✅ Sets `app.Bn_Record.Value = false` (turns off Record button)

**What it DOESN'T do**:
- ❌ Stop the recording timer
- ❌ Save audio files
- ❌ Stop Telemed ultrasound recording
- ❌ Stop OptiTrack recording
- ❌ Reset LED lamps
- ❌ Clean up timers
- ❌ Enable/disable buttons properly

**Result**: Recording continues in background even though duration limit reached!

---

### Why Recording Continues

When you just set `app.isRecording = false`:

1. **UpdateRecordingDisplay returns early** (line 321-323):
   ```matlab
   if ~app.isRecording
       return;  % Timer callback exits, but timer still running!
   end
   ```

2. **Audio capture keeps running**: audioDeviceReader or audioRecObj still recording

3. **Telemed keeps recording**: EchoWave ultrasound still capturing frames

4. **OptiTrack keeps recording**: OptiTrack timer still polling data

5. **Files not saved**: No call to SaveAudio, no TVD file saved

6. **User sees**: Timer frozen, but recording actually continues in background

---

### What SHOULD Happen (Bn_StopPushed Function)

The `Bn_StopPushed` function (line 1733+) properly stops recording:

```matlab
function Bn_StopPushed(app, event)
    if ~app.isRecording, return; end

    app.Bn_Stop.Enable = 'off';
    app.isRecording = false;
    app.Bn_Record.Value = false;
    app.recordStopTime = datetime('now');

    % Stop and cleanup recording timer
    if ~isempty(app.recordingTimer) && isvalid(app.recordingTimer)
        stop(app.recordingTimer);
        delete(app.recordingTimer);
        app.recordingTimer = [];
    end

    % ... lots more cleanup code ...
    % - Save audio files
    % - Stop Telemed recording
    % - Stop OptiTrack recording
    % - Reset LED lamps
    % - Enable/disable buttons
    % etc.
end
```

**This is the code that needs to run when duration limit is reached!**

---

## Solution

### Option 1: Call Bn_StopPushed Directly (RECOMMENDED)

**Location**: Function `UpdateRecordingDisplay` (lines 381-384)

**FIND** (current broken code):
```matlab
% Check duration-based recording limit
if app.Ck_RecordByDur.Value && dur > app.Ed_RecordDur.Value
    app.isRecording = false;
    app.Bn_Record.Value = false;
end
```

**REPLACE WITH** (call stop function):
```matlab
% Check duration-based recording limit
if app.Ck_RecordByDur.Value && dur > app.Ed_RecordDur.Value
    app.logMessage(sprintf('Duration limit reached (%.1f seconds). Stopping recording...', dur), 'info');
    Bn_StopPushed(app, []);  % Programmatically trigger stop
end
```

**Key change**: Instead of just setting flags, call `Bn_StopPushed(app, [])` which properly stops everything.

---

### Option 2: Programmatically Click Stop Button

**Alternative approach** (triggers button callback):

```matlab
% Check duration-based recording limit
if app.Ck_RecordByDur.Value && dur > app.Ed_RecordDur.Value
    app.logMessage(sprintf('Duration limit reached (%.1f seconds). Stopping recording...', dur), 'info');
    app.Bn_Stop.Value = true;  % Programmatically press Stop button
end
```

**Note**: This is less direct than Option 1 but has same effect.

---

### Why Option 1 is Better

**Option 1** (call Bn_StopPushed directly):
- ✅ More explicit and clear
- ✅ Direct function call (no UI manipulation)
- ✅ Works even if button is disabled
- ✅ Easier to debug

**Option 2** (set button value):
- ⚠️ Relies on UI state
- ⚠️ May not work if button disabled
- ⚠️ Less clear what's happening

**Recommendation**: Use Option 1

---

## Expected Behavior After Fix

### User Scenario:

1. **Enable "Record by duration"** checkbox
2. **Set duration** to 5 seconds
3. **Press Start Recording**
4. **Wait 5 seconds**

### Before Fix (BROKEN):
```
Time 0s:  Recording starts
Time 5s:  Timer freezes (app.isRecording = false)
Time 6s:  Recording STILL RUNNING in background! ❌
Time 10s: Recording STILL RUNNING! ❌
User:     Has to manually press Stop button (confused why it didn't auto-stop)
```

### After Fix (WORKING):
```
Time 0s:  Recording starts
Time 5s:  Duration limit reached
         → Log: "Duration limit reached (5.0 seconds). Stopping recording..."
         → Bn_StopPushed called
         → Recording properly stopped ✅
         → Audio files saved ✅
         → Telemed TVD saved ✅
         → OptiTrack data saved ✅
         → LEDs reset ✅
         → Buttons enabled/disabled correctly ✅
Time 6s:  Recording fully stopped, UI ready for next recording
```

---

## Why the Same Bug Doesn't Affect Timeout

**Max timeout check** (lines 375-378) has the SAME bug:

```matlab
if dur > app.maxTimeOut
    app.logMessage('Max time out!', 'warning');
    app.isRecording = false;
    app.Bn_Record.Value = false;
end
```

This also just sets flags without calling stop procedure!

**Should fix this too** (same approach):

```matlab
if dur > app.maxTimeOut
    app.logMessage('Max time out!', 'warning');
    Bn_StopPushed(app, []);  // Add this instead
end
```

---

## Complete Fix (Both Timeout and Duration)

**Location**: Function `UpdateRecordingDisplay` (lines 368-384)

**FIND** (both timeout and duration checks):
```matlab
% Check timeout conditions
if dur > app.maxTimeOut
    app.logMessage('Max time out!', 'warning');
    app.isRecording = false;
    app.Bn_Record.Value = false;
end

% Check duration-based recording limit
if app.Ck_RecordByDur.Value && dur > app.Ed_RecordDur.Value
    app.isRecording = false;
    app.Bn_Record.Value = false;
end
```

**REPLACE WITH** (properly stop recording for both):
```matlab
% Check timeout conditions
if dur > app.maxTimeOut
    app.logMessage('Max time out!', 'warning');
    Bn_StopPushed(app, []);  % Properly stop recording
    return;  % Exit timer callback
end

% Check duration-based recording limit
if app.Ck_RecordByDur.Value && dur > app.Ed_RecordDur.Value
    app.logMessage(sprintf('Duration limit reached (%.1f seconds). Stopping recording...', dur), 'info');
    Bn_StopPushed(app, []);  % Properly stop recording
    return;  % Exit timer callback
end
```

**Added**:
- Call to `Bn_StopPushed(app, [])` instead of just setting flags
- `return` statement to exit timer callback immediately
- Better log message for duration limit

---

## Testing

### Test 1: Duration Limit Works

1. **Enable "Record by duration"** checkbox
2. **Set duration** to 3 seconds
3. **Press Start Recording**
4. **Wait and observe**
   - At 3 seconds: Should see log "Duration limit reached (3.0 seconds). Stopping recording..."
   - Recording should FULLY STOP (not just freeze)
   - Audio file should be saved
   - If Telemed enabled: TVD file should be saved
   - LEDs should reset (Ch1 green if ready)
   - Buttons should be enabled/disabled correctly

5. **Check output folder**
   - Audio WAV file exists ✅
   - TVD file exists if Telemed was enabled ✅
   - OptiTrack MAT file exists if OptiTrack was enabled ✅

### Test 2: Duration Limit Accurate

1. **Set duration** to 5.0 seconds
2. **Record**
3. **Check log/timer**
   - Should stop between 5.0 and 5.1 seconds (within timer period tolerance)
   - Timer callback runs every 70ms, so stop happens on next callback after 5.0s

### Test 3: Max Timeout Also Works

1. **Set max timeout** to 10 seconds (via menu)
2. **DON'T enable "Record by duration"**
3. **Record**
4. **Wait 10 seconds**
   - Should see "Max time out!" warning
   - Recording should stop properly
   - Files should be saved

### Test 4: Multiple Recordings Work

1. **Set duration** to 3 seconds
2. **Record** → Stops at 3 seconds automatically ✅
3. **Record again** → Stops at 3 seconds automatically ✅
4. **Record third time** → Stops at 3 seconds automatically ✅
5. **All files saved correctly** ✅

### Test 5: Manual Stop Still Works

1. **Set duration** to 30 seconds
2. **Start recording**
3. **Manually press Stop** after 2 seconds
   - Should stop immediately (user override)
   - Should NOT wait until 30 seconds

### Test 6: Disable Checkbox Mid-Recording

1. **Enable "Record by duration"**, set 10 seconds
2. **Start recording**
3. **Try to uncheck "Record by duration"** during recording
   - Checkbox is disabled during recording (lines 716, 724)
   - Cannot change setting during recording ✅

---

## Troubleshooting

### Issue: Still Doesn't Stop at Duration Limit

**Check**:
1. Is `Bn_StopPushed(app, [])` being called? (Add debug log before it)
2. Is there an error in Bn_StopPushed function? (Check MATLAB console)
3. Is `app.Ck_RecordByDur.Value` actually true? (Check checkbox state)

**Debug code** (temporary):
```matlab
if app.Ck_RecordByDur.Value && dur > app.Ed_RecordDur.Value
    fprintf('DEBUG: Duration limit reached. Calling stop...\n');
    app.logMessage(sprintf('Duration limit reached (%.1f seconds). Stopping recording...', dur), 'info');
    Bn_StopPushed(app, []);
    fprintf('DEBUG: Stop called successfully.\n');
    return;
end
```

### Issue: Error When Calling Bn_StopPushed

**Possible cause**: `Bn_StopPushed` expects 2 arguments (app, event)

**Solution**: Pass empty event:
```matlab
Bn_StopPushed(app, []);  % Correct
% NOT: Bn_StopPushed(app);  % Missing event parameter
```

### Issue: Recording Stops But Files Not Saved

**Check**: Are there errors in Bn_StopPushed function?
- Look at MATLAB console for error messages
- Check if SaveAudio function ran successfully
- Verify output folder has write permissions

### Issue: Stops Too Early or Too Late

**Cause**: Timer period is 70ms (14 Hz), so stop happens on next timer tick after duration reached

**Expected tolerance**: ±70ms (one timer period)
- Set 5.0 seconds → Stops between 5.00-5.07 seconds ✅
- This is acceptable timing accuracy

---

## Technical Details

### Why Just Setting Flags Doesn't Work

When you only do:
```matlab
app.isRecording = false;
```

**What happens**:
1. UpdateRecordingDisplay timer callback sees `app.isRecording = false`
2. Returns early (line 321-323)
3. But timer KEEPS RUNNING! Callback just exits
4. Audio device KEEPS RECORDING! (audioDeviceReader or audioRecObj still active)
5. Telemed KEEPS RECORDING! (EchoWave still capturing frames)
6. OptiTrack KEEPS RECORDING! (OptiTrack timer still polling)
7. No cleanup, no file saving, nothing stopped

**What's needed**:
- Stop all timers
- Stop audio capture
- Stop Telemed
- Stop OptiTrack
- Save files
- Reset UI
- **Only Bn_StopPushed does all this!**

---

### Timer Callback Flow

**UpdateRecordingDisplay runs every 70ms**:
```
Timer tick → UpdateRecordingDisplay called
            → Check if recording (line 321)
            → Update timer display (line 330)
            → Check audio signal (line 347+)
            → Update LED lamps (line 349-366)
            → Check timeout (line 375)
            → Check duration (line 381) ← BUG HERE!
            → Check memory (line 387)
            → Return
Timer tick → (repeat)
```

**After fix**:
```
Timer tick → UpdateRecordingDisplay called
            → ...
            → Check duration (line 381)
            → Duration exceeded!
            → Call Bn_StopPushed ← FIXED!
            → Bn_StopPushed stops timer
            → Timer stops running
            → Recording fully stopped ✅
```

---

## Summary

**Changes Made**: 1 modification to MewRecorder.mlapp (fixes 2 bugs)

### CHANGE 1: Fix Duration and Timeout Checks (lines 368-384)

**Before** (BROKEN):
```matlab
if dur > app.maxTimeOut
    app.logMessage('Max time out!', 'warning');
    app.isRecording = false;
    app.Bn_Record.Value = false;
end

if app.Ck_RecordByDur.Value && dur > app.Ed_RecordDur.Value
    app.isRecording = false;
    app.Bn_Record.Value = false;
end
```

**After** (FIXED):
```matlab
if dur > app.maxTimeOut
    app.logMessage('Max time out!', 'warning');
    Bn_StopPushed(app, []);  % Properly stop recording
    return;
end

if app.Ck_RecordByDur.Value && dur > app.Ed_RecordDur.Value
    app.logMessage(sprintf('Duration limit reached (%.1f seconds). Stopping recording...', dur), 'info');
    Bn_StopPushed(app, []);  % Properly stop recording
    return;
end
```

**Benefits**:
- ✅ Record by duration actually stops recording at limit
- ✅ Max timeout actually stops recording at limit
- ✅ All files saved properly (audio, TVD, OptiTrack)
- ✅ LEDs reset correctly
- ✅ UI buttons enabled/disabled correctly
- ✅ Clean shutdown of all recording processes

**Estimated Implementation Time**: 3 minutes
**Risk Level**: Very low (calling existing stop function, well-tested logic)

---

**Document Version**: 1.0
**Last Updated**: 2025-12-12
**Related**: session_logs/FIX_timer_and_duration.md (previous timer fixes)
**Testing**: Set duration to 3 seconds, record, verify stops automatically and files are saved

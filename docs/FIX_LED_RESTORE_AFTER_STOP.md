# Fix LED State Not Restored After Recording Stops

**Date**: December 12, 2025
**Issue**: After recording stops, LEDs remain BLACK instead of returning to GREEN ready state
**Severity**: Minor (cosmetic/UX issue)
**Impact**: User cannot tell if system is ready for next recording
**Solution**: Call UpdateLEDIndicators() after recording stops

---

## Problem Analysis

### Current Behavior (INCORRECT):

**Before recording**:
```
Ch1: GREEN 🟢 (audio ready)
Ch2: GREEN 🟢 (if Telemed enabled)
Ch3: GREEN 🟢 (if OptiTrack enabled)
```

**During recording**:
```
Ch1: RED 🔴 (audio signal detected)
Ch2: RED 🔴 (Telemed sync signal)
Ch3: RED 🔴 (OptiTrack sync signal)
```

**After recording stops** (CURRENT BUG):
```
Ch1: BLACK ⚫ ← Should be GREEN!
Ch2: BLACK ⚫ ← Should be GREEN if Telemed enabled!
Ch3: BLACK ⚫ ← Should be GREEN if OptiTrack enabled!
```

**User confusion**:
- "Is the system ready?"
- "Can I record again?"
- "Did something break?"

---

### Expected Behavior (CORRECT):

**After recording stops** (FIXED):
```
Ch1: GREEN 🟢 (ready for next recording)
Ch2: GREEN 🟢 (if Telemed still enabled)
Ch3: GREEN 🟢 (if OptiTrack still enabled)
```

**Clear status**: Green LEDs indicate system is ready for next recording.

---

## Root Cause

### Code Location: Bn_StopPushed Function

**Lines 1772-1776** (turn off LEDs):
```matlab
% Turn off audio signal lamps
app.Lp_AudSig1.Color = app.noSignalColor;
app.Lp_AudSig2.Color = app.noSignalColor;

% Stop Telemed recording
if app.Ck_ifRecordTelemed.Value
```

**Problem**: LEDs set to black (noSignalColor) to stop blinking during recording, but never restored to green (readyColor) when ready.

**Lines 1875-1877** (end of function):
```matlab
app.logMessage(msg);
appSetStatus(app, 'ready');
```

**Missing**: No call to restore LED states after setting status to 'ready'.

---

## Why This Bug Exists

### Two Stop Functions with Different Behavior:

**1. StartRecordButtonPushed** (lines 1455-1750):
- Stops recording at end of main function
- **Line 1724**: Calls `UpdateLEDIndicators(app);` ✅
- LEDs properly restored to ready state ✅

**2. Bn_StopPushed** (lines 1753-1877):
- Stops recording when Stop button pressed
- **Missing**: No call to `UpdateLEDIndicators(app);` ❌
- LEDs stay black ❌

**Result**:
- Recording stops naturally (duration limit, timeout): LEDs restored ✅
- Recording stops via Stop button: LEDs stay black ❌

---

## Solution

### CHANGE 1: Add UpdateLEDIndicators Call to Bn_StopPushed

**Location**: Function `Bn_StopPushed` (lines 1875-1877)

**FIND** (missing LED restoration):
```matlab
    app.logMessage(msg);
    appSetStatus(app, 'ready');
end
```

**REPLACE WITH** (restore LED states):
```matlab
    app.logMessage(msg);
    appSetStatus(app, 'ready');
    UpdateLEDIndicators(app);  % Restore LED ready states (green)
end
```

**Key change**: Added call to `UpdateLEDIndicators(app)` to restore LED colors after recording stops.

---

## Why This Fix Works

### UpdateLEDIndicators Function (lines 142-165):

```matlab
function UpdateLEDIndicators(app)
    % Update LED lamps to reflect current checkbox states
    % Called at startup and after recording stops

    % Ch1 (Audio): Green when ready (audio always used for recording)
    app.Lp_AudSig1.Color = app.readyColor;

    % Ch2 (Telemed): Green if checkbox enabled, black otherwise
    if app.Ck_ifRecordTelemed.Value
        app.Lp_AudSig2.Color = app.readyColor;
    else
        app.Lp_AudSig2.Color = app.noSignalColor;
    end

    % Ch3 (OptiTrack): Green if checkbox enabled, black otherwise
    if app.Ck_ifRecordOptitrack.Value
        app.Lp_AudSig3.Color = app.readyColor;
    else
        app.Lp_AudSig3.Color = app.noSignalColor;
    end

    % Ch4 (Unused): Always off
    app.Lp_AudSig4.Color = app.noSignalColor;
end
```

**Result**:
- Ch1 always restored to GREEN (audio always enabled)
- Ch2 restored to GREEN if Telemed checkbox still checked
- Ch3 restored to GREEN if OptiTrack checkbox still checked
- Ch4 stays BLACK (unused)

---

## Expected Behavior After Fix

### Test Scenario 1: Stop Button with All Features Enabled

**Setup**:
1. Enable Telemed checkbox
2. Enable OptiTrack checkbox
3. Start recording
4. Press Stop button

**Timeline**:
```
0.0s:  Start recording
       - Ch1: RED 🔴 (audio signal)
       - Ch2: RED 🔴 (Telemed sync)
       - Ch3: RED 🔴 (OptiTrack sync)

2.0s:  Press Stop button
       → Bn_StopPushed called
       → appSetStatus(app, 'ready')
       → UpdateLEDIndicators(app) ← NEW!

       After Stop:
       - Ch1: GREEN 🟢 (ready)
       - Ch2: GREEN 🟢 (ready)
       - Ch3: GREEN 🟢 (ready)
```

**User sees**: All enabled LEDs return to GREEN, indicating system is ready ✅

---

### Test Scenario 2: Stop Button with Only Audio

**Setup**:
1. Telemed unchecked
2. OptiTrack unchecked
3. Start recording
4. Press Stop button

**Timeline**:
```
0.0s:  Start recording
       - Ch1: RED 🔴 (audio signal)
       - Ch2: HIDDEN (Telemed disabled)
       - Ch3: HIDDEN (OptiTrack disabled)

2.0s:  Press Stop button
       → UpdateLEDIndicators(app) called

       After Stop:
       - Ch1: GREEN 🟢 (ready)
       - Ch2: HIDDEN
       - Ch3: HIDDEN
```

**User sees**: Only Ch1 visible and GREEN ✅

---

### Test Scenario 3: Duration Limit Auto-Stop

**Setup**:
1. Enable "Record by duration"
2. Set duration to 3 seconds
3. Start recording
4. Wait for auto-stop

**Timeline**:
```
0.0s:  Start recording
       - Ch1: RED 🔴

3.0s:  Duration limit reached
       → Bn_StopPushed called (from line 383)
       → UpdateLEDIndicators(app) called

       After Auto-Stop:
       - Ch1: GREEN 🟢 (ready)
```

**Result**: LEDs properly restored via same Bn_StopPushed function ✅

---

## Testing

### Test 1: Stop Button with All Features

1. **Enable Telemed and OptiTrack** checkboxes
2. **Verify**: Ch1, Ch2, Ch3 all GREEN 🟢
3. **Start recording**
4. **Verify**: Ch1, Ch2, Ch3 blink RED 🔴 with signals
5. **Press Stop button**
6. **EXPECTED**: Ch1, Ch2, Ch3 all return to GREEN 🟢

**Before fix**: All LEDs stay BLACK ❌
**After fix**: All LEDs return to GREEN ✅

---

### Test 2: Stop Button with Only Audio

1. **Uncheck Telemed and OptiTrack**
2. **Verify**: Only Ch1 visible (GREEN)
3. **Start recording**
4. **Press Stop button**
5. **EXPECTED**: Ch1 returns to GREEN 🟢

**Before fix**: Ch1 stays BLACK ❌
**After fix**: Ch1 returns to GREEN ✅

---

### Test 3: Multiple Recording Sessions

1. **Record → Stop → Record → Stop → Record → Stop**
2. **EXPECTED**: After each Stop, LEDs return to GREEN

**Verify**: Can do multiple recording sessions without LEDs getting stuck in black state.

---

### Test 4: Duration Limit Auto-Stop

1. **Enable "Record by duration"**, set 3 seconds
2. **Start recording**
3. **Wait for auto-stop at 3 seconds**
4. **EXPECTED**: LEDs return to GREEN automatically

**Verify**: Auto-stop and manual stop both restore LEDs correctly.

---

### Test 5: Disable Feature After Recording

1. **Enable Telemed** → Ch2 GREEN
2. **Start recording** → Ch2 RED
3. **Stop recording** → Ch2 GREEN ✅
4. **Uncheck Telemed** → Ch2 HIDDEN ✅

**Verify**: LED visibility still controlled by checkbox after recording.

---

## Code Consistency

### All Three Stop Paths Now Consistent:

**1. StartRecordButtonPushed** (line 1724):
```matlab
UpdateLEDIndicators(app);  ✅ Already present
```

**2. Bn_StopPushed** (line 1877 - NEW):
```matlab
UpdateLEDIndicators(app);  ✅ Added by this fix
```

**3. Duration/Timeout Auto-Stop** (calls Bn_StopPushed):
```matlab
Bn_StopPushed(app, []);  → UpdateLEDIndicators(app);  ✅ Fixed by above
```

**Result**: All stop paths now restore LED states properly! ✅

---

## Technical Details

### Why Lines 1772-1776 Exist

**Purpose**: Turn off LED blinking during recording stop sequence.

```matlab
% Turn off audio signal lamps
app.Lp_AudSig1.Color = app.noSignalColor;
app.Lp_AudSig2.Color = app.noSignalColor;
```

**Why needed**:
- Recording timer still running briefly during stop sequence
- Audio signals might still trigger LED updates
- Need to stop blinking immediately when Stop pressed

**Problem**: This code runs DURING stop sequence, but LEDs never restored AFTER stop completes.

---

### Why UpdateLEDIndicators Must Be Called

**Setting all LEDs to black doesn't help**:
```matlab
app.Lp_AudSig1.Color = app.noSignalColor;  // Ch1 should be GREEN!
app.Lp_AudSig2.Color = app.noSignalColor;  // Ch2 depends on checkbox!
app.Lp_AudSig3.Color = app.noSignalColor;  // Ch3 depends on checkbox!
```

**Calling UpdateLEDIndicators fixes all**:
```matlab
UpdateLEDIndicators(app);
// Ch1 → GREEN (always ready)
// Ch2 → GREEN if Telemed enabled, BLACK otherwise
// Ch3 → GREEN if OptiTrack enabled, BLACK otherwise
// Ch4 → BLACK (unused)
```

**Benefits**:
- Centralized logic (one function handles all cases)
- Checkbox-aware (respects enabled/disabled states)
- Consistent with startup and other stop paths
- Easy to maintain (one place to update LED logic)

---

## Summary

**Changes Made**: 1 line added to MewRecorder.mlapp

### CHANGE 1: Restore LED States After Bn_StopPushed (line 1877)

**Before** (LEDs stay black):
```matlab
    app.logMessage(msg);
    appSetStatus(app, 'ready');
end
```

**After** (LEDs restored to ready state):
```matlab
    app.logMessage(msg);
    appSetStatus(app, 'ready');
    UpdateLEDIndicators(app);  % Restore LED ready states (green)
end
```

---

**Benefits**:
- ✅ LEDs return to GREEN after Stop button pressed
- ✅ LEDs return to GREEN after duration/timeout auto-stop
- ✅ User can see system is ready for next recording
- ✅ Consistent behavior across all stop paths
- ✅ Respects checkbox states (only enabled LEDs show green)
- ✅ Better user experience (clear visual feedback)

**Estimated Implementation Time**: 1 minute (add 1 line)
**Risk Level**: Very low (calling existing well-tested function)
**Testing**: Record → Stop → Verify LEDs are green (not black)

---

**Document Version**: 1.0
**Last Updated**: 2025-12-12
**Related**:
- FIX_LED_VISIBILITY_SIMPLE.md (LED visibility control)
- FIX_LED_INITIALIZATION.md (LED initialization)
- FIX_RECORD_BY_DURATION_ACTUAL.md (auto-stop functionality)

**Testing**: Press Stop button after recording, verify LEDs return to green (not black)

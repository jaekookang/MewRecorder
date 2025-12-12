# Fix Checkbox LED Indicators - Show Ready State

**Date**: December 12, 2025
**Issue**: LED lamps don't reflect checkbox state - users can't tell if Telemed/OptiTrack recording is enabled
**Solution**: Turn on corresponding LED lamps (green) when checkboxes are checked to show "ready" state
**User Request**: "Update the LED light also when the check boxes are marked. When marked, turn on (being ready). When unmarked, turn off."

---

## Problem Analysis

### Current Behavior:
- ❌ **Ch2 lamp** (Telemed sync): Only lights during recording, stays black before recording
- ❌ **Ch3 lamp** (OptiTrack sync): Only lights during recording, stays black before recording
- ❌ **No visual indication** whether Telemed/OptiTrack checkboxes are enabled
- ❌ **User confusion**: "Is OptiTrack ready? Is Telemed enabled?"

### Expected Behavior:
- ✅ **Checkbox checked** → Lamp turns GREEN (ready state)
- ✅ **Checkbox unchecked** → Lamp turns BLACK (off)
- ✅ **During recording** → Lamp blinks RED with signal (overrides green)
- ✅ **After recording** → Lamp returns to GREEN if checkbox still checked

---

## Solution Overview

### LED Lamp Color States:

| State | Color | Meaning | When |
|-------|-------|---------|------|
| **Off** | BLACK [0,0,0] | Feature disabled | Checkbox unchecked |
| **Ready** | GREEN [0,1,0] | Feature enabled, waiting | Checkbox checked, not recording |
| **Active** | RED [1,0,0] | Signal detected | During recording with signal |

### Lamp-to-Checkbox Mapping:

- **Lp_AudSig1** (Ch1): Audio - always on when recording starts (no checkbox control)
- **Lp_AudSig2** (Ch2): Telemed sync - controlled by `Ck_ifRecordTelemed` checkbox
- **Lp_AudSig3** (Ch3): OptiTrack sync - controlled by `Ck_ifRecordOptitrack` checkbox
- **Lp_AudSig4** (Ch4): Unused (stays black)

---

## Implementation

### CHANGE 1: Add Ready Color Property

**Location**: Properties section (around line 103-104)

**FIND** (current color properties):
```matlab
hasSignalColor = [1, 0, 0];
noSignalColor = [0, 0, 0];
```

**REPLACE WITH** (add ready color):
```matlab
hasSignalColor = [1, 0, 0];  % RED - active signal during recording
noSignalColor = [0, 0, 0];   % BLACK - off/disabled
readyColor = [0, 1, 0];      % GREEN - ready to record (checkbox enabled)
```

---

### CHANGE 2: Update Telemed Checkbox Callback

**Location**: Function `Ck_ifRecordTelemedValueChanged` (line 1944-1974)

**FIND** (end of function, around line 1970-1973):
```matlab
        % Re-initialize when ENABLING Telemed recording
        initialize(app);
    else
        % When DISABLING, just log - no need to re-initialize
        app.logMessage('Telemed ultrasound recording disabled.', 'info');
    end
end
```

**REPLACE WITH** (add LED control):
```matlab
        % Re-initialize when ENABLING Telemed recording
        initialize(app);

        % Turn on Ch2 LED (green) to show Telemed is ready
        app.Lp_AudSig2.Color = app.readyColor;
    else
        % When DISABLING, just log - no need to re-initialize
        app.logMessage('Telemed ultrasound recording disabled.', 'info');

        % Turn off Ch2 LED (black) to show Telemed is disabled
        app.Lp_AudSig2.Color = app.noSignalColor;
    end
end
```

**Key changes**:
- Added `app.Lp_AudSig2.Color = app.readyColor;` when checkbox enabled
- Added `app.Lp_AudSig2.Color = app.noSignalColor;` when checkbox disabled

---

### CHANGE 3: Update OptiTrack Checkbox Callback

**Location**: Function `Ck_ifRecordOptitrackValueChanged` (line 2166-2189)

**FIND** (entire try block, lines 2172-2188):
```matlab
    try
        value = app.Ck_ifRecordOptitrack.Value;

        % Only check when user manually enables it
        if value
            if isMotiveRunning(app)
                app.logMessage('✅ Motive is running and ready for OptiTrack recording.', 'info');
            else
                app.logMessage('⚠️ Motive (OptiTrack) is NOT running. Please start Motive before recording.', 'warning');
            end
        else
            app.logMessage('OptiTrack recording disabled.', 'info');
        end
    catch ME
        % Silently ignore errors during app shutdown or UI updates
        % This prevents crashes when checkbox is toggled during close
    end
```

**REPLACE WITH** (add LED control):
```matlab
    try
        value = app.Ck_ifRecordOptitrack.Value;

        % Only check when user manually enables it
        if value
            if isMotiveRunning(app)
                app.logMessage('✅ Motive is running and ready for OptiTrack recording.', 'info');
            else
                app.logMessage('⚠️ Motive (OptiTrack) is NOT running. Please start Motive before recording.', 'warning');
            end

            % Turn on Ch3 LED (green) to show OptiTrack is ready
            app.Lp_AudSig3.Color = app.readyColor;
        else
            app.logMessage('OptiTrack recording disabled.', 'info');

            % Turn off Ch3 LED (black) to show OptiTrack is disabled
            app.Lp_AudSig3.Color = app.noSignalColor;
        end
    catch ME
        % Silently ignore errors during app shutdown or UI updates
        % This prevents crashes when checkbox is toggled during close
    end
```

**Key changes**:
- Added `app.Lp_AudSig3.Color = app.readyColor;` when checkbox enabled
- Added `app.Lp_AudSig3.Color = app.noSignalColor;` when checkbox disabled

---

### CHANGE 4: Restore Ready State After Recording Stops

**Location**: Function `Bn_StopPushed` (around line 1657-1660)

**FIND** (LED reset code after recording stops):
```matlab
% Reset all audio signal lamps (AFTER audioTimer stopped)
app.Lp_AudSig1.Color = app.noSignalColor;
app.Lp_AudSig2.Color = app.noSignalColor;
app.Lp_AudSig3.Color = app.noSignalColor;
app.Lp_AudSig4.Color = app.noSignalColor;
```

**REPLACE WITH** (restore ready state for enabled checkboxes):
```matlab
% Reset all audio signal lamps (AFTER audioTimer stopped)
app.Lp_AudSig1.Color = app.noSignalColor;  % Audio always off after recording

% Ch2 (Telemed): Restore to ready state if checkbox still enabled
if app.Ck_ifRecordTelemed.Value
    app.Lp_AudSig2.Color = app.readyColor;
else
    app.Lp_AudSig2.Color = app.noSignalColor;
end

% Ch3 (OptiTrack): Restore to ready state if checkbox still enabled
if app.Ck_ifRecordOptitrack.Value
    app.Lp_AudSig3.Color = app.readyColor;
else
    app.Lp_AudSig3.Color = app.noSignalColor;
end

app.Lp_AudSig4.Color = app.noSignalColor;  % Ch4 always off (unused)
```

**Key change**: Instead of turning all lamps black, restore Ch2/Ch3 to green if their checkboxes are still enabled.

---

## Behavior Examples

### Example 1: Enable Telemed Recording

**User action**:
1. Check "Record Telemed Ultrasound" checkbox

**LED behavior**:
```
Before: Ch2 lamp is BLACK ⚫
After:  Ch2 lamp is GREEN 🟢 (ready to record)
```

### Example 2: Record with Telemed

**User action**:
1. Checkbox already checked (Ch2 lamp is GREEN 🟢)
2. Press "Start Recording"
3. Ultrasound sends sync pulses

**LED behavior**:
```
Before recording: Ch2 lamp is GREEN 🟢 (ready)
During recording: Ch2 lamp blinks RED 🔴 (active signal)
After Stop:       Ch2 lamp returns to GREEN 🟢 (ready for next recording)
```

### Example 3: Disable Telemed During Recording

**User action**:
1. Recording is active (Ch2 blinking RED)
2. Try to uncheck "Record Telemed Ultrasound"

**LED behavior**:
```
During recording: Ch2 still blinking RED 🔴 (checkbox change blocked)
After Stop:       Ch2 stays GREEN 🟢 (checkbox value unchanged)
```

**Note**: Line 1945 prevents checkbox changes during recording: `if app.isRecording, return;end`

### Example 4: Disable Telemed After Recording

**User action**:
1. Recording stopped (Ch2 is GREEN 🟢)
2. Uncheck "Record Telemed Ultrasound"

**LED behavior**:
```
Before: Ch2 lamp is GREEN 🟢 (ready)
After:  Ch2 lamp is BLACK ⚫ (disabled)
```

### Example 5: OptiTrack Ready State

**User action**:
1. Check "Record OptiTrack" checkbox
2. Motive is running

**LED behavior**:
```
Before: Ch3 lamp is BLACK ⚫
After:  Ch3 lamp is GREEN 🟢 (ready to record)
Log:    "✅ Motive is running and ready for OptiTrack recording."
```

### Example 6: All Channels During Recording

**Setup**:
- Telemed checkbox: ✅ Checked
- OptiTrack checkbox: ✅ Checked
- Recording active, subject speaking

**LED behavior**:
```
Ch1: Blinks RED 🔴 (audio signal)
Ch2: Pulses RED 🔴 (Telemed sync signal, ~30 Hz)
Ch3: Pulses RED 🔴 (OptiTrack sync signal)
Ch4: BLACK ⚫ (unused)
```

**After recording stops**:
```
Ch1: BLACK ⚫ (audio always off when not recording)
Ch2: GREEN 🟢 (Telemed checkbox still checked)
Ch3: GREEN 🟢 (OptiTrack checkbox still checked)
Ch4: BLACK ⚫ (unused)
```

---

## Testing

### Test 1: Telemed Checkbox Control

1. **Start application** (Telemed unchecked by default)
   - Expected: Ch2 lamp is BLACK ⚫

2. **Check "Record Telemed Ultrasound"**
   - Expected: Ch2 lamp turns GREEN 🟢 immediately
   - Expected: Log message "✅ Telemed EchoWave is connected..."

3. **Uncheck "Record Telemed Ultrasound"**
   - Expected: Ch2 lamp turns BLACK ⚫ immediately
   - Expected: Log message "Telemed ultrasound recording disabled."

4. **Check Telemed again**
   - Expected: Ch2 lamp turns GREEN 🟢 again

### Test 2: OptiTrack Checkbox Control

1. **Start application** (OptiTrack unchecked by default)
   - Expected: Ch3 lamp is BLACK ⚫

2. **Check "Record OptiTrack"** (Motive running)
   - Expected: Ch3 lamp turns GREEN 🟢 immediately
   - Expected: Log message "✅ Motive is running..."

3. **Uncheck "Record OptiTrack"**
   - Expected: Ch3 lamp turns BLACK ⚫ immediately
   - Expected: Log message "OptiTrack recording disabled."

### Test 3: Ready State During Recording

1. **Check Telemed checkbox** (Ch2 lamp GREEN 🟢)
2. **Start recording**
   - Expected: Ch2 lamp changes from GREEN to blinking RED 🔴

3. **Stop recording**
   - Expected: Ch2 lamp returns to GREEN 🟢 (not black)
   - Expected: Checkbox still checked

### Test 4: Both Checkboxes Enabled

1. **Check both Telemed and OptiTrack**
   - Expected: Ch2 lamp GREEN 🟢
   - Expected: Ch3 lamp GREEN 🟢

2. **Start recording with audio**
   - Expected: Ch1 blinks RED 🔴 (audio)
   - Expected: Ch2 pulses RED 🔴 (Telemed sync)
   - Expected: Ch3 pulses RED 🔴 (OptiTrack sync)

3. **Stop recording**
   - Expected: Ch1 BLACK ⚫
   - Expected: Ch2 GREEN 🟢 (returns to ready)
   - Expected: Ch3 GREEN 🟢 (returns to ready)

### Test 5: Uncheck After Recording

1. **Check Telemed** → Ch2 GREEN 🟢
2. **Record** → Ch2 RED 🔴 during recording
3. **Stop** → Ch2 GREEN 🟢
4. **Uncheck Telemed** → Ch2 BLACK ⚫
5. **Record again** (Telemed disabled)
   - Expected: Ch2 stays BLACK ⚫ (no Telemed recording)

### Test 6: Checkbox Blocked During Recording

1. **Check Telemed** → Ch2 GREEN 🟢
2. **Start recording** → Ch2 RED 🔴
3. **Try to uncheck Telemed checkbox**
   - Expected: Checkbox change BLOCKED (line 1945: `if app.isRecording, return;end`)
   - Expected: Ch2 still RED 🔴 (recording continues normally)

---

## Visual State Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                 LED Lamp State Machine                       │
└─────────────────────────────────────────────────────────────┘

                    Checkbox UNCHECKED
                           ↓
                    ┌──────────────┐
                    │   BLACK ⚫   │ (Off/Disabled)
                    └──────────────┘
                           ↑
                    Checkbox CHECKED
                           ↓
                    ┌──────────────┐
              ┌────▶│   GREEN 🟢   │ (Ready to record)
              │     └──────────────┘
              │            ↓
              │     Start Recording
              │            ↓
              │     ┌──────────────┐
              │     │   RED 🔴     │ (Active signal)
              │     │  (blinking)  │
              │     └──────────────┘
              │            ↓
              │      Stop Recording
              └────────────┘
                    (Returns to GREEN if checkbox still checked)
```

---

## Color Reference

### RGB Values:
```matlab
noSignalColor = [0, 0, 0];    % BLACK ⚫ - Off/Disabled
readyColor = [0, 1, 0];       % GREEN 🟢 - Ready (checkbox enabled)
hasSignalColor = [1, 0, 0];   % RED 🔴   - Active signal (recording)
```

### Visual Appearance:
- **BLACK ⚫**: Lamp completely off, no light visible
- **GREEN 🟢**: Solid green light, indicates feature is enabled and ready
- **RED 🔴**: Blinking/pulsing red light, indicates active signal detection

---

## Troubleshooting

### Issue: Lamp Doesn't Turn Green When Checkbox Checked

**Possible causes**:
1. `readyColor` property not added (Change 1)
2. LED control code not added to checkbox callback (Change 2/3)
3. App needs to be restarted after code changes

**Solution**: Verify all 4 changes are implemented, restart app

### Issue: Lamp Stays Black After Recording Stops

**Possible causes**:
1. Change 4 not implemented (lamp restore after recording)
2. Checkbox was unchecked during recording (blocked, but value might have changed)

**Solution**: Implement Change 4, verify checkbox is still checked

### Issue: Green Light Hard to See

**Alternative colors**:
```matlab
% Brighter green
readyColor = [0, 1, 0.5];  % Green with slight blue tint

% Yellow (ready/armed state)
readyColor = [1, 1, 0];    % Yellow (mixture of red + green)

% Blue (alternative)
readyColor = [0, 0.5, 1];  % Light blue
```

**Recommendation**: Stick with pure green `[0, 1, 0]` - standard "ready" color

### Issue: Lamp Flickers When Toggling Checkbox Rapidly

**Expected behavior**: Lamp color updates immediately with each checkbox change
**If problematic**: Not an issue, user shouldn't toggle rapidly during normal use

---

## Benefits

✅ **Visual feedback** - Users can immediately see if Telemed/OptiTrack is enabled
✅ **No guessing** - Green lamp = ready to record, black = disabled
✅ **Professional appearance** - Standard LED indicator pattern (off → ready → active)
✅ **Prevents mistakes** - Easy to verify settings before pressing Start
✅ **Three-state indication**:
   - BLACK: Feature disabled
   - GREEN: Feature enabled, waiting
   - RED: Feature active, recording signal
✅ **State persistence** - Lamps return to green after recording (checkboxes stay enabled)

---

## Summary

**Changes Made**: 4 modifications to MewRecorder.mlapp

1. ✅ Add `readyColor` property (1 line)
2. ✅ Update Telemed checkbox callback with Ch2 LED control (4 lines)
3. ✅ Update OptiTrack checkbox callback with Ch3 LED control (4 lines)
4. ✅ Restore ready state after recording stops (8 lines)

**Total**: ~17 lines of code

**Benefits**:
- Visual indication when Telemed/OptiTrack recording is enabled
- Green lamps show "ready" state before recording
- Red lamps show "active" signal during recording
- Lamps return to green after recording (if checkbox still enabled)
- Professional LED indicator behavior

**Estimated Implementation Time**: 10 minutes
**Risk Level**: Very low (simple color assignments, no logic changes)

---

**Document Version**: 1.0
**Last Updated**: 2025-12-12
**Related**: FIX_AUDIO_LAMPS.md (blinking behavior during recording)
**Testing**: Toggle checkboxes and verify lamp colors (green when checked, black when unchecked)

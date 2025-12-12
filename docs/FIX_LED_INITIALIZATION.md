# Fix LED Initialization and Visibility Issues

**Date**: December 12, 2025
**Issues Reported**:
1. When program launches, two LEDs are black (not reflecting checkbox state)
2. Checking US/OptiTrack checkbox doesn't change LED color
3. Fourth LED (Ch4) not shown at first, but turns red during recording
4. Overall lighting behavior is inconsistent

**Root Causes**:
1. LED colors not initialized at startup based on checkbox states
2. LED visibility controlled by `num_audio_channels` instead of functionality
3. Checkbox callbacks implemented, but not called at startup

---

## Problem Analysis

### Issue 1: No LED Initialization at Startup

**Current behavior** (lines 2430-2445):
```matlab
% LEDs created with black color, never initialized based on checkboxes
app.Lp_AudSig1.Color = [0 0 0];  % Always black at startup
app.Lp_AudSig2.Color = [0 0 0];  % Should be green if Telemed checked
app.Lp_AudSig3.Color = [0 0 0];  % Should be green if OptiTrack checked
app.Lp_AudSig4.Color = [0 0 0];  % Always black (unused)
```

**Missing**: Code to set Ch2/Ch3 to green if their checkboxes are enabled at startup.

---

### Issue 2: LED Visibility Based on Audio Channels (Wrong Logic)

**Current behavior** (lines 1069-1075 in `selectAudioDevice`):
```matlab
for i = 1:app.max_audio_sig_lamps
    if app.num_audio_channels >= i
        app.("Lp_AudSig" + num2str(i)).Visible = 'on';
    else
        app.("Lp_AudSig" + num2str(i)).Visible = 'off';
    end
end
```

**Problem**:
- When `num_audio_channels = 2` → Only Ch1 and Ch2 visible
- Ch3 (OptiTrack) is HIDDEN even if OptiTrack checkbox is checked
- Ch4 hidden until recording starts with ASIO (4 channels)

**Why this is wrong**:
- Ch3 should be visible if OptiTrack is ENABLED (checkbox), not based on audio channels
- During recording, ASIO uses 4 channels, so Ch3/Ch4 become visible
- User sees "Fourth LED appears during recording" (inconsistent)

---

### Issue 3: Checkbox Callbacks Work, But Not Called at Startup

**Current implementation**:
- ✅ `Ck_ifRecordTelemedValueChanged` (lines 1986, 1992) - Sets Ch2 LED green/black
- ✅ `Ck_ifRecordOptitrackValueChanged` (lines 2204, 2209) - Sets Ch3 LED green/black

**Problem**: These functions only fire when user CHANGES checkbox, not at app startup.

---

## Solution

### CHANGE 1: Add LED Initialization Function

**Location**: After `initialize` function (after line 138)

**ADD NEW FUNCTION**:
```matlab
function UpdateLEDIndicators(app)
    % Update LED lamps to reflect current checkbox states
    % Called at startup and after recording stops

    % Ch1 (Audio): Off when not recording
    app.Lp_AudSig1.Color = app.noSignalColor;

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

---

### CHANGE 2: Call UpdateLEDIndicators at Startup

**Location**: Function `initialize` (line 110-138)

**FIND** (end of initialize function, around line 130-137):
```matlab
    if success
        appSetStatus(app, 'ready');
        app.logMessage(msg, 'info');
    else
        appSetStatus(app, 'inactive');
        app.logMessage(msg, 'error');
        return;
    end

end %initialize
```

**REPLACE WITH** (add LED initialization):
```matlab
    if success
        appSetStatus(app, 'ready');
        app.logMessage(msg, 'info');

        % Initialize LED indicators based on checkbox states
        UpdateLEDIndicators(app);
    else
        appSetStatus(app, 'inactive');
        app.logMessage(msg, 'error');
        return;
    end

end %initialize
```

---

### CHANGE 3: Fix LED Visibility Logic

**Location**: Function `selectAudioDevice` (lines 1069-1075)

**FIND** (current visibility logic):
```matlab
for i = 1:app.max_audio_sig_lamps
    if app.num_audio_channels >= i
        app.("Lp_AudSig" + num2str(i)).Visible = 'on';
    else
        app.("Lp_AudSig" + num2str(i)).Visible = 'off';
    end
end
```

**REPLACE WITH** (functionality-based visibility):
```matlab
% LED visibility based on functionality, not just audio channel count
% Ch1: Always visible (audio channel)
app.Lp_AudSig1.Visible = 'on';

% Ch2: Visible if Telemed enabled OR if audio has 2+ channels
if app.Ck_ifRecordTelemed.Value || app.num_audio_channels >= 2
    app.Lp_AudSig2.Visible = 'on';
else
    app.Lp_AudSig2.Visible = 'off';
end

% Ch3: Visible if OptiTrack enabled OR if audio has 3+ channels
if app.Ck_ifRecordOptitrack.Value || app.num_audio_channels >= 3
    app.Lp_AudSig3.Visible = 'on';
else
    app.Lp_AudSig3.Visible = 'off';
end

% Ch4: Visible only if audio has 4 channels
if app.num_audio_channels >= 4
    app.Lp_AudSig4.Visible = 'on';
else
    app.Lp_AudSig4.Visible = 'off';
end
```

**Key change**: Ch2 and Ch3 are visible if their corresponding feature is ENABLED, not just based on audio channel count.

---

### CHANGE 4: Update Telemed Checkbox to Refresh LED Visibility

**Location**: Function `Ck_ifRecordTelemedValueChanged` (lines 1986, 1992)

**FIND** (current LED control):
```matlab
        % Turn on Ch2 LED (green) to show Telemed is ready
        app.Lp_AudSig2.Color = app.readyColor;
    else
        % When DISABLING, just log - no need to re-initialize
        app.logMessage('Telemed ultrasound recording disabled.', 'info');

        % Turn off Ch2 LED (black) to show Telemed is disabled
        app.Lp_AudSig2.Color = app.noSignalColor;
    end
```

**REPLACE WITH** (add visibility control):
```matlab
        % Turn on Ch2 LED (green) to show Telemed is ready
        app.Lp_AudSig2.Color = app.readyColor;
        app.Lp_AudSig2.Visible = 'on';  % Ensure visible when enabled
    else
        % When DISABLING, just log - no need to re-initialize
        app.logMessage('Telemed ultrasound recording disabled.', 'info');

        % Turn off Ch2 LED (black) to show Telemed is disabled
        app.Lp_AudSig2.Color = app.noSignalColor;
        % Keep visible if audio has 2+ channels, hide otherwise
        if app.num_audio_channels < 2
            app.Lp_AudSig2.Visible = 'off';
        end
    end
```

---

### CHANGE 5: Update OptiTrack Checkbox to Refresh LED Visibility

**Location**: Function `Ck_ifRecordOptitrackValueChanged` (lines 2204, 2209)

**FIND** (current LED control):
```matlab
            % Turn on Ch3 LED (green) to show OptiTrack is ready
            app.Lp_AudSig3.Color = app.readyColor;
        else
            app.logMessage('OptiTrack recording disabled.', 'info');

            % Turn off Ch3 LED (black) to show OptiTrack is disabled
            app.Lp_AudSig3.Color = app.noSignalColor;
        end
```

**REPLACE WITH** (add visibility control):
```matlab
            % Turn on Ch3 LED (green) to show OptiTrack is ready
            app.Lp_AudSig3.Color = app.readyColor;
            app.Lp_AudSig3.Visible = 'on';  % Ensure visible when enabled
        else
            app.logMessage('OptiTrack recording disabled.', 'info');

            % Turn off Ch3 LED (black) to show OptiTrack is disabled
            app.Lp_AudSig3.Color = app.noSignalColor;
            % Keep visible if audio has 3+ channels, hide otherwise
            if app.num_audio_channels < 3
                app.Lp_AudSig3.Visible = 'off';
            end
        end
```

---

### CHANGE 6: Call UpdateLEDIndicators After Recording Stops

**Location**: Function `Bn_StopPushed` (around line 1658-1674)

**FIND** (current code after recording stops):
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

**REPLACE WITH** (use centralized function):
```matlab
% Reset all audio signal lamps (AFTER audioTimer stopped)
% Use centralized function to restore LED states
UpdateLEDIndicators(app);
```

**Benefit**: Simpler, consistent LED state management.

---

## Expected Behavior After Fix

### At Startup (No Checkboxes Enabled):
```
Ch1: BLACK ⚫ (visible)
Ch2: BLACK ⚫ (visible if 2+ audio channels, hidden otherwise)
Ch3: HIDDEN (OptiTrack not enabled)
Ch4: HIDDEN (not used)
```

### At Startup (Telemed Checkbox Enabled):
```
Ch1: BLACK ⚫ (visible)
Ch2: GREEN 🟢 (visible - Telemed enabled)
Ch3: HIDDEN (OptiTrack not enabled)
Ch4: HIDDEN (not used)
```

### At Startup (Both Telemed and OptiTrack Enabled):
```
Ch1: BLACK ⚫ (visible)
Ch2: GREEN 🟢 (visible - Telemed enabled)
Ch3: GREEN 🟢 (visible - OptiTrack enabled)
Ch4: HIDDEN (not used)
```

### User Checks OptiTrack Checkbox:
```
Before: Ch3 HIDDEN
After:  Ch3 visible, GREEN 🟢 (ready)
```

### User Unchecks Telemed Checkbox:
```
Before: Ch2 GREEN 🟢 (visible)
After:  Ch2 BLACK ⚫ (visible if 2+ audio channels) or HIDDEN (if < 2 channels)
```

### During Recording (with Telemed + OptiTrack):
```
Ch1: Blinks RED 🔴 (audio signal)
Ch2: Pulses RED 🔴 (Telemed sync)
Ch3: Pulses RED 🔴 (OptiTrack sync)
Ch4: BLACK ⚫ or HIDDEN (depends on audio channels)
```

### After Recording Stops (checkboxes still enabled):
```
Ch1: BLACK ⚫ (visible)
Ch2: GREEN 🟢 (visible - back to ready state)
Ch3: GREEN 🟢 (visible - back to ready state)
Ch4: HIDDEN (not used)
```

---

## Testing

### Test 1: Fresh Startup (No Checkboxes)

1. **Start application**
   - Expected: Ch1 visible (black), Ch2 visible if 2+ channels (black), Ch3/Ch4 hidden

### Test 2: Fresh Startup (Telemed Checked)

1. **Start application with Telemed checkbox enabled**
   - Expected: Ch1 black (visible), Ch2 GREEN 🟢 (visible), Ch3 hidden, Ch4 hidden

### Test 3: Enable Telemed After Startup

1. **Start application** (Telemed unchecked)
   - Expected: Ch2 black or hidden (depends on audio channels)
2. **Check "Record Telemed Ultrasound"**
   - Expected: Ch2 turns GREEN 🟢 and becomes visible
3. **Uncheck "Record Telemed Ultrasound"**
   - Expected: Ch2 turns BLACK ⚫ (stays visible if 2+ audio channels)

### Test 4: Enable OptiTrack

1. **Start application** (OptiTrack unchecked)
   - Expected: Ch3 HIDDEN
2. **Check "Record OptiTrack"**
   - Expected: Ch3 becomes visible and turns GREEN 🟢
3. **Uncheck "Record OptiTrack"**
   - Expected: Ch3 turns BLACK ⚫ and becomes HIDDEN (if < 3 audio channels)

### Test 5: Recording with Both Features

1. **Check Telemed and OptiTrack**
   - Expected: Ch2 GREEN 🟢 (visible), Ch3 GREEN 🟢 (visible)
2. **Start recording** (speak into mic)
   - Expected: Ch1 RED 🔴, Ch2 RED 🔴, Ch3 RED 🔴
3. **Stop recording**
   - Expected: Ch1 BLACK ⚫, Ch2 GREEN 🟢, Ch3 GREEN 🟢
4. **Uncheck both checkboxes**
   - Expected: Ch2 BLACK/HIDDEN, Ch3 HIDDEN

### Test 6: LED Persistence After Recording

1. **Enable Telemed** → Ch2 GREEN 🟢
2. **Record** → Ch2 RED 🔴
3. **Stop** → Ch2 GREEN 🟢 (restored)
4. **Record again** → Ch2 RED 🔴
5. **Stop** → Ch2 GREEN 🟢 (restored again)

---

## Troubleshooting

### Issue: Ch2/Ch3 Still Black at Startup

**Check**:
1. Is `readyColor` property defined? (Line 104: `readyColor = [0, 1, 0]`)
2. Is `UpdateLEDIndicators` function added after `initialize`?
3. Is `UpdateLEDIndicators(app)` called at end of `initialize`?

### Issue: Ch3 Still Appears During Recording

**Check**:
1. Is CHANGE 3 (LED visibility logic) implemented?
2. Verify Ch3 visibility is controlled by OptiTrack checkbox, not just audio channels

### Issue: LEDs Don't Change When Toggling Checkboxes

**Check**:
1. Are CHANGE 4 and CHANGE 5 implemented (checkbox callbacks)?
2. Verify LED color AND visibility are being set

### Issue: Ch4 Still Appears During Recording

**Expected behavior**: Ch4 will appear during ASIO recording (4 channels), but should stay black
- This is correct - Ch4 shows audio channel 4 status
- If Ch4 turning RED during recording, this means audio channel 4 has signal (check hardware connections)

---

## Summary

**Changes Made**: 6 modifications to MewRecorder.mlapp

1. ✅ **Add UpdateLEDIndicators function** (~25 lines) - Centralized LED state management
2. ✅ **Call UpdateLEDIndicators at startup** (1 line in `initialize`)
3. ✅ **Fix LED visibility logic** (~20 lines) - Based on functionality, not just audio channels
4. ✅ **Update Telemed checkbox** (2 lines) - Control Ch2 visibility
5. ✅ **Update OptiTrack checkbox** (2 lines) - Control Ch3 visibility
6. ✅ **Use UpdateLEDIndicators after recording** (replace 14 lines with 1 line)

**Benefits**:
- ✅ LEDs show correct state at startup (green if checkbox enabled)
- ✅ Ch3 (OptiTrack) visible when OptiTrack enabled, not based on audio channels
- ✅ Toggling checkboxes immediately updates LED color AND visibility
- ✅ Consistent LED behavior across all scenarios
- ✅ Centralized LED management (easier maintenance)

**Estimated Implementation Time**: 20-30 minutes
**Risk Level**: Low (visual changes only, no logic changes to recording)

---

**Document Version**: 1.0
**Last Updated**: 2025-12-12
**Related**:
- FIX_CHECKBOX_LED_INDICATORS.md (original implementation)
- FIX_AUDIO_LAMPS.md (blinking behavior during recording)

**Testing**: Restart app and verify LED colors match checkbox states immediately at startup

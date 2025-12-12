# Fix LED Visibility - Hide Unchecked Features

**Date**: December 12, 2025
**Issue**: Ch2 (Telemed) shows as BLACK when unchecked - should be HIDDEN instead
**User Report**: "Initially ultrasound is not checked but it is black"
**Solution**: Simplify visibility logic - only show LEDs for enabled features

---

## Problem Analysis

**Current behavior** (with previous fix):
```
Telemed unchecked, num_audio_channels = 2:
Ch1: GREEN 🟢 (visible)
Ch2: BLACK ⚫ (visible) ← WRONG! Should be hidden
Ch3: HIDDEN
Ch4: HIDDEN
```

**Problem**: Ch2 is visible (showing black) even when Telemed is unchecked.

**Root cause**: Visibility logic in the previous fix was:
```matlab
% Ch2: Visible if Telemed enabled OR if audio has 2+ channels
if app.Ck_ifRecordTelemed.Value || app.num_audio_channels >= 2
    app.Lp_AudSig2.Visible = 'on';
else
    app.Lp_AudSig2.Visible = 'off';
end
```

This shows Ch2 even when Telemed is unchecked (because `num_audio_channels >= 2`).

**Expected behavior**:
```
Telemed unchecked:
Ch1: GREEN 🟢 (visible)
Ch2: HIDDEN ← Should not be visible at all
Ch3: HIDDEN
Ch4: HIDDEN
```

---

## Solution: Checkbox-Only Visibility

### Design Principle:
**Only show LEDs for features that are enabled (checkboxes checked).**

- Ch1: Always visible (audio always enabled)
- Ch2: Only visible if **Telemed checkbox checked**
- Ch3: Only visible if **OptiTrack checkbox checked**
- Ch4: Never visible (unused)

---

## Implementation

### CHANGE 1: Simplify LED Visibility in selectAudioDevice

**Location**: Function `selectAudioDevice` (lines 1069-1075)

**FIND** (previous complex visibility logic):
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

**REPLACE WITH** (checkbox-only visibility):
```matlab
% LED visibility: Only show LEDs for enabled features
% Ch1: Always visible (audio always enabled)
app.Lp_AudSig1.Visible = 'on';

% Ch2: Only visible if Telemed checkbox is checked
if app.Ck_ifRecordTelemed.Value
    app.Lp_AudSig2.Visible = 'on';
else
    app.Lp_AudSig2.Visible = 'off';
end

% Ch3: Only visible if OptiTrack checkbox is checked
if app.Ck_ifRecordOptitrack.Value
    app.Lp_AudSig3.Visible = 'on';
else
    app.Lp_AudSig3.Visible = 'off';
end

% Ch4: Never visible (no checkbox, unused)
app.Lp_AudSig4.Visible = 'off';
```

**Key change**: Removed `num_audio_channels` logic entirely. Visibility is now purely checkbox-based.

---

### CHANGE 2: Update Telemed Checkbox Visibility Control

**Location**: Function `Ck_ifRecordTelemedValueChanged` (lines 1986, 1992)

**FIND** (previous code with conditional visibility):
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

**REPLACE WITH** (always hide when unchecked):
```matlab
        % Turn on Ch2 LED (green) to show Telemed is ready
        app.Lp_AudSig2.Color = app.readyColor;
        app.Lp_AudSig2.Visible = 'on';  % Show when enabled
    else
        % When DISABLING, just log - no need to re-initialize
        app.logMessage('Telemed ultrasound recording disabled.', 'info');

        % Turn off Ch2 LED and hide it
        app.Lp_AudSig2.Color = app.noSignalColor;
        app.Lp_AudSig2.Visible = 'off';  // Always hide when disabled
    end
```

**Key change**: Removed conditional visibility check. Ch2 is **always hidden** when Telemed unchecked.

---

### CHANGE 3: Update OptiTrack Checkbox Visibility Control

**Location**: Function `Ck_ifRecordOptitrackValueChanged` (lines 2204, 2209)

**FIND** (previous code with conditional visibility):
```matlab
            % Turn on Ch3 LED (green) to show OptiTrack is ready
            app.Lp_AudSig3.Color = app.readyColor;
            app.Lp_AudSig3.Visible = 'on';  // Ensure visible when enabled
        else
            app.logMessage('OptiTrack recording disabled.', 'info');

            % Turn off Ch3 LED (black) to show OptiTrack is disabled
            app.Lp_AudSig3.Color = app.noSignalColor;
            // Keep visible if audio has 3+ channels, hide otherwise
            if app.num_audio_channels < 3
                app.Lp_AudSig3.Visible = 'off';
            end
        end
```

**REPLACE WITH** (always hide when unchecked):
```matlab
            % Turn on Ch3 LED (green) to show OptiTrack is ready
            app.Lp_AudSig3.Color = app.readyColor;
            app.Lp_AudSig3.Visible = 'on';  // Show when enabled
        else
            app.logMessage('OptiTrack recording disabled.', 'info');

            % Turn off Ch3 LED and hide it
            app.Lp_AudSig3.Color = app.noSignalColor;
            app.Lp_AudSig3.Visible = 'off';  // Always hide when disabled
        end
```

**Key change**: Removed conditional visibility check. Ch3 is **always hidden** when OptiTrack unchecked.

---

## Expected Behavior After Fix

### Scenario 1: Nothing Checked (Startup Default)
```
Checkboxes: Telemed ☐  OptiTrack ☐
Visible LEDs: Ch1 only

Ch1: GREEN 🟢 (visible - audio ready)
Ch2: HIDDEN (not shown - Telemed disabled)
Ch3: HIDDEN (not shown - OptiTrack disabled)
Ch4: HIDDEN (never used)
```

**User sees**: Only **one green LED** (Ch1)

---

### Scenario 2: Telemed Checked
```
Checkboxes: Telemed ☑  OptiTrack ☐
Visible LEDs: Ch1, Ch2

Ch1: GREEN 🟢 (visible)
Ch2: GREEN 🟢 (visible - Telemed enabled)
Ch3: HIDDEN (OptiTrack disabled)
Ch4: HIDDEN
```

**User sees**: **Two green LEDs** (Ch1, Ch2)

---

### Scenario 3: OptiTrack Checked
```
Checkboxes: Telemed ☐  OptiTrack ☑
Visible LEDs: Ch1, Ch3

Ch1: GREEN 🟢 (visible)
Ch2: HIDDEN (Telemed disabled)
Ch3: GREEN 🟢 (visible - OptiTrack enabled)
Ch4: HIDDEN
```

**User sees**: **Two green LEDs** (Ch1, Ch3)

---

### Scenario 4: Both Checked
```
Checkboxes: Telemed ☑  OptiTrack ☑
Visible LEDs: Ch1, Ch2, Ch3

Ch1: GREEN 🟢 (visible)
Ch2: GREEN 🟢 (visible - Telemed enabled)
Ch3: GREEN 🟢 (visible - OptiTrack enabled)
Ch4: HIDDEN
```

**User sees**: **Three green LEDs** (Ch1, Ch2, Ch3)

---

### Scenario 5: Recording with Both Features
```
During recording (speaking):
Ch1: RED 🔴 (visible - audio signal)
Ch2: RED 🔴 (visible - Telemed sync)
Ch3: RED 🔴 (visible - OptiTrack sync)
Ch4: HIDDEN
```

---

### Scenario 6: After Recording
```
After Stop (checkboxes still enabled):
Ch1: GREEN 🟢 (visible - back to ready)
Ch2: GREEN 🟢 (visible - back to ready)
Ch3: GREEN 🟢 (visible - back to ready)
Ch4: HIDDEN
```

---

## Testing

### Test 1: Default Startup (Nothing Checked)

1. **Start application** (all checkboxes unchecked)
   - Expected: Only Ch1 visible (green)
   - Expected: Ch2 HIDDEN (not black, not visible at all)
   - Expected: Ch3 HIDDEN
   - Expected: Ch4 HIDDEN

### Test 2: Enable Telemed

1. **Start with nothing checked** → Only Ch1 visible
2. **Check "Record Telemed Ultrasound"**
   - Expected: Ch2 appears and turns GREEN 🟢
3. **Uncheck "Record Telemed Ultrasound"**
   - Expected: Ch2 disappears (hidden again)

### Test 3: Enable OptiTrack

1. **Start with nothing checked** → Only Ch1 visible
2. **Check "Record OptiTrack"**
   - Expected: Ch3 appears and turns GREEN 🟢
3. **Uncheck "Record OptiTrack"**
   - Expected: Ch3 disappears (hidden again)

### Test 4: Enable Both Features

1. **Check Telemed** → Ch1 green, Ch2 appears green
2. **Check OptiTrack** → Ch3 appears green
   - Expected: Three green LEDs visible (Ch1, Ch2, Ch3)
3. **Uncheck Telemed** → Ch2 disappears
   - Expected: Two green LEDs visible (Ch1, Ch3)
4. **Uncheck OptiTrack** → Ch3 disappears
   - Expected: One green LED visible (Ch1)

### Test 5: Recording Visibility

1. **Enable both features** → Ch1, Ch2, Ch3 all green
2. **Start recording**
   - Expected: All three LEDs blink red with signals
   - Expected: No new LEDs appear
3. **Stop recording**
   - Expected: All three LEDs return to green
   - Expected: No LEDs disappear

### Test 6: Uncheck During Ready State

1. **Enable Telemed** → Ch2 appears green
2. **DO NOT start recording**
3. **Uncheck Telemed**
   - Expected: Ch2 immediately disappears
   - Expected: Ch1 still visible (green)

---

## Visual Comparison

### BEFORE Fix (Wrong):
```
Startup (nothing checked):
┌────────────────────┐
│ Ch1 🟢  Ch2 ⚫     │  ← Ch2 visible but black (confusing!)
└────────────────────┘
User thinks: "Why is Ch2 showing? Is something wrong?"
```

### AFTER Fix (Correct):
```
Startup (nothing checked):
┌────────────────────┐
│ Ch1 🟢             │  ← Only Ch1 visible (clear!)
└────────────────────┘
User thinks: "Audio is ready. I can enable other features if needed."
```

---

### With Telemed Enabled:
```
BEFORE:
┌────────────────────┐
│ Ch1 🟢  Ch2 🟢     │
└────────────────────┘

AFTER (same):
┌────────────────────┐
│ Ch1 🟢  Ch2 🟢     │  ← Both visible and green
└────────────────────┘
```

---

## Benefits

✅ **Clearer UI**: Only show what's actually enabled
✅ **Less confusion**: No mysterious black LEDs
✅ **Obvious status**: Green LED = feature enabled and ready
✅ **Hidden = disabled**: If you don't see it, it's not being recorded
✅ **Clean startup**: Only one LED when starting fresh
✅ **Progressive disclosure**: LEDs appear as you enable features

---

## Summary

**Changes Made**: 3 modifications to MewRecorder.mlapp

### CHANGE 1: Simplify selectAudioDevice Visibility (lines 1069-1090)
- Remove `num_audio_channels` checks
- Ch2 visible only if `Ck_ifRecordTelemed.Value`
- Ch3 visible only if `Ck_ifRecordOptitrack.Value`

### CHANGE 2: Telemed Checkbox Always Hides Ch2 When Disabled (line ~1992)
```matlab
app.Lp_AudSig2.Visible = 'off';  // Was conditional, now always hide
```

### CHANGE 3: OptiTrack Checkbox Always Hides Ch3 When Disabled (line ~2209)
```matlab
app.Lp_AudSig3.Visible = 'off';  // Was conditional, now always hide
```

**Result**:
- ✅ Ch2 only visible when Telemed checkbox checked
- ✅ Ch3 only visible when OptiTrack checkbox checked
- ✅ No confusing black LEDs at startup
- ✅ Simple rule: If you see it, it's enabled

**Estimated Implementation Time**: 10 minutes
**Risk Level**: Very low (visibility only, no recording logic changed)

---

**Document Version**: 1.0
**Last Updated**: 2025-12-12
**Supersedes**: FIX_LED_INITIALIZATION.md (visibility section)
**Related**:
- FIX_LED_AUDIO_AND_CH4.md (Ch1 green, Ch4 disabled)
- FIX_CHECKBOX_LED_INDICATORS.md (LED color control)

**Testing**: Start app with nothing checked → should see only Ch1 (green)

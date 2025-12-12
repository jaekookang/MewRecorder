# Fix Audio LED Green State and Disable Ch4 Blinking

**Date**: December 12, 2025
**Issues Reported**:
1. **Ch1 (Audio) never shows green** - Audio is always used, but LED never shows "ready" state
2. **Ch4 blinks red during recording** - Should not light up (nothing connected to Input 4)

---

## Problem Analysis

### Issue 1: Audio LED Never Shows Green

**Current behavior**:
- At startup: Ch1 is BLACK ⚫
- When ready: Ch1 is BLACK ⚫
- During recording (speaking): Ch1 is RED 🔴
- During recording (silent): Ch1 is BLACK ⚫
- After recording: Ch1 is BLACK ⚫

**Problem**: Audio is **always used** for recording, but Ch1 never shows "ready" state (green).

**Expected behavior**:
- At startup/ready: Ch1 should be GREEN 🟢 (ready to record audio)
- During recording: Ch1 should blink RED 🔴 when signal detected, BLACK ⚫ when silent
- After recording: Ch1 should return to GREEN 🟢 (ready for next recording)

**Rationale**:
- Audio recording is mandatory (always enabled)
- Users should see Ch1 green to confirm audio system is ready
- Consistent with Ch2 (Telemed) and Ch3 (OptiTrack) showing green when enabled

---

### Issue 2: Ch4 Blinks Red During Recording

**Current behavior** (lines 364-366):
```matlab
if size(s, 2) > 3 && s(4) ~= 0
    app.Lp_AudSig4.Color = app.hasSignalColor;  % Turns RED if Ch4 has signal
end
```

**Hardware setup**:
- Input 1: Microphone → Ch1 (Audio)
- Input 2: Telemed sync → Ch2 (Telemed)
- Input 3: OptiTrack sync → Ch3 (OptiTrack)
- Input 4: **Nothing connected** → Ch4 (Unused)

**Problem**: During ASIO recording (4 channels), Ch4 picks up noise/signal even though nothing is connected.

**Possible causes**:
- Electrical noise on unused input
- Floating voltage when no input connected
- Cross-talk from other channels
- Buffer initialization with non-zero values

**Solution**: Disable Ch4 lamp updates entirely - it should never light up.

---

## Implementation

### CHANGE 1: Set Ch1 Green When Ready (in UpdateLEDIndicators)

**Location**: Function `UpdateLEDIndicators` (newly added function after line 138)

**FIND** (current UpdateLEDIndicators function):
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

**REPLACE WITH** (set Ch1 to green when ready):
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

**Key change**: Changed `app.Lp_AudSig1.Color = app.noSignalColor;` to `app.Lp_AudSig1.Color = app.readyColor;`

---

### CHANGE 2: Disable Ch4 Lamp Updates During Recording

**Location**: Function `UpdateRecordingDisplay` (lines 354-366)

**FIND** (current lamp update logic):
```matlab
% Turn on lamps with signal
if s(1) ~= 0
    app.Lp_AudSig1.Color = app.hasSignalColor;
end
if size(s, 2) > 1 && s(2) ~= 0
    app.Lp_AudSig2.Color = app.hasSignalColor;
end
if size(s, 2) > 2 && s(3) ~= 0
    app.Lp_AudSig3.Color = app.hasSignalColor;
end
if size(s, 2) > 3 && s(4) ~= 0
    app.Lp_AudSig4.Color = app.hasSignalColor;
end
```

**REPLACE WITH** (remove Ch4 update, keep it always black):
```matlab
% Turn on lamps with signal
if s(1) ~= 0
    app.Lp_AudSig1.Color = app.hasSignalColor;
end
if size(s, 2) > 1 && s(2) ~= 0
    app.Lp_AudSig2.Color = app.hasSignalColor;
end
if size(s, 2) > 2 && s(3) ~= 0
    app.Lp_AudSig3.Color = app.hasSignalColor;
end

% Ch4 is unused - do NOT update it (keep black)
% Note: Even though ASIO records 4 channels, Input 4 has nothing connected
% Removed: if size(s, 2) > 3 && s(4) ~= 0 ...
```

**Key change**: Removed the Ch4 lamp update logic entirely. Ch4 will stay black during recording (set on line 352).

---

### Alternative: Only Update Ch4 If Actually Used (Future-Proof)

If you ever connect something to Input 4 in the future, you could add a checkbox like Telemed/OptiTrack:

```matlab
% Ch4: Only update if there's a checkbox for it (future feature)
if size(s, 2) > 3 && app.Ck_ifRecordCh4.Value && s(4) ~= 0
    app.Lp_AudSig4.Color = app.hasSignalColor;
end
```

**But for now**: Just disable Ch4 entirely (use CHANGE 2 above).

---

## Expected Behavior After Fix

### At Startup (No Recording):
```
Ch1: GREEN 🟢 (audio ready)
Ch2: GREEN 🟢 (if Telemed checked) or BLACK ⚫ (if unchecked)
Ch3: GREEN 🟢 (if OptiTrack checked) or BLACK ⚫ (if unchecked)
Ch4: BLACK ⚫ (unused, hidden if num_audio_channels < 4)
```

### During Recording (Speaking):
```
Ch1: RED 🔴 (audio signal detected)
Ch2: RED 🔴 (Telemed sync pulses, if enabled)
Ch3: RED 🔴 (OptiTrack sync pulses, if enabled)
Ch4: BLACK ⚫ (stays black, no longer blinks)
```

### During Recording (Silent):
```
Ch1: BLACK ⚫ (no audio signal)
Ch2: RED 🔴 (Telemed sync continues, if enabled)
Ch3: RED 🔴 (OptiTrack sync continues, if enabled)
Ch4: BLACK ⚫ (stays black)
```

### After Recording Stops:
```
Ch1: GREEN 🟢 (back to ready state)
Ch2: GREEN 🟢 (if Telemed checked) or BLACK ⚫ (if unchecked)
Ch3: GREEN 🟢 (if OptiTrack checked) or BLACK ⚫ (if unchecked)
Ch4: BLACK ⚫ (stays black)
```

---

## Testing

### Test 1: Ch1 Shows Green at Startup

1. **Start application**
   - Expected: Ch1 is GREEN 🟢
   - Expected: Shows audio is ready to record

2. **Check system is ready**
   - Expected: Status shows "ready"
   - Expected: Ch1 stays GREEN 🟢

### Test 2: Ch1 Blinks During Recording

1. **Start recording**
2. **Speak into microphone**
   - Expected: Ch1 turns RED 🔴 when speaking
3. **Stay silent**
   - Expected: Ch1 turns BLACK ⚫ when silent
4. **Speak again**
   - Expected: Ch1 turns RED 🔴 again

### Test 3: Ch1 Returns to Green After Recording

1. **Start recording** (Ch1 blinks RED/BLACK)
2. **Stop recording**
   - Expected: Ch1 returns to GREEN 🟢
3. **Start recording again**
   - Expected: Ch1 blinks RED/BLACK again
4. **Stop recording**
   - Expected: Ch1 returns to GREEN 🟢

### Test 4: Ch4 Never Lights Up During Recording

1. **Start recording with ASIO (4 channels)**
2. **Speak into microphone**
   - Expected: Ch1 blinks RED 🔴
   - Expected: Ch2 pulses RED 🔴 (if Telemed enabled)
   - Expected: Ch3 pulses RED 🔴 (if OptiTrack enabled)
   - Expected: **Ch4 stays BLACK ⚫** (no longer blinks)

3. **Check Ch4 throughout recording**
   - Expected: Ch4 **never turns red**, regardless of audio input

### Test 5: All Three Features Enabled

1. **Enable Telemed and OptiTrack**
   - Expected: Ch1 GREEN 🟢, Ch2 GREEN 🟢, Ch3 GREEN 🟢

2. **Start recording, speak into mic**
   - Expected: Ch1 RED 🔴 (audio), Ch2 RED 🔴 (Telemed), Ch3 RED 🔴 (OptiTrack)
   - Expected: Ch4 BLACK ⚫ (never lights up)

3. **Stop recording**
   - Expected: Ch1 GREEN 🟢, Ch2 GREEN 🟢, Ch3 GREEN 🟢
   - Expected: Ch4 BLACK ⚫

---

## LED State Summary Table

| State | Ch1 (Audio) | Ch2 (Telemed) | Ch3 (OptiTrack) | Ch4 (Unused) |
|-------|-------------|---------------|-----------------|--------------|
| **Startup/Ready** | GREEN 🟢 | GREEN 🟢 if checked<br>BLACK ⚫ if unchecked | GREEN 🟢 if checked<br>BLACK ⚫ if unchecked | BLACK ⚫ |
| **Recording (signal)** | RED 🔴 | RED 🔴 if enabled | RED 🔴 if enabled | BLACK ⚫ |
| **Recording (no signal)** | BLACK ⚫ | RED 🔴 if enabled | RED 🔴 if enabled | BLACK ⚫ |
| **After recording** | GREEN 🟢 | GREEN 🟢 if checked<br>BLACK ⚫ if unchecked | GREEN 🟢 if checked<br>BLACK ⚫ if unchecked | BLACK ⚫ |

---

## Why Ch4 Was Blinking

**Technical explanation**:

During ASIO recording, all 4 hardware inputs are captured:
```matlab
% Line 345: Get last sample from all channels
s = S(end,:);  % s is [Ch1, Ch2, Ch3, Ch4]

% Line 364-366: Check if Ch4 has signal
if size(s, 2) > 3 && s(4) ~= 0
    app.Lp_AudSig4.Color = app.hasSignalColor;  // Turns red if Ch4 non-zero
end
```

**Why Ch4 has non-zero values**:
1. **Floating input**: When nothing is connected to Input 4, the input is "floating"
2. **Electrical noise**: Picks up ambient electrical noise (50/60 Hz hum, EMI)
3. **Input impedance**: High-impedance input captures stray signals
4. **ADC noise**: Analog-to-Digital Converter adds quantization noise

**Result**: Even with nothing connected, Ch4 data is rarely exactly 0.0000, so `s(4) ~= 0` is often true.

**Solution**: Don't check Ch4 at all - just keep it black always.

---

## Troubleshooting

### Issue: Ch1 Still Black at Startup

**Check**:
1. Is CHANGE 1 implemented (UpdateLEDIndicators sets Ch1 to green)?
2. Is `UpdateLEDIndicators(app)` called at end of `initialize` function?
3. Is `readyColor` property defined? (Should be `[0, 1, 0]`)

**Debug**:
Add this line in `initialize` function before calling `UpdateLEDIndicators`:
```matlab
fprintf('Setting LED indicators - Ch1 should be green\n');
```

### Issue: Ch4 Still Blinks During Recording

**Check**:
1. Is CHANGE 2 implemented (removed Ch4 lamp update)?
2. Verify lines 364-366 are removed or commented out

**Debug**:
Add this line in `UpdateRecordingDisplay` after line 352:
```matlab
fprintf('Ch4 should stay black (not updated)\n');
```

### Issue: Ch1 Doesn't Turn Red When Speaking

**Check**:
1. Is microphone connected and working?
2. Check Windows sound settings - verify mic input
3. Verify line 355-357 still exists (Ch1 lamp update when s(1) ~= 0)

**Debug**:
Add this after line 356:
```matlab
fprintf('Ch1 signal detected: %.4f\n', s(1));
```

---

## Summary

**Changes Made**: 2 modifications to MewRecorder.mlapp

### CHANGE 1: Ch1 Green When Ready (1 line)
```matlab
% In UpdateLEDIndicators function
app.Lp_AudSig1.Color = app.readyColor;  % Was: app.noSignalColor
```

### CHANGE 2: Disable Ch4 Updates (remove 3 lines)
```matlab
% In UpdateRecordingDisplay function
% Remove lines 364-366:
% if size(s, 2) > 3 && s(4) ~= 0
%     app.Lp_AudSig4.Color = app.hasSignalColor;
% end
```

**Benefits**:
- ✅ Ch1 shows GREEN 🟢 when ready to record (audio always enabled)
- ✅ Ch4 never blinks red (unused input ignored)
- ✅ Consistent LED behavior: GREEN = ready, RED = active signal
- ✅ Users can visually confirm audio system is ready before recording
- ✅ No confusion from Ch4 lighting up unexpectedly

**Estimated Implementation Time**: 5 minutes
**Risk Level**: Very low (cosmetic change, no recording logic affected)

---

**Document Version**: 1.0
**Last Updated**: 2025-12-12
**Related**:
- FIX_LED_INITIALIZATION.md (LED startup and visibility)
- FIX_CHECKBOX_LED_INDICATORS.md (checkbox LED control)
- FIX_AUDIO_LAMPS.md (blinking behavior during recording)

**Testing**:
1. Verify Ch1 is GREEN at startup
2. Verify Ch1 blinks RED during recording when speaking
3. Verify Ch4 never lights up during recording

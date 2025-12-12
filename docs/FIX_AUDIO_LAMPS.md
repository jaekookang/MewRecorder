# Fix Audio Signal Lamp Inconsistency

**Date**: December 10, 2025
**Issue**: Audio signal lamps (LED indicators) don't light correctly - stay lit inconsistently
**Root Cause**: Lamps turn red when signal detected but never turn back to black during recording
**Solution**: Add reset logic to turn lamps off when no signal detected

---

## Problem Analysis

### Current Behavior:
- ❌ Lamps turn RED when audio signal detected
- ❌ Once red, they **stay red** for entire recording
- ❌ Never turn back to black (off) during recording
- ❌ Only reset when recording stops (lines 1642-1646)
- ❌ Result: Inconsistent indication - doesn't reflect actual real-time signal

### Root Cause:
**Missing reset logic** in `UpdateRecordingDisplay` function (lines 319-331):

```matlab
// Current broken logic (lines 319-331):
% Update audio signal lamps
if s(1) ~= 0
    app.Lp_AudSig1.Color = app.hasSignalColor;  // Turn ON
    // BUG: Never turns OFF!
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

### Expected Behavior:
- ✅ Lamps blink/pulse with actual audio signal
- ✅ RED when signal present in current sample
- ✅ BLACK when no signal in current sample
- ✅ Real-time indication of audio levels

---

## Solution

**Add `else` clauses** to turn lamps OFF when no signal detected.

---

## Implementation

### CHANGE: Fix UpdateRecordingDisplay Function

**Location**: Function `UpdateRecordingDisplay` (lines 319-331)

**FIND** (current broken code):
```matlab
% Update audio signal lamps
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

**REPLACE WITH** (add else clauses for proper blinking):
```matlab
% Update audio signal lamps (real-time blinking)
if s(1) ~= 0
    app.Lp_AudSig1.Color = app.hasSignalColor;
else
    app.Lp_AudSig1.Color = app.noSignalColor;
end

if size(s, 2) > 1
    if s(2) ~= 0
        app.Lp_AudSig2.Color = app.hasSignalColor;
    else
        app.Lp_AudSig2.Color = app.noSignalColor;
    end
end

if size(s, 2) > 2
    if s(3) ~= 0
        app.Lp_AudSig3.Color = app.hasSignalColor;
    else
        app.Lp_AudSig3.Color = app.noSignalColor;
    end
end

if size(s, 2) > 3
    if s(4) ~= 0
        app.Lp_AudSig4.Color = app.hasSignalColor;
    else
        app.Lp_AudSig4.Color = app.noSignalColor;
    end
end
```

**Key change**: Added `else` clauses to reset lamps to black when no signal (s == 0).

---

## Alternative Approach (More Efficient)

If you prefer cleaner code, reset ALL lamps first, then only turn on the ones with signal:

```matlab
% Update audio signal lamps (real-time blinking)
% Reset all lamps to black first
app.Lp_AudSig1.Color = app.noSignalColor;
app.Lp_AudSig2.Color = app.noSignalColor;
app.Lp_AudSig3.Color = app.noSignalColor;
app.Lp_AudSig4.Color = app.noSignalColor;

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

**Benefit**: Shorter, cleaner code. Slightly less efficient but difference is negligible.

---

## Verification

### Before Fix:
1. Start recording with audio/ultrasound/OptiTrack
2. Speak into microphone
3. **Problem**: Ch1 lamp turns red and **stays red** entire recording
4. Ch2 (Telemed sync) turns red and **stays red**
5. Ch3 (OptiTrack sync) turns red and **stays red**
6. Ch4 stays black (unused)
7. No blinking - just permanently lit

### After Fix:
1. Start recording with audio/ultrasound/OptiTrack
2. Speak into microphone
3. **Expected**: Ch1 lamp **blinks red** when speaking, **black** when silent
4. Ch2 (Telemed sync) **pulses red** at ultrasound frame rate
5. Ch3 (OptiTrack sync) **pulses red** with OptiTrack sync signal
6. Ch4 stays black (unused)
7. Real-time visual feedback of signal levels

---

## Testing Procedures

### Test 1: Audio Only (Ch1)
1. Uncheck "Record Telemed Ultrasound"
2. Uncheck "Record OptiTrack"
3. Start recording
4. Speak into microphone → **Ch1 should blink red**
5. Stay silent → **Ch1 should turn black**
6. Speak again → **Ch1 should blink red again**
7. **Success**: Lamp responds to audio in real-time

### Test 2: Telemed Sync (Ch2)
1. Check "Record Telemed Ultrasound"
2. Start recording
3. **Ch2 should pulse red** at ultrasound frame rate (~14 times per second due to timer period)
4. May appear as steady dim red due to fast pulsing
5. Should see it flicker if you look closely

### Test 3: OptiTrack Sync (Ch3)
1. Check "Record OptiTrack"
2. Start recording
3. **Ch3 should pulse red** with OptiTrack sync signals
4. Behavior depends on OptiTrack sync signal pattern

### Test 4: All Channels Together
1. Enable all: Audio, Telemed, OptiTrack
2. Start recording and speak
3. **Ch1**: Blinks with speech
4. **Ch2**: Pulses with Telemed sync
5. **Ch3**: Pulses with OptiTrack sync
6. **Ch4**: Stays black (unused)
7. All lamps should respond independently

---

## Technical Details

### Update Frequency:
- **Timer period**: `app.timerPeriod = 0.070` seconds = ~14 Hz (14 times per second)
- Fast enough for visual feedback but not as smooth as real-time ASIO callback
- Lamps update every 70 milliseconds

### Signal Detection Logic:
```matlab
s = S(end,:);  // Get last row (most recent sample) from audio buffer

if s(1) ~= 0  // Check if channel 1 has non-zero value
    // Signal present
else
    // No signal
end
```

### Lamp Colors:
- **hasSignalColor = [1, 0, 0]** → RED (RGB: 100% red, 0% green, 0% blue)
- **noSignalColor = [0, 0, 0]** → BLACK (off)

### Audio Data Sources:
- **ASIO mode** (`app.useAudioDeviceReader = true`): Uses `app.audioData` buffer
- **audiorecorder mode**: Uses `getaudiodata(app.audioRecObj)`

---

## Why This Matters

### Current Problem (Before Fix):
```
Recording Timeline:
0s:  Lamps all black
1s:  Audio signal → Ch1 turns RED
2s:  Silent → Ch1 STILL RED (stuck!)
3s:  Audio signal → Ch1 STILL RED
... stays red for entire recording
```

### After Fix:
```
Recording Timeline:
0s:  Lamps all black
1s:  Audio signal → Ch1 turns RED
2s:  Silent → Ch1 turns BLACK ✓
3s:  Audio signal → Ch1 turns RED ✓
4s:  Silent → Ch1 turns BLACK ✓
... proper real-time indication
```

### Benefits:
- ✅ Lamps accurately reflect real-time signal presence
- ✅ Blinking indicates active audio (Ch1)
- ✅ Pulsing indicates sync signals (Ch2, Ch3)
- ✅ Visual confirmation that each channel is working
- ✅ Can diagnose recording issues during capture
- ✅ Consistent behavior across all recording modes

---

## Additional Note: Commented Out Reset Code

**Lines 1560-1563** have commented out lamp resets:
```matlab
% app.Lp_AudSig1.Color = app.noSignalColor;
% app.Lp_AudSig2.Color = app.noSignalColor;
% app.Lp_AudSig3.Color = app.noSignalColor;
% app.Lp_AudSig4.Color = app.noSignalColor;
```

These are **intentionally commented out** because lamps are reset later at line 1642-1646:
```matlab
% Reset all audio signal lamps (AFTER audioTimer stopped)
app.Lp_AudSig1.Color = app.noSignalColor;
app.Lp_AudSig2.Color = app.noSignalColor;
app.Lp_AudSig3.Color = app.noSignalColor;
app.Lp_AudSig4.Color = app.noSignalColor;
```

**Keep this as-is** - the final reset at line 1642-1646 ensures lamps turn off when recording stops.

---

## Troubleshooting

### Issue: Lamps never turn on
- Check if audio device is actually recording
- Verify `s = S(end,:)` has non-zero values
- Check `hasSignalColor` is set to [1, 0, 0] (red) in properties (line 103)
- Verify audio is reaching the device (Windows sound settings)

### Issue: Lamps flicker too fast (hard to see)
- This is expected for Ch2/Ch3 sync signals
- Timer updates every 70ms, so high-frequency signals appear as steady dim glow
- Ch1 (audio) should have visible blinking when speaking

### Issue: Ch2 doesn't blink during Telemed recording
- Check if Telemed ultrasound is actually recording
- Verify sync cable connected to Focusrite Input 2
- Check WAV file after recording - Ch2 should have pulse waveform

### Issue: Ch3 doesn't light with OptiTrack
- Check if OptiTrack is enabled and recording
- Verify sync cable connected to Focusrite Input 3
- OptiTrack may send pulses only at start/stop (not continuous)

### Issue: All lamps stay black
- Check if `UpdateRecordingDisplay` timer is running
- Verify `app.isRecording` is true
- Check if `S = app.audioData` or `getaudiodata()` returns data
- Look for errors in console/log

---

## Summary

**Changes Made**: 1 modification to MewRecorder.mlapp
- ✅ Add `else` clauses to lamp control in `UpdateRecordingDisplay` function (lines 319-331)

**Alternative**: Reset all lamps first, then turn on only those with signal (cleaner code)

**Benefits**:
- ✅ Lamps accurately show real-time audio signal levels
- ✅ Proper blinking behavior for all channels
- ✅ Visual confirmation that recording is working
- ✅ Easy to diagnose signal issues during recording
- ✅ Consistent lamp behavior across all recording modes

**Estimated Implementation Time**: 3-5 minutes
**Risk Level**: Very low (cosmetic fix, doesn't affect actual recording)

---

## Context

**UpdateRecordingDisplay Function** (lines 289-360):
- Called by `recordingTimer` every 70ms (line 1541)
- Updates elapsed time display
- Checks audio signal levels
- Updates lamp colors
- Checks timeout and duration limits
- Monitors memory usage

**This is the ONLY place** where lamps are updated during recording (no separate ASIO callback).

---

**Document Version**: 2.0
**Last Updated**: 2025-12-10
**Changes**:
- v1.0: Incorrect - referenced non-existent ASIO callback
- v2.0: Corrected to reference actual `UpdateRecordingDisplay` function
**Related**: session_logs/session_251020.md (ASIO implementation)

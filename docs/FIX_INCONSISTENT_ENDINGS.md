# Fix Inconsistent MP4 Endings - Video/Audio Duration Mismatch

**Date**: December 12, 2025
**Issue**: MP4 files have inconsistent endings - sometimes silent video, sometimes frozen frame, sometimes chopped while sync pulses still active
**Root Cause**: Audio is trimmed to sync pulses, but video is NOT trimmed, and FFmpeg uses longest duration by default
**Solution**: Use FFmpeg `-shortest` flag to stop at whichever stream ends first

---

## Problem Analysis

### Current Behavior (Inconsistent Endings):

#### Scenario 1: Video Longer than Audio
- ❌ **Last 1-2 seconds**: Video plays but NO audio (silent)
- ❌ **Reason**: Audio ended (last sync pulse + 1 frame), but video continues
- ❌ **User sees**: Ultrasound still moving, but no corresponding audio

#### Scenario 2: Audio Longer than Video
- ❌ **Last 1-2 seconds**: Audio plays but video FROZEN on last frame
- ❌ **Reason**: Video ended, but audio continues to end of trimmed file
- ❌ **User sees**: Frozen ultrasound frame while audio continues

#### Scenario 3: Recording Stopped During Sync Pulses
- ❌ **Audio chopped**: Recording stopped but sync pulses were still being sent
- ❌ **Duration mismatch**: Video has full recording, audio trimmed to last detected pulse
- ❌ **Result**: Missing end portion of data

---

## Root Cause Analysis

### Audio Trimming Logic (TrimTelemedAudio - Lines 1214-1248)

```matlab
% Line 1225-1231: Audio trimming based on sync pulses
frameStart = mean(locs(1:2));           % Start: midpoint of first 2 pulses
frameDur = median(diff(locs(2:end)));   % Median frame duration
frameEnd = locs(end) + frameDur;        % End: LAST PULSE + 1 frame duration
frameStartN = floor(frameStart * sr)+1;
frameEndN = floor(frameEnd * sr)+1;
if frameEndN > nSamplesAudio, frameEndN = nSamplesAudio; end
sig = audio(frameStartN:frameEndN);     % Trim audio to exact pulse range
```

**Audio duration** = Time from first pulse to (last pulse + 1 frame)

### Video Conversion (ConvertTVDtoVideo)

```matlab
% Line 2071: Full TVD converted to AVI/MP4
ConvertTVDtoVideo(app, tmpPath, toFormat);
```

**Video duration** = Full TVD file (from start to stop button press)

### FFmpeg Combination (Line 2095-2096)

```matlab
[status,cmdout] = app.ffmpegCombineVideoAudio(tmpVideoFN, trimmedAudioFN, outVideoFN, ...
    videoOffset=frameStart, fps=target_fps);
```

**Problem**: `ifUseShortest` parameter NOT passed (defaults to `false`)

**FFmpeg default behavior** when `ifUseShortest=false`:
```bash
# Output duration = MAX(video_duration, audio_duration)
# If video is 10s and audio is 8s → output is 10s (2s silent video at end)
# If video is 8s and audio is 10s → output is 10s (2s frozen frame at end)
```

---

## Why Durations Don't Match

### Ultrasound Recording Timeline:

```
Time:  0s ──────── 1s ─────────── 9s ──────── 10s ──────── 11s
Audio: [silence]   [Recording.....................]  [silence]
                   ↑                                ↑
                   First pulse                      Last pulse

Video: [black]     [Recording.................................] [possibly continues]
       ↑                                                        ↑
       User pressed Start                                       User pressed Stop
```

**Audio trimming**: Cuts from first pulse (1s) to last pulse + 1 frame (~9.03s)
- **Audio duration**: ~8 seconds

**Video conversion**: Includes everything from Start to Stop
- **Video duration**: ~10+ seconds (includes warmup and any extra frames)

**Result**: Video is usually **1-2 seconds longer** than trimmed audio

---

## Solution: Use FFmpeg `-shortest` Flag

### What `-shortest` Does:

**FFmpeg with `-shortest` flag**:
- Stops encoding when the **SHORTEST** stream ends
- If audio ends at 8s and video at 10s → output stops at 8s
- No silent video, no frozen frames
- Clean ending at exactly the last sync pulse

---

## Implementation

### CHANGE 1: Add ifUseShortest Parameter to Conversion Workflow

**Location**: Function `Mn_ConvertTVDtoVideoMenuSelected` (line 2095-2096)

**FIND** (current code):
```matlab
if app.ffmpegFound
    % Force constant 100 fps output (sync offset still applied)
    [status,cmdout] = app.ffmpegCombineVideoAudio(tmpVideoFN, trimmedAudioFN, outVideoFN, ...
        videoOffset=frameStart, fps=target_fps);
```

**REPLACE WITH** (add ifUseShortest=true):
```matlab
if app.ffmpegFound
    % Force constant fps output, stop at end of trimmed audio (shortest stream)
    [status,cmdout] = app.ffmpegCombineVideoAudio(tmpVideoFN, trimmedAudioFN, outVideoFN, ...
        videoOffset=frameStart, fps=target_fps, ifUseShortest=true);
```

**Key change**: Added `ifUseShortest=true` parameter

---

## How This Fixes Each Scenario

### Scenario 1: Video Longer than Audio (Most Common)

**Before** (without `-shortest`):
```
Audio:  [====== 8 seconds ======]
Video:  [=========== 10 seconds ===========]
Output: [====== 8s audio ======][2s SILENT VIDEO]
        ✅ Synced audio/video   ❌ Silent ending
```

**After** (with `-shortest`):
```
Audio:  [====== 8 seconds ======]
Video:  [=========== 10 seconds ===========]
Output: [====== 8 seconds ======]
        ✅ Synced audio/video   ✅ Clean ending (stops when audio ends)
```

### Scenario 2: Audio Longer than Video (Rare)

**Before** (without `-shortest`):
```
Audio:  [========= 10 seconds =========]
Video:  [====== 8 seconds ======]
Output: [====== 8s synced ======][2s FROZEN FRAME]
        ✅ Synced part          ❌ Frozen ending
```

**After** (with `-shortest`):
```
Audio:  [========= 10 seconds =========]
Video:  [====== 8 seconds ======]
Output: [====== 8 seconds ======]
        ✅ Synced audio/video   ✅ Clean ending (stops when video ends)
```

### Scenario 3: Recording Stopped During Sync Pulses

**Before** (without `-shortest`):
```
Sync pulses detected: [pulse][pulse][pulse][pulse] ... [pulse]
                       1s     2s     3s     4s          8s
User pressed Stop at: ─────────────────────────────────────── 10s
Audio trimmed to: 8s (last pulse detected)
Video duration: 10s (full recording)
Output: [====== 8s synced ======][2s SILENT VIDEO]
        ❌ Missing last 2s of data
```

**After** (with `-shortest`):
```
Sync pulses detected: [pulse][pulse][pulse][pulse] ... [pulse]
                       1s     2s     3s     4s          8s
User pressed Stop at: ─────────────────────────────────────── 10s
Audio trimmed to: 8s (last pulse detected)
Video duration: 10s (full recording)
Output: [====== 8 seconds ======]
        ✅ Clean ending at last detected sync pulse
        Note: Last 2s not included (no sync pulses detected)
```

**Important**: This is correct behavior - if sync pulses weren't detected in the last 2 seconds, that portion shouldn't be included in synchronized output.

---

## Additional Issue: Missing End Sync Pulses

If recordings are being "chopped" while sync pulses are still going, there may be a **sync pulse detection issue**.

### Possible Causes:

#### 1. **Recording Stopped Before Last Pulses Saved to Disk**
- ASIO buffer may have pulses that weren't written to WAV yet
- Solution: Check `SaveAudio` function drains all buffers before stopping

#### 2. **Sync Pulse Detection Threshold Too High**
- Last few pulses might be weaker, below detection threshold
- Current threshold: `'MinPeakHeight', 0.3` (line 1245)
- Solution: Lower threshold or use adaptive detection

#### 3. **Ultrasound Stopped Before Audio Recording**
- User stopped ultrasound first, then audio
- Last few seconds of audio have no corresponding sync pulses
- Solution: This is user error, not a bug

#### 4. **Pulse Detection Window Too Narrow**
- If FPS detection is wrong, pulse spacing filter might miss pulses
- Current filter: `'MinPeakDistance', 1/max_fps` (line 1245)
- Solution: Verify detected FPS matches actual ultrasound frame rate

---

## Testing

### Test 1: Verify Clean Endings

1. **Record session** with audio + ultrasound (at least 10 seconds)
2. **Convert TVD to MP4** with updated code
3. **Play MP4 and skip to last 3 seconds**
4. **Expected**:
   - ✅ Audio and video both end at same time
   - ✅ No silent video at end
   - ✅ No frozen frame at end
   - ✅ Smooth ending exactly at last sync pulse

### Test 2: Check Duration Matching

Use FFprobe to check stream durations:
```bash
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 recording_001.mp4
ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 recording_001.mp4
ffprobe -v error -select_streams a:0 -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 recording_001.mp4
```

**Expected**:
- All three durations should be identical or within 0.1 seconds
- Should match trimmed audio duration (not full video duration)

### Test 3: Verify Sync Pulse Detection

1. **Open trimmed FLAC file** in Audacity or MATLAB
2. **Check Ch2 (Telemed sync)**:
   - Verify pulses are clean and detected correctly
   - Check if pulses continue to very end of recording
   - Look for missing pulses at the end

3. **Compare with original WAV**:
   - Check if original WAV has more sync pulses after trimmed endpoint
   - If yes: Detection issue (pulses exist but not detected)
   - If no: Recording stopped correctly at last pulse

### Test 4: Check Sync Timing Log

Open `recording_001_sync.txt` and check:
```
Number of sync pulses detected: 120
First pulse detected at: 0.789 seconds
frameStart (video offset): 0.856 seconds
```

**Verify**:
- Pulse count matches expected (~FPS × recording_duration)
- If much lower: Pulse detection issue
- If matches: Recording stopped at correct time

---

## Troubleshooting

### Issue: Last 1-2 Seconds Still Silent/Frozen

**Check FFmpeg command output**:
```matlab
% In ffmpegCombineVideoAudio, line 1293
[status,cmdout] = system(command,'-echo');
```

Look for `-shortest` in the echoed command. If missing:
- Verify `ifUseShortest=true` was passed
- Check line 1271: `if opt.ifUseShortest, useShortest = '-shortest'; ...`

### Issue: Output Too Short (Missing End Content)

**Possible causes**:
1. **Sync pulses stopped before recording stopped**
   - Check original WAV Ch2 for pulse continuity
   - Ensure ultrasound keeps running until Stop pressed

2. **Detection threshold too high**
   - Try lowering `MinPeakHeight` from 0.3 to 0.2 in line 1245:
   ```matlab
   [pks, locs] = findpeaks(syncs,sr, 'MinPeakHeight', 0.2, 'MinPeakDistance',1/max_fps);
   ```

3. **Audio buffer not fully saved**
   - Check `SaveAudio` function (lines 559-592)
   - Verify all ASIO frames drained before stopping

### Issue: Inconsistent Durations Across Recordings

**Check sync timing logs**:
```bash
# In output folder, check multiple *_sync.txt files
cat recording_001_sync.txt | grep "Number of sync pulses"
cat recording_002_sync.txt | grep "Number of sync pulses"
cat recording_003_sync.txt | grep "Number of sync pulses"
```

**If pulse counts vary widely**:
- Detection inconsistency
- Variable recording durations (expected)
- Hardware sync signal issues

---

## FFmpeg Command Comparison

### Before (No `-shortest` Flag):
```bash
ffmpeg -itsoffset 0.856 -i video.avi -i audio.flac \
  -map 0:v -map 1:a -vf fps=60 -r 60 -vsync cfr \
  -c:v libx264 -pix_fmt yuv420p -preset slow -crf 23 -c:a copy \
  -y output.mp4
```
**Result**: Output duration = max(video_duration, audio_duration)
**Problem**: Longer stream continues after shorter one ends

### After (With `-shortest` Flag):
```bash
ffmpeg -itsoffset 0.856 -i video.avi -i audio.flac \
  -map 0:v -map 1:a -vf fps=60 -r 60 -vsync cfr \
  -c:v libx264 -pix_fmt yuv420p -preset slow -crf 23 -c:a copy \
  -shortest \
  -y output.mp4
```
**Result**: Output duration = min(video_duration, audio_duration)
**Success**: Encoding stops when first stream ends (clean cutoff)

---

## Additional Diagnostic: Check Sync Pulse Continuity

If you want to verify sync pulses are continuous to the end, add diagnostic logging to TrimTelemedAudio:

```matlab
% After line 1227 in TrimTelemedAudio
fprintf('Sync pulse analysis:\n');
fprintf('  First pulse: %.3f s\n', locs(1));
fprintf('  Last pulse: %.3f s\n', locs(end));
fprintf('  Total pulses: %d\n', length(locs));
fprintf('  Recording duration: %.3f s\n', nSamplesAudio/sr);
fprintf('  Trimmed audio duration: %.3f s\n', (frameEndN - frameStartN)/sr);
fprintf('  Time after last pulse: %.3f s\n', (nSamplesAudio - locs(end)*sr)/sr);
```

**Expected output**:
```
Sync pulse analysis:
  First pulse: 0.789 s
  Last pulse: 8.234 s
  Total pulses: 120
  Recording duration: 10.500 s
  Trimmed audio duration: 7.478 s
  Time after last pulse: 2.266 s  ← This explains 2s silent video!
```

This shows:
- Recording was 10.5 seconds
- Last sync pulse at 8.2 seconds
- 2.3 seconds of recording AFTER last pulse (no more ultrasound frames)
- Trimmed audio ends at 8.2s, but video continues to 10.5s
- **Solution**: `-shortest` flag stops at 8.2s (end of audio)

---

## Summary

**Changes Made**: 1 modification to MewRecorder.mlapp

### CHANGE 1: Add ifUseShortest=true (Line 2095-2096)
```matlab
% Before:
[status,cmdout] = app.ffmpegCombineVideoAudio(tmpVideoFN, trimmedAudioFN, outVideoFN, ...
    videoOffset=frameStart, fps=target_fps);

% After:
[status,cmdout] = app.ffmpegCombineVideoAudio(tmpVideoFN, trimmedAudioFN, outVideoFN, ...
    videoOffset=frameStart, fps=target_fps, ifUseShortest=true);
```

**Benefits**:
- ✅ **No more silent video** at end (video longer than audio)
- ✅ **No more frozen frames** at end (audio longer than video)
- ✅ **Clean endings** exactly at last detected sync pulse
- ✅ **Consistent output duration** matches trimmed audio
- ✅ **Better A/V synchronization** throughout entire file
- ✅ **Smaller file sizes** (no padding with silent/frozen content)

**Important Notes**:
- If recording shows "chopped while sync pulses going", check sync pulse detection threshold
- Audio is trimmed to last DETECTED pulse, not recording stop time
- This is correct behavior - only synchronized content should be in output

**Estimated Implementation Time**: 2 minutes
**Risk Level**: Very low (standard FFmpeg flag, well-tested)

---

**Document Version**: 1.0
**Last Updated**: 2025-12-12
**Related**:
- Fix_audio_video_sync.md (sync offset implementation)
- FIX_VARIABLE_FPS_v3.md (constant frame rate fix)
**Testing**: Check last 3 seconds of converted MP4 for clean ending

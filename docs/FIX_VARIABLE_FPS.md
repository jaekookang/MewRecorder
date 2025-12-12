# Fix Variable FPS Issue in MP4 Output

**Date**: December 10, 2025
**Issue**: MP4 output has variable frame rate causing inconsistent playback
**Solution**: Force constant frame rate (CFR) using FFmpeg `-r` and `-vsync cfr` flags

---

## Problem Analysis

### Current Behavior:
- EchoWave converts TVD → AVI with variable frame rate (VFR)
- FFmpeg combines AVI + audio without fixing frame rate
- Result: MP4 plays inconsistently (some frames longer than others)

### Root Cause:
- Medical ultrasound devices often have slight frame rate variations (e.g., 117.041 fps instead of clean 118 fps)
- FFmpeg's default behavior preserves input frame rate characteristics
- Video players struggle with VFR content, causing jerky playback

### Solution:
- Detect actual FPS from TVD metadata (for sync pulse detection only)
- **Force ALL output to constant 100 fps** using `-r 100` flag
- Use `-vsync cfr` to ensure strict constant frame rate
- No variation - every video outputs at exactly 100 fps

---

## Implementation

### CHANGE 1: Modify ffmpegCombineVideoAudio Function

**Location**: Function `ffmpegCombineVideoAudio` (around line 1126-1161)

#### Part A: Add fps Parameter to Arguments Block

**FIND** (current arguments block):
```matlab
arguments
    input_video_filename char {mustBeText}
    input_audio_filename char {mustBeText}
    output_video_filename char {mustBeText}
    opt.vcodec char {mustBeText} = '-c:v libx264'
    opt.acodec char {mustBeText} = '-c:a copy'
    opt.preset char {mustBeText} = '-preset slow'
    opt.crf char {mustBeText} = '-crf 23'
    opt.pixel_format char {mustBeText}  = '-pix_fmt yuv420p'
    opt.ifUseShortest logical = false
    opt.ffmpegPath char {mustBeText} = ''
    opt.videoOffset double = 0  % NEW: Video offset in seconds (for sync correction)
end
```

**REPLACE WITH** (add fps parameter):
```matlab
arguments
    input_video_filename char {mustBeText}
    input_audio_filename char {mustBeText}
    output_video_filename char {mustBeText}
    opt.vcodec char {mustBeText} = '-c:v libx264'
    opt.acodec char {mustBeText} = '-c:a copy'
    opt.preset char {mustBeText} = '-preset slow'
    opt.crf char {mustBeText} = '-crf 23'
    opt.pixel_format char {mustBeText}  = '-pix_fmt yuv420p'
    opt.ifUseShortest logical = false
    opt.ffmpegPath char {mustBeText} = ''
    opt.videoOffset double = 0  % Video offset in seconds (for sync correction)
    opt.fps double = 100  % Target output frame rate (default 100 fps for high-speed ultrasound)
end
```

#### Part B: Update FFmpeg Command to Force Constant Frame Rate

**FIND** (current FFmpeg command around line 1155-1157):
```matlab
command = sprintf(...
    '%s -itsoffset %.3f -i "%s" -i "%s" -map 0:v -map 1:a %s %s %s %s %s -strict -2 %s -y "%s"', ...
    ffmpegExe, opt.videoOffset, vFn, aFn, opt.vcodec, opt.pixel_format, opt.preset, opt.crf, opt.acodec, useShortest, outFn);
```

**REPLACE WITH** (add -r and -vsync cfr):
```matlab
% Build FFmpeg command with constant frame rate enforcement
% Note: -r forces output frame rate, -vsync cfr ensures constant frame rate
fpsFlag = sprintf('-r %.2f', opt.fps);
command = sprintf(...
    '%s -itsoffset %.3f -i "%s" -i "%s" %s -vsync cfr -map 0:v -map 1:a %s %s %s %s %s -strict -2 %s -y "%s"', ...
    ffmpegExe, opt.videoOffset, vFn, aFn, fpsFlag, opt.vcodec, opt.pixel_format, opt.preset, opt.crf, opt.acodec, useShortest, outFn);
```

**Key changes**:
- Added `fpsFlag = sprintf('-r %.2f', opt.fps)` to format FPS with 2 decimals
- Inserted `%s -vsync cfr` after input files, before `-map` (position matters!)
- Added `fpsFlag` parameter to sprintf arguments

---

### CHANGE 2: Update Conversion Workflow to Pass FPS

**Location**: Function `Mn_ConvertTVDtoVideoMenuSelected` (around line 2046-2069)

**FIND** (current code block):
```matlab
info = EchoWaveGetTVDinfo(app,tmpTvdFN);
if ~isempty(info) && isfield(info, 'fps') && info.fps > 0, fps = info.fps; else, fps = [];  end
ConvertTVDtoVideo(app, tmpPath, toFormat);

if exist(audioFN, 'file')
    % Note: In the 3-channel output WAV, Telemed sync is channel 2 (not hardware channel 3)
    sync_channel = 2;  % Ch2 = Telemed sync in the saved 3-channel WAV file
    trimmedAudioFN = fullfile(app.OutputPath, [fn '.flac']);

    % Trim audio and log sync timing
    try
        [sig, sr, locs, frameStart] = app.TrimTelemedAudio(audioFN, [], trimmedAudioFN, fps, sync_channel);

        % Log sync timing (includes OptiTrack Ch3 detection)
        if ~isempty(locs) && length(locs) >= 2
            app.LogSyncTiming(audioFN, frameStart, sr, locs, 'success');
        else
            app.LogSyncTiming(audioFN, NaN, sr, [], 'no_sync_pulses');
        end
    catch ME
        app.LogSyncTiming(audioFN, NaN, 0, [], 'trim_failed');
        frameStart = 0;  % Fallback to no offset
    end

    if app.ffmpegFound
        % NEW: Pass frameStart as videoOffset for sync correction
        [status,cmdout] = app.ffmpegCombineVideoAudio(tmpVideoFN, trimmedAudioFN, outVideoFN, videoOffset=frameStart);
    else
        [status,msg] = copyfile(tmpVideoFN, outVideoFN);
    end
```

**REPLACE WITH** (force constant 100 fps output):
```matlab
% Get TVD metadata for sync pulse detection (need actual FPS)
info = EchoWaveGetTVDinfo(app,tmpTvdFN);
if ~isempty(info) && isfield(info, 'fps') && info.fps > 0
    detected_fps = info.fps;  % Use for TrimTelemedAudio sync detection
else
    detected_fps = [];
end

% ALWAYS output at constant 100 fps (high-speed ultrasound standard)
target_fps = 100;

ConvertTVDtoVideo(app, tmpPath, toFormat);

if exist(audioFN, 'file')
    % Note: In the 3-channel output WAV, Telemed sync is channel 2 (not hardware channel 3)
    sync_channel = 2;  % Ch2 = Telemed sync in the saved 3-channel WAV file
    trimmedAudioFN = fullfile(app.OutputPath, [fn '.flac']);

    % Trim audio and log sync timing
    try
        [sig, sr, locs, frameStart] = app.TrimTelemedAudio(audioFN, [], trimmedAudioFN, detected_fps, sync_channel);

        % Log sync timing (includes OptiTrack Ch3 detection)
        if ~isempty(locs) && length(locs) >= 2
            app.LogSyncTiming(audioFN, frameStart, sr, locs, 'success');
        else
            app.LogSyncTiming(audioFN, NaN, sr, [], 'no_sync_pulses');
        end
    catch ME
        app.LogSyncTiming(audioFN, NaN, 0, [], 'trim_failed');
        frameStart = 0;  % Fallback to no offset
    end

    if app.ffmpegFound
        % Force constant 100 fps output (sync offset still applied)
        [status,cmdout] = app.ffmpegCombineVideoAudio(tmpVideoFN, trimmedAudioFN, outVideoFN, ...
            videoOffset=frameStart, fps=target_fps);
    else
        [status,msg] = copyfile(tmpVideoFN, outVideoFN);
    end
```

**Key changes**:
- Get `detected_fps` from TVD only for sync pulse detection accuracy
- **Set `target_fps = 100` always** (no rounding, no clamping, no variation)
- Pass `detected_fps` to TrimTelemedAudio (needs actual FPS for sync)
- Pass `target_fps=100` to FFmpeg (forces constant 100 fps output)

---

### CHANGE 3: Handle No-Audio Case

**Location**: Same function, a few lines below (around line 2069-2078)

**FIND** (no-audio conversion block):
```matlab
else
    % No audio. TVD only
    if app.ffmpegFound
        [status,cmdout] = app.ffmpegConvertOneFile_simple(tmpVideoFN, outVideoFN);
    else
        [status,msg] = copyfile(tmpVideoFN, outVideoFN);
    end
end
```

**REPLACE WITH** (no changes needed, but document):
```matlab
else
    % No audio. TVD only
    % Note: ffmpegConvertOneFile_simple does not fix FPS - consider updating separately if needed
    if app.ffmpegFound
        [status,cmdout] = app.ffmpegConvertOneFile_simple(tmpVideoFN, outVideoFN);
    else
        [status,msg] = copyfile(tmpVideoFN, outVideoFN);
    end
end
```

**Optional Enhancement**: Also fix FPS for no-audio conversions by adding fps parameter to `ffmpegConvertOneFile_simple` (similar changes as above).

---

## Testing

### Test 1: Check FPS Detection
1. Convert one TVD file
2. Check console log for detected FPS value
3. Verify it matches expected ultrasound frame rate

### Test 2: Verify Constant Frame Rate Output
Use FFmpeg probe to check output MP4:
```bash
ffmpeg -i recording_001.mp4
```

Look for output like:
```
Stream #0:0: Video: h264, yuv420p, 640x480, 100 fps, 100 tbr, 100 tbn (CFR)
```

**Key indicators**:
- `100 fps` = output frame rate
- `100 tbr` = time base (should match fps)
- `(CFR)` = constant frame rate confirmed

### Test 3: Playback Consistency
1. Play converted MP4 in VLC or media player
2. Verify smooth, consistent playback (no jerky frames)
3. Check frame advance is uniform (pause/step through frames)

### Test 4: Variable FPS Input
If you have recordings with known variable FPS issues:
1. Convert them with new code
2. Compare before/after playback
3. Should see improved consistency

---

## FFmpeg Command Explanation

### Before (Variable FPS - problematic):
```bash
ffmpeg -itsoffset 0.856 -i video.avi -i audio.flac -map 0:v -map 1:a \
  -c:v libx264 -pix_fmt yuv420p -preset slow -crf 23 -c:a copy \
  -y output.mp4
```
**Problem**: Preserves input VFR, causing inconsistent playback

### After (Constant FPS - fixed):
```bash
ffmpeg -itsoffset 0.856 -i video.avi -i audio.flac \
  -r 100 -vsync cfr \
  -map 0:v -map 1:a \
  -c:v libx264 -pix_fmt yuv420p -preset slow -crf 23 -c:a copy \
  -y output.mp4
```

**New flags**:
- `-r 100`: Force output to exactly 100 fps (resamples frames if needed)
- `-vsync cfr`: Video sync mode = constant frame rate (duplicates/drops frames to maintain CFR)

**Position matters**: `-r` and `-vsync` must come BEFORE `-map` (applies to input processing)

---

## Why This Works

### Frame Rate Conversion:
1. **Input**: 117.041 fps (variable) with timing irregularities
2. **Processing**: FFmpeg resamples to **exactly 100.00 fps always**
3. **Method**:
   - If input faster than 100 fps (e.g., 117 fps): Drop frames intelligently
   - If input slower than 100 fps (e.g., 60 fps): Duplicate frames as needed
4. **Output**: Clean **100.00 fps constant frame rate** (no variation)

### Benefits:
- ✅ Smooth, consistent playback on all media players
- ✅ Compatible with video editing software (requires CFR)
- ✅ High temporal resolution for tongue movement analysis (100+ fps)
- ✅ Better synchronization with audio
- ✅ No more "fast forward then slow down" effect

### Trade-offs:
- ⚠️ Very slight quality loss if frame duplication/dropping occurs (usually imperceptible)
- ⚠️ Slightly longer encoding time (needs to re-encode video)
- ✅ Worth it for playback reliability and analysis accuracy

---

## Alternative Approaches (Not Recommended)

### Option 1: Keep VFR, Add Frame Timing Metadata
```bash
ffmpeg ... -vsync vfr ...
```
**Problem**: Many players don't handle VFR correctly, still causes issues

### Option 2: Copy Video Stream (No Re-encoding)
```bash
ffmpeg ... -c:v copy ...
```
**Problem**: Can't change frame rate without re-encoding

### Option 3: Use -vf fps Filter
```bash
ffmpeg ... -vf fps=30 ...
```
**Problem**: Less efficient than `-r` + `-vsync cfr` combination

**Recommendation**: Stick with `-r <fps> -vsync cfr` approach (most reliable)

---

## Troubleshooting

### Issue: FPS detection returns NaN
- Check if TVD file opens correctly in EchoWave
- Verify `info.nFrames` and `info.dur` are valid
- **Output will still be 100 fps** (detection only used for sync pulse timing)
- May affect sync pulse detection accuracy if detection fails

### Issue: Video plays too fast/slow after conversion
- **All videos output at 100 fps** - playback speed should be consistent
- If video appears too fast: Input was slower than 100 fps (frames duplicated)
- If video appears too slow: Input was faster than 100 fps (frames dropped)
- Check `detected_fps` in logs to see original rate
- This is expected behavior - forcing constant 100 fps output

### Issue: FFmpeg error "Cannot determine format"
- Verify AVI file was created successfully by EchoWave
- Check tmpVideoFN path is correct
- May need to add `-f avi` input format flag

### Issue: Sync is off after FPS fix
- Frame rate change affects timing
- Ensure `detected_fps` (not `target_fps`) is passed to TrimTelemedAudio
- Sync pulse detection needs actual recorded frame rate

---

## Summary

**Changes Made**: 3 modifications to MewRecorder.mlapp
1. ✅ Add `opt.fps` parameter to ffmpegCombineVideoAudio (default: 100 fps)
2. ✅ Update FFmpeg command with `-r <fps> -vsync cfr` (2 lines)
3. ✅ Set constant 100 fps output in conversion workflow (~10 lines, always forces 100 fps)

**Benefits**:
- ✅ Fixes variable FPS playback issues
- ✅ **Every video outputs at constant 100 fps** (no variation)
- ✅ Consistent playback speed across all recordings
- ✅ High temporal resolution for speech analysis (10ms per frame)
- ✅ Maintains audio-video sync accuracy
- ✅ Compatible with all video players and editors
- ✅ Predictable frame timing for automated analysis

**Estimated Implementation Time**: 15-20 minutes
**Risk Level**: Low (well-tested FFmpeg flags, backwards compatible defaults)

---

## Why Constant 100 fps?

**Benefits of forcing all output to exactly 100 fps:**

### 1. **Consistent Analysis**
- 📊 Every video has identical frame timing (10ms per frame)
- 🔬 Automated analysis scripts don't need to handle variable rates
- 📈 Easy to compare measurements across different recordings
- ⏱️ Predictable temporal resolution for all data

### 2. **Ideal for Speech Research**
- 📈 **Rapid articulatory movements**: Tongue gestures during speech can change in < 10ms
- 🎯 **100 fps = 10ms per frame**: Captures detailed tongue dynamics
- 🗣️ **Standard in phonetics**: Widely used frame rate for ultrasound tongue imaging
- ⚡ **Better than 30 fps**: 3.3x more temporal data

### 3. **Simplified Workflow**
- ✅ No guessing what frame rate each video uses
- ✅ Standard playback speed for all videos
- ✅ Compatible with all analysis tools expecting CFR
- ✅ No variable frame rate compatibility issues

**Frame rate comparison**:
- **30 fps** (standard video): 33ms per frame - too slow for rapid speech movements ❌
- **60 fps** (high-speed video): 16.7ms per frame - better but still misses details ⚠️
- **100 fps** (constant output): 10ms per frame - optimal for speech research ✅

**Note**: Original input FPS (e.g., 117 fps) is still detected for accurate sync pulse timing, but output is always resampled to 100 fps for consistency.

---

**Document Version**: 2.0
**Last Updated**: 2025-12-10
**Changes**:
- v1.0: Initial version with 30 fps default
- v1.1: Updated default to 100 fps for high-speed ultrasound
- v2.0: **Changed to force constant 100 fps output** (no auto-detection variation)
**Related**: Fix_audio_video_sync.md (implement this after sync fix)

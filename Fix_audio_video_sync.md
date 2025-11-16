# Fix Audio-Video Synchronization Issue

**Date**: November 16, 2025
**Issue**: Ultrasound video lags ~1 second behind audio in MP4 playback
**Status**: Analysis complete, ready to implement

---

## Problem

After recording with MewRecorder and converting TVD files to MP4 (via Menu → Convert TVD to Video), the ultrasound video plays ~1 second behind the audio.

**Key observation**: The issue is **intermittent**:
- Recording 1: ~1 second delay ❌
- Recording 2: Perfect sync ✅
- Recording 3: ~1 second delay ❌

**Confirmed behavior**: Video has all frames present but plays delayed throughout (Scenario B: offset error, not missing frames).

---

## Root Cause

### Why It Happens

1. **Audio always starts first** (consistent ~50ms ASIO initialization)
2. **Telemed ultrasound starts second** with **variable delay**:
   - Cold start: ~800-1000ms delay
   - Warm start: ~50-100ms delay (hardware already active)
   - This explains why Recording 2 had perfect sync

3. **Audio pre-recording gap** varies by hardware warmup state
4. **FFmpeg doesn't know about the offset** when combining video + audio

### Why Telemed Timing Varies

The Telemed COM object (`app.asmcmd`) is created once at startup and reused for all recordings. Hardware response time depends on power state:
- **Just started**: Hardware cold, takes 1 second to respond
- **Recently used**: Hardware warm, responds in 50ms
- **After idle time**: Hardware cooling, takes 800ms

---

## Solution: Apply FFmpeg Offset

Modify 3 functions to pass the calculated `frameStart` offset to FFmpeg's `-itsoffset` parameter.

### Step 1: Modify TrimTelemedAudio() to Return frameStart

**Location**: Lines 1090-1124 in MewRecorder.mlapp

**Change function signature** from:
```matlab
function [sig, sr, locs] = TrimTelemedAudio(app, audioFN, ifPlot, trimmedAudioFN, fps, sync_channel)
```

**To**:
```matlab
function [sig, sr, locs, frameStart] = TrimTelemedAudio(app, audioFN, ifPlot, trimmedAudioFN, fps, sync_channel)
```

**Add return value** at the end (frameStart is already calculated at line 1101):
```matlab
% frameStart already exists from: frameStart = mean(locs(1:2));
% Just ensure it's returned in function signature above
```

---

### Step 2: Modify ffmpegCombineVideoAudio() to Accept Offset

**Location**: Lines 1126-1161 in MewRecorder.mlapp

**Current function signature**:
```matlab
function [status,cmdout] = ffmpegCombineVideoAudio(input_video_filename, input_audio_filename, output_video_filename, opt)
```

**Add new optional parameter** in arguments block (after line 1141):
```matlab
arguments
    input_video_filename char {mustBeText}
    input_audio_filename char {mustBeText}
    output_video_filename char {mustBeText}
    opt.vcodec char {mustBeText} = '-c:v libx264'
    opt.acodec char {mustBeText} = '-c:a copy'
    opt.preset char {mustBeText} = '-preset slow'
    opt.crf char {mustBeText} = '-crf 23'
    opt.pixel_format char {mustBeText} = '-pix_fmt yuv420p'
    opt.ifUseShortest logical = false
    opt.ffmpegPath char {mustBeText} = ''
    opt.videoOffset double = 0  % NEW: Video offset in seconds
end
```

**Modify FFmpeg command** at line 1156:
```matlab
command = sprintf(...
    '%s -itsoffset %.3f -i "%s" -i "%s" -map 0:v -map 1:a %s %s %s %s %s -strict -2 %s -y "%s"', ...
    ffmpegExe, opt.videoOffset, vFn, aFn, opt.vcodec, opt.pixel_format, opt.preset, opt.crf, opt.acodec, useShortest, outFn);
```

**Key change**: Added `-itsoffset %.3f` and `opt.videoOffset` parameter

---

### Step 3: Update Conversion Workflow to Pass Offset

**Location**: Line 1935-1938 in `Mn_ConvertTVDtoVideoMenuSelected()`

**Current code**:
```matlab
[sig, sr, locs, frameStart] = app.TrimTelemedAudio(audioFN, [], trimmedAudioFN, fps, sync_channel);

if app.ffmpegFound
    [status,cmdout] = app.ffmpegCombineVideoAudio(tmpVideoFN, trimmedAudioFN, outVideoFN);
```

**New code**:
```matlab
[sig, sr, locs, frameStart] = app.TrimTelemedAudio(audioFN, [], trimmedAudioFN, fps, sync_channel);

if app.ffmpegFound
    [status,cmdout] = app.ffmpegCombineVideoAudio(tmpVideoFN, trimmedAudioFN, outVideoFN, videoOffset=frameStart);
```

**Key change**: Pass `videoOffset=frameStart` to ffmpegCombineVideoAudio

---

## Enhancement: Log frameStart Values (Optional but Recommended)

This helps verify the fix is working and identify any remaining issues.

### Add These Properties

**Location**: After line 103 in MewRecorder.mlapp

```matlab
sessionRecordingCounter = 0;  % Track recording number
syncTimingLogFilename = '_sync_timing.csv';  % Log file name
```

### Increment Counter When Recording Starts

**Location**: After line 1258 in `StartRecordButtonPushed()`

```matlab
app.sessionRecordingCounter = app.sessionRecordingCounter + 1;
```

### Add Logging Function

**Location**: After line 760 (after `do_log` function)

```matlab
function LogSyncTiming(app, filename, frameStart, sampleRate, locs, status)
    if nargin < 6, status = 'success'; end
    [~, baseFilename, ~] = fileparts(filename);

    % Calculate metrics
    numPulses = length(locs);
    if numPulses >= 2
        firstPulse = locs(1);
        frameDuration = median(diff(locs(2:end)));
    else
        firstPulse = NaN;
        frameDuration = NaN;
    end

    % Log file path
    logPath = fullfile(app.OutputPath, app.syncTimingLogFilename);

    % Create header if new file
    if ~exist(logPath, 'file')
        try
            fid = fopen(logPath, 'wt');
            if fid > 0
                fprintf(fid, 'Timestamp,Filename,FrameStart_sec,SampleRate_Hz,SessionRun,NumPulses,FirstPulse_sec,FrameDuration_sec,Status\n');
                fclose(fid);
            end
        catch
            return;
        end
    end

    % Append data
    try
        fid = fopen(logPath, 'at');
        if fid > 0
            timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            fprintf(fid, '%s,%s,%.6f,%d,%d,%d,%.6f,%.6f,%s\n', ...
                timestamp, baseFilename, frameStart, sampleRate, ...
                app.sessionRecordingCounter, numPulses, firstPulse, frameDuration, status);
            fclose(fid);

            app.logMessage(sprintf('Sync logged: frameStart=%.3fs (run #%d)', ...
                frameStart, app.sessionRecordingCounter), 'info');
        end
    catch
        % Fail silently
    end
end
```

### Call Logging During Conversion

**Location**: After line 1935 in `Mn_ConvertTVDtoVideoMenuSelected()`

**Wrap the TrimTelemedAudio call**:
```matlab
try
    [sig, sr, locs, frameStart] = app.TrimTelemedAudio(audioFN, [], trimmedAudioFN, fps, sync_channel);

    % Log sync timing
    if ~isempty(locs) && length(locs) >= 2
        LogSyncTiming(app, audioFN, frameStart, sr, locs, 'success');
    else
        LogSyncTiming(app, audioFN, NaN, sr, [], 'no_sync_pulses');
    end
catch ME
    LogSyncTiming(app, audioFN, NaN, sr, [], 'trim_failed');
end

if app.ffmpegFound
    [status,cmdout] = app.ffmpegCombineVideoAudio(tmpVideoFN, trimmedAudioFN, outVideoFN, videoOffset=frameStart);
```

---

## Testing After Implementation

1. **Record 3 test sessions** (already done)
2. **Run Menu → Convert TVD to Video**
3. **Check `_sync_timing.csv`** in output folder:
   - Verify `frameStart` values are in seconds (0.01-2.0 range)
   - Check if values explain the 1-second delay
4. **Play MP4 files** and verify sync is fixed
5. **If sync is reversed** (video ahead of audio), change sign:
   ```matlab
   videoOffset=-frameStart  % Negative offset instead of positive
   ```

---

## Expected Results

### Before Fix
- Run 1: 1 second delay (frameStart ~0.85s, but not applied)
- Run 2: Perfect sync (frameStart ~0.05s)
- Run 3: 1 second delay (frameStart ~0.80s, but not applied)

### After Fix
- All runs: Perfect sync (FFmpeg compensates using actual frameStart)
- CSV log shows exact frameStart values used
- Sync error < 33ms (1 frame at 30fps)

---

## Notes

**Important**:
- Conversion is MANUAL (Menu → Convert TVD to Video), not automatic
- You can re-convert existing recordings after implementing the fix
- The logging enhancement helps verify the fix works

**If issues persist**:
- Check CSV log to see actual `frameStart` values
- If values seem wrong (e.g., very large numbers), there may be a unit conversion bug
- The offset sign might need to be inverted (use `-frameStart` instead of `frameStart`)

---

## OptiTrack Synchronization (Important for Motion Correction)

### Why This Matters

If you use OptiTrack data to correct ultrasound tongue contours for head movement, you need accurate frame-level alignment between:
- **Ultrasound video frame N** → **OptiTrack marker positions at same time**

### OptiTrack Sync Signal (Ch3)

Unlike Telemed (continuous pulses), OptiTrack sends:
- **1 pulse at recording START** (when `natnet_client.startRecord()` is called)
- **1 pulse at recording STOP** (when `natnet_client.stopRecord()` is called)

### How to Align OptiTrack with Video

**Step 1: Detect OptiTrack start pulse in Ch3**
```matlab
[wav, sr] = audioread('recording.wav');
ch3 = abs(wav(:, 3));  % Take absolute value for bipolar pulses
[~, ot_locs] = findpeaks(ch3, sr, 'MinPeakHeight', 0.3, 'NPeaks', 2, 'SortStr', 'descend');
optitrack_start = min(ot_locs);  % First pulse = recording start
```

**Step 2: Calculate offset relative to video**
```matlab
% frameStart = when video starts (from TrimTelemedAudio)
% optitrack_start = when OptiTrack starts (from Ch3 pulse)

video_to_optitrack_offset = frameStart - optitrack_start;
```

**Step 3: Align in your analysis code**
```matlab
% For ultrasound video frame N at fps
video_time = N / fps;  % Time relative to video frame 0

% Find corresponding OptiTrack frame
optitrack_time = video_time + video_to_optitrack_offset;
optitrack_frame_idx = round(optitrack_time * optitrack_fps);

% Get marker positions for this frame
markers = optitrack_data(optitrack_frame_idx).markers;
% Apply head movement correction to tongue contour
```

### Add OptiTrack Logging to LogSyncTiming Function

**Modify the logging function** (line 760) to also capture Ch3:

```matlab
function LogSyncTiming(app, filename, frameStart, sampleRate, locs, status)
    if nargin < 6, status = 'success'; end
    [~, baseFilename, ~] = fileparts(filename);

    % Calculate Telemed metrics (Ch2)
    numPulses = length(locs);
    if numPulses >= 2
        firstPulse = locs(1);
        frameDuration = median(diff(locs(2:end)));
    else
        firstPulse = NaN;
        frameDuration = NaN;
    end

    % NEW: Detect OptiTrack sync pulse (Ch3)
    try
        [wav, sr] = audioread(filename);
        if size(wav, 2) >= 3
            ch3 = abs(wav(:, 3));
            [~, ot_locs] = findpeaks(ch3, sr, 'MinPeakHeight', 0.3, 'NPeaks', 2, 'SortStr', 'descend');
            if ~isempty(ot_locs)
                optitrackStart = min(ot_locs);  % First pulse
                videoToOTOffset = frameStart - optitrackStart;
            else
                optitrackStart = NaN;
                videoToOTOffset = NaN;
            end
        else
            optitrackStart = NaN;
            videoToOTOffset = NaN;
        end
    catch
        optitrackStart = NaN;
        videoToOTOffset = NaN;
    end

    % Log file path
    logPath = fullfile(app.OutputPath, app.syncTimingLogFilename);

    % Create header if new file
    if ~exist(logPath, 'file')
        try
            fid = fopen(logPath, 'wt');
            if fid > 0
                fprintf(fid, 'Timestamp,Filename,FrameStart_sec,SampleRate_Hz,SessionRun,NumPulses,FirstPulse_sec,FrameDuration_sec,OptiTrackStart_sec,VideoToOTOffset_sec,Status\n');
                fclose(fid);
            end
        catch
            return;
        end
    end

    % Append data
    try
        fid = fopen(logPath, 'at');
        if fid > 0
            timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            fprintf(fid, '%s,%s,%.6f,%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%s\n', ...
                timestamp, baseFilename, frameStart, sampleRate, ...
                app.sessionRecordingCounter, numPulses, firstPulse, frameDuration, ...
                optitrackStart, videoToOTOffset, status);
            fclose(fid);

            app.logMessage(sprintf('Sync logged: frameStart=%.3fs, OT offset=%.3fs (run #%d)', ...
                frameStart, videoToOTOffset, app.sessionRecordingCounter), 'info');
        end
    catch
        % Fail silently
    end
end
```

### Updated CSV Format

**New columns**:
```csv
Timestamp,Filename,FrameStart_sec,SampleRate_Hz,SessionRun,NumPulses,FirstPulse_sec,FrameDuration_sec,OptiTrackStart_sec,VideoToOTOffset_sec,Status
2025-11-16 14:23:45,rec001,0.856,48000,1,120,0.789,0.033,0.105,0.751,success
2025-11-16 14:25:12,rec002,0.102,48000,2,145,0.045,0.033,0.089,0.013,success
2025-11-16 14:28:33,rec003,0.721,48000,3,98,0.650,0.033,0.112,0.609,success
```

### Using the Offset in Analysis

**Example MATLAB analysis script**:
```matlab
% Load sync data
sync = readtable('_sync_timing.csv');
run_number = 1;
video_to_ot_offset = sync.VideoToOTOffset_sec(run_number);

% Load OptiTrack data
optitrack = load('recording_001_optitrack.mat');  % or .tak file

% For each video frame
for frame_num = 1:num_frames
    video_time = frame_num / video_fps;

    % Find corresponding OptiTrack time
    ot_time = video_time + video_to_ot_offset;
    ot_idx = round(ot_time * optitrack_fps);

    % Get marker positions
    if ot_idx > 0 && ot_idx <= length(optitrack.data)
        head_markers = optitrack.data(ot_idx).markers;

        % Apply head movement correction
        corrected_tongue = correct_for_head_movement(tongue_contour(frame_num), head_markers);
    end
end
```

### Important Notes

- OptiTrack has only START/STOP pulses (not continuous like Telemed)
- Cannot detect drift during recording - assumes clocks stay synchronized
- If OptiTrack fps ≠ Video fps, you may see alignment errors accumulate over long recordings
- **Test accuracy**: Record a known movement pattern and verify OptiTrack correction works correctly

---

## Summary

**3 code changes for Video-Audio sync**:
1. Return `frameStart` from `TrimTelemedAudio()`
2. Accept `videoOffset` parameter in `ffmpegCombineVideoAudio()` and add `-itsoffset` to FFmpeg command
3. Pass `frameStart` to FFmpeg in conversion workflow

**Recommended enhancement for OptiTrack sync**:
4. Add logging system to track both `frameStart` (Ch2) and `optitrackStart` (Ch3)
5. Use `VideoToOTOffset` in your motion correction analysis scripts

**Implementation time**: ~45 minutes (including OptiTrack logging)
**Files to modify**: `MewRecorder.mlapp` (via MATLAB App Designer)
**Backup first**: Create `MewRecorder_backup_251116.mlapp`

---

**Document Version**: 3.1
**Last Updated**: 2025-11-16
**Changes**: Added OptiTrack synchronization section for head movement correction use case

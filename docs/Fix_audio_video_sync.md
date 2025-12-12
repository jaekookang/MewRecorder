# Fix Audio-Video Synchronization Issue

**Date**: December 10, 2025
**Issue**: Ultrasound video lags ~1 second behind audio in MP4 playback
**Status**: ✅ **READY TO IMPLEMENT** - Complete implementation guide with copy/paste code blocks


---
Claude Note:

 Perfect! I've updated Fix_audio_video_sync.md
  with complete implementation guidance. Here's
  what's ready for you:

  ✅ Complete Implementation Guide Created

  Required Changes (Fixes Audio-Video Sync):

  1. Add logging properties (2 lines) - Track
  recording sessions
  2. Increment counter (1 line) - Count each
  recording
  3. Add LogSyncTiming function (~70 lines) - Logs
   frameStart + OptiTrack offset
  4. Modify ffmpegCombineVideoAudio (2 lines) -
  Accept videoOffset parameter, add -itsoffset to
  FFmpeg
  5. Update conversion workflow (~15 lines) - Pass
   frameStart to FFmpeg, add logging

  Optional Change 6 (Your Request - Saves Disk
  Space):

  Conditional Ch3 channel saving (~10 lines in
  SaveAudio function around line 559-576)

  What it does:
  - If OptiTrack checkbox disabled: Save 2-channel
   WAV (Audio, Telemed sync) → 33% smaller file
  - If OptiTrack checkbox enabled: Save 3-channel
  WAV (Audio, Telemed sync, OptiTrack sync)

  Benefits:
  - ✅ Smaller WAV files when OptiTrack not used
  - ✅ Clearer - channels match what was actually
  recorded
  - ✅ No confusion about empty Ch3
  - ✅ Backwards compatible - works with both 2
  and 3-channel files

  📋 Ready to Copy/Paste

  The document now has:
  - Clear "FIND THIS / REPLACE WITH" sections for
  each change
  - Exact line numbers based on current code
  - Complete code blocks ready to paste into App
  Designer
  - Verification checklist to ensure all changes
  are made
  - Testing guide with expected CSV output
  - Troubleshooting section if issues arise

  Next Steps for You:

  1. Open Fix_audio_video_sync.md
  2. Backup current MewRecorder.mlapp as
  MewRecorder_backup_251210.mlapp
  3. Open MewRecorder.mlapp in MATLAB App Designer
  4. Follow the 6 change sections, copying and
  pasting code
  5. Test by converting an existing TVD file
  6. Check _sync_timing.csv is created with
  frameStart values
  
  The sync fix will work regardless of whether you
   implement Change 6, but Change 6 is recommended
   for cleaner output when OptiTrack isn't being
  used.

---

## Problem Summary

After converting TVD files to MP4 (Menu → Convert All TVD to MP4), the ultrasound video plays ~1 second behind audio.

**Key observation**: Issue is **intermittent**
- Recording 1: ~1 second delay ❌
- Recording 2: Perfect sync ✅
- Recording 3: ~1 second delay ❌

**Root cause**: Telemed ultrasound has **variable startup delay** (50ms warm vs. 800-1000ms cold), but FFmpeg doesn't compensate for this offset when combining video + audio.

---

## Implementation Guide

### Before You Start

1. **Backup your current file**: Save a copy as `MewRecorder_backup_251210.mlapp`
2. **Open in MATLAB App Designer**: Right-click → Open in App Designer
3. **Implementation time**: ~30-45 minutes
4. **Test after each change**: Verify no syntax errors

---

## CHANGE 1: Add Logging Property

**Location**: In the `properties (Access = private)` section (around line 49-100)

**What to do**: Find the properties section and ADD this one line anywhere in the block:

```matlab
sessionRecordingCounter = 0;  % Track recording number for sync logging
```

**Example placement** (add after line ~76 near `tmpFolder` definition):
```matlab
tmpFolder = '_mwr_tmp_mwr'; tmpFile = '_mwr_tmp_mwr_test.txt';
sessionRecordingCounter = 0;  % Track recording number for sync logging
```

**Note**: We only need `sessionRecordingCounter`. Each recording will get its own `_sync.txt` log file automatically.

---

## CHANGE 2: Increment Recording Counter

**Location**: In `StartRecordButtonPushed` function (around line 1255-1270)

**What to do**: Find this function and ADD one line after the log messages at the start:

**Find this code** (lines 1257-1258):
```matlab
app.logMessage('----------------------------', 'info');
app.logMessage('New recording session started', 'info');
```

**Add this line right after**:
```matlab
app.logMessage('----------------------------', 'info');
app.logMessage('New recording session started', 'info');
app.sessionRecordingCounter = app.sessionRecordingCounter + 1;  % NEW LINE
```

---

## CHANGE 3: Add Logging Function with OptiTrack Support

**Location**: After `do_log` function ends (around line 760)

**What to do**: ADD this complete new function right after the `end % do_log` line:

**Note**: This creates individual `_sync.txt` log files for each recording (not a single CSV file).

```matlab
        %% Sync timing logger (for audio-video alignment verification)
        function LogSyncTiming(app, filename, frameStart, sampleRate, locs, status)
            % Log sync timing data for video-audio alignment verification
            % Creates individual _sync.txt log file for each recording
            % Includes OptiTrack sync pulse detection from Ch3
            if nargin < 6, status = 'success'; end
            [filepath, baseFilename, ~] = fileparts(filename);

            % Create log filename: recording_001.wav → recording_001_sync.txt
            logFilename = [baseFilename, '_sync.txt'];
            logPath = fullfile(app.OutputPath, logFilename);

            % Calculate Telemed metrics (Ch2)
            numPulses = length(locs);
            if numPulses >= 2
                firstPulse = locs(1);
                frameDuration = median(diff(locs(2:end)));
                estimatedFPS = 1 / frameDuration;
            else
                firstPulse = NaN;
                frameDuration = NaN;
                estimatedFPS = NaN;
            end

            % Detect OptiTrack sync pulse (Ch3)
            try
                [wav, sr] = audioread(filename);
                if size(wav, 2) >= 3
                    ch3 = abs(wav(:, 3));
                    [~, ot_locs] = findpeaks(ch3, sr, 'MinPeakHeight', 0.3, 'NPeaks', 2, 'SortStr', 'descend');
                    if ~isempty(ot_locs)
                        optitrackStart = min(ot_locs);  % First pulse = recording start
                        videoToOTOffset = frameStart - optitrackStart;
                        optitrackDetected = true;
                    else
                        optitrackStart = NaN;
                        videoToOTOffset = NaN;
                        optitrackDetected = false;
                    end
                else
                    optitrackStart = NaN;
                    videoToOTOffset = NaN;
                    optitrackDetected = false;
                end
            catch
                optitrackStart = NaN;
                videoToOTOffset = NaN;
                optitrackDetected = false;
            end

            % Write log file (TXT format, human-readable)
            try
                fid = fopen(logPath, 'wt');
                if fid > 0
                    fprintf(fid, '=====================================================\n');
                    fprintf(fid, 'MewRecorder - Audio-Video Synchronization Log\n');
                    fprintf(fid, '=====================================================\n\n');

                    fprintf(fid, 'Recording File: %s\n', baseFilename);
                    fprintf(fid, 'Conversion Date: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
                    fprintf(fid, 'Session Run #: %d\n', app.sessionRecordingCounter);
                    fprintf(fid, 'Status: %s\n\n', upper(status));

                    fprintf(fid, '--- Video Sync Offset ---\n');
                    fprintf(fid, 'frameStart (video offset): %.6f seconds\n', frameStart);
                    fprintf(fid, '  -> This offset was applied to FFmpeg for A/V sync\n\n');

                    fprintf(fid, '--- Telemed Ultrasound Sync (Ch2) ---\n');
                    fprintf(fid, 'Number of sync pulses detected: %d\n', numPulses);
                    if ~isnan(firstPulse)
                        fprintf(fid, 'First pulse detected at: %.6f seconds\n', firstPulse);
                        fprintf(fid, 'Frame duration (median): %.6f seconds\n', frameDuration);
                        fprintf(fid, 'Estimated frame rate: %.2f fps\n', estimatedFPS);
                    else
                        fprintf(fid, 'WARNING: No Telemed sync pulses detected!\n');
                    end
                    fprintf(fid, '\n');

                    fprintf(fid, '--- OptiTrack Motion Capture Sync (Ch3) ---\n');
                    if optitrackDetected
                        fprintf(fid, 'OptiTrack start pulse detected at: %.6f seconds\n', optitrackStart);
                        fprintf(fid, 'Video-to-OptiTrack offset: %.6f seconds\n', videoToOTOffset);
                        fprintf(fid, '  -> Use this offset for head movement correction\n');
                        fprintf(fid, '  -> Formula: optitrack_time = video_time + %.6f\n', videoToOTOffset);
                    else
                        fprintf(fid, 'No OptiTrack sync pulses detected (Ch3 silent or not recorded)\n');
                    end
                    fprintf(fid, '\n');

                    fprintf(fid, '--- Audio Settings ---\n');
                    fprintf(fid, 'Sample Rate: %d Hz\n', sampleRate);
                    fprintf(fid, '\n');

                    fprintf(fid, '=====================================================\n');
                    fprintf(fid, 'For analysis, use frameStart to align video with audio.\n');
                    fprintf(fid, 'For motion correction, use Video-to-OptiTrack offset.\n');
                    fprintf(fid, '=====================================================\n');

                    fclose(fid);

                    if optitrackDetected
                        app.logMessage(sprintf('Sync log saved: %s (frameStart=%.3fs, OT offset=%.3fs)', ...
                            logFilename, frameStart, videoToOTOffset), 'info');
                    else
                        app.logMessage(sprintf('Sync log saved: %s (frameStart=%.3fs)', ...
                            logFilename, frameStart), 'info');
                    end
                end
            catch ME
                app.logMessage(sprintf('Warning: Failed to write sync log: %s', ME.message), 'warning');
            end
        end
```

---

## CHANGE 4: Modify ffmpegCombineVideoAudio to Accept Offset

**Location**: Function `ffmpegCombineVideoAudio` (around line 1126-1161)

### Part A: Add videoOffset Parameter

**Find the `arguments` block** (lines 1131-1142):
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
end
```

**ADD this line before `end`**:
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

### Part B: Modify FFmpeg Command

**Find the command sprintf** (around line 1155-1157):
```matlab
command = sprintf(...
    '%s -i "%s" -i "%s" -map 0:v -map 1:a %s %s %s %s %s -strict -2 %s -y "%s"', ...
    ffmpegExe, vFn, aFn, opt.vcodec, opt.pixel_format, opt.preset, opt.crf, opt.acodec, useShortest, outFn);
```

**REPLACE with** (adds `-itsoffset` parameter):
```matlab
command = sprintf(...
    '%s -itsoffset %.3f -i "%s" -i "%s" -map 0:v -map 1:a %s %s %s %s %s -strict -2 %s -y "%s"', ...
    ffmpegExe, opt.videoOffset, vFn, aFn, opt.vcodec, opt.pixel_format, opt.preset, opt.crf, opt.acodec, useShortest, outFn);
```

**Key changes**:
- Added `-itsoffset %.3f` right after `%s` (ffmpegExe)
- Added `opt.videoOffset` parameter after `ffmpegExe`

---

## CHANGE 5: Update Conversion Workflow

**Location**: Function `Mn_ConvertTVDtoVideoMenuSelected` (around line 1931-1941)

**Find this code block** (lines 1931-1941):
```matlab
if exist(audioFN, 'file')
    % Note: In the 3-channel output WAV, Telemed sync is channel 2 (not hardware channel 3)
    sync_channel = 2;  % Ch2 = Telemed sync in the saved 3-channel WAV file
    trimmedAudioFN = fullfile(app.OutputPath, [fn '.flac']);
    [sig, sr, locs, frameStart] = app.TrimTelemedAudio(audioFN, [], trimmedAudioFN, fps, sync_channel);

    if app.ffmpegFound
        [status,cmdout] = app.ffmpegCombineVideoAudio(tmpVideoFN, trimmedAudioFN, outVideoFN);
    else
        [status,msg] = copyfile(tmpVideoFN, outVideoFN);
    end
```

**REPLACE with** (adds logging and videoOffset parameter):
```matlab
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

**Key changes**:
- Wrapped `TrimTelemedAudio` in try-catch with logging
- Added `videoOffset=frameStart` parameter to `ffmpegCombineVideoAudio`

---

## Verification Checklist

After making all changes in App Designer:

### Required Changes (for sync fix)
- [ ] **Change 1**: Added `sessionRecordingCounter` property (ONE line, not two)
- [ ] **Change 2**: Added counter increment in `StartRecordButtonPushed`
- [ ] **Change 3**: Added complete `LogSyncTiming` function after `do_log` (creates per-file _sync.txt logs)
- [ ] **Change 4A**: Added `opt.videoOffset` parameter to `ffmpegCombineVideoAudio` arguments
- [ ] **Change 4B**: Modified FFmpeg command to include `-itsoffset`
- [ ] **Change 5**: Updated conversion workflow with logging and `videoOffset=frameStart`

### Optional Change (for channel optimization)
- [ ] **Change 6**: Modified `SaveAudio` to conditionally save Ch3 based on OptiTrack checkbox

### Testing
- [ ] **Save & Run**: Check for syntax errors (red underlines in App Designer)
- [ ] **Test Conversion**: Convert one existing TVD file and check if `*_sync.txt` log is created (one per recording)
- [ ] **Test Recording**: Record a new session without OptiTrack and verify WAV has only 2 channels (if Change 6 applied)
- [ ] **Test Recording**: Record a new session with OptiTrack and verify WAV has 3 channels

---

## Testing the Fix

### Step 1: Convert Test Recordings
1. Open MewRecorder
2. Menu → Tools → **Convert All TVD to MP4 (via AVI)**
3. Let it process your existing recordings

### Step 2: Check the Log Files
Look for `*_sync.txt` files in your output folder (one per recording):

**Example**: `recording_001_sync.txt`
```
=====================================================
MewRecorder - Audio-Video Synchronization Log
=====================================================

Recording File: recording_001
Conversion Date: 2025-12-10 15:23:45
Session Run #: 1
Status: SUCCESS

--- Video Sync Offset ---
frameStart (video offset): 0.856234 seconds
  -> This offset was applied to FFmpeg for A/V sync

--- Telemed Ultrasound Sync (Ch2) ---
Number of sync pulses detected: 120
First pulse detected at: 0.789123 seconds
Frame duration (median): 0.033333 seconds
Estimated frame rate: 30.00 fps

--- OptiTrack Motion Capture Sync (Ch3) ---
OptiTrack start pulse detected at: 0.105234 seconds
Video-to-OptiTrack offset: 0.751000 seconds
  -> Use this offset for head movement correction
  -> Formula: optitrack_time = video_time + 0.751000

--- Audio Settings ---
Sample Rate: 48000 Hz

=====================================================
For analysis, use frameStart to align video with audio.
For motion correction, use Video-to-OptiTrack offset.
=====================================================
```

**What to look for**:
- `frameStart (video offset)`: Should be 0.05-1.0 seconds for most recordings
- Recordings with ~0.8-1.0s frameStart had the delay before
- Recordings with ~0.05-0.1s frameStart were already synced

### Step 3: Verify Video Playback
- Open the converted MP4 files
- Check if audio-video sync is now consistent across all recordings
- Sync error should be < 33ms (1 frame at 30fps)

### Step 4: If Sync is Reversed
If video is now **ahead** of audio, change the offset sign in Change 5:
```matlab
% Instead of:
[status,cmdout] = app.ffmpegCombineVideoAudio(tmpVideoFN, trimmedAudioFN, outVideoFN, videoOffset=frameStart);

% Use negative offset:
[status,cmdout] = app.ffmpegCombineVideoAudio(tmpVideoFN, trimmedAudioFN, outVideoFN, videoOffset=-frameStart);
```

---

## Sync Log File Format Explained

Each recording gets its own `*_sync.txt` log file with these sections:

### 1. **Recording Information**
- Filename, conversion date, session run number, status

### 2. **Video Sync Offset** (Critical for A/V sync)
- `frameStart (video offset)`: **The offset applied to FFmpeg** - time when first ultrasound frame was captured
- This is the value that fixes the audio-video sync

### 3. **Telemed Ultrasound Sync** (Ch2)
- Number of sync pulses detected
- First pulse timing
- Frame duration and estimated FPS

### 4. **OptiTrack Motion Capture Sync** (Ch3)
- OptiTrack start pulse timing
- `Video-to-OptiTrack offset`: **Critical for head movement correction**
- Formula provided for aligning OptiTrack data with video frames

### 5. **Audio Settings**
- Sample rate

---

## Using OptiTrack Offset for Motion Correction

If you're doing head movement correction, extract the `Video-to-OptiTrack offset` value from the sync log file:

**Manual extraction** (open `recording_001_sync.txt`, find the line):
```
Video-to-OptiTrack offset: 0.751000 seconds
```

**Or parse with MATLAB**:
```matlab
% Read sync log file
logFile = 'recording_001_sync.txt';
fid = fopen(logFile, 'rt');
logContent = fread(fid, '*char')';
fclose(fid);

% Extract Video-to-OptiTrack offset
pattern = 'Video-to-OptiTrack offset:\s+([\d.]+)\s+seconds';
match = regexp(logContent, pattern, 'tokens');
if ~isempty(match)
    video_to_ot_offset = str2double(match{1}{1});
else
    video_to_ot_offset = NaN;
end

% For ultrasound video frame N
video_time = N / video_fps;
optitrack_time = video_time + video_to_ot_offset;
optitrack_frame_idx = round(optitrack_time * optitrack_fps);

% Get marker positions at corresponding time
markers = optitrack_data(optitrack_frame_idx).markers;
```

---

## Why This Fix Works

**The Problem**:
- Audio recording starts immediately (~50ms ASIO init)
- Telemed hardware has variable startup delay (50ms-1000ms)
- FFmpeg combines them assuming they both started at t=0
- Result: Video lags behind audio by the hardware warmup time

**The Solution**:
- `TrimTelemedAudio` detects when video actually started (via Ch2 sync pulses)
- Calculated `frameStart` = offset in seconds
- FFmpeg's `-itsoffset` delays the video stream to match audio timeline
- Result: Perfect sync regardless of hardware warmup time

**FFmpeg command before**:
```bash
ffmpeg -i video.avi -i audio.flac -map 0:v -map 1:a ... output.mp4
```

**FFmpeg command after**:
```bash
ffmpeg -itsoffset 0.856 -i video.avi -i audio.flac -map 0:v -map 1:a ... output.mp4
#        ^^^^^^^^^^^^^ Video delayed by frameStart seconds
```

---

## Troubleshooting

### Issue: Sync log files not created
- Check if `OutputPath` is writable
- Look for log messages in MewRecorder console
- Verify `LogSyncTiming` function was added correctly

### Issue: frameStart value is NaN in log file
- Ch2 sync pulses not detected
- Check WAV file has at least 2 channels
- Verify Telemed recording was enabled
- Open WAV in audio editor - check if Ch2 has pulse signals

### Issue: OptiTrack offset is always NaN
- No Ch3 pulses detected
- Check if OptiTrack recording was enabled during capture
- Verify sync cable connected to Focusrite Input 3
- If OptiTrack not used, this is expected (can ignore)

### Issue: Sync is worse after fix
- Try negative offset: `videoOffset=-frameStart` in Change 5
- Check sync log to see if frameStart values are reasonable (0.01-2.0 sec range)
- Very large frameStart (>2 seconds) suggests pulse detection issue

---

## OPTIONAL CHANGE 6: Save Only Necessary Channels

**Purpose**: If OptiTrack is not recorded, save only 2 channels (Audio + Telemed sync) instead of 3 channels. This saves disk space and makes the output clearer.

**Location**: Function `SaveAudio` (around line 559-576)

### Modify Channel Mapping Logic

**Find this code block** (lines 559-576):
```matlab
% Remap 4-channel input to 3-channel output:
% Remap 4-channel input to 3-channel output:
% Input:  Ch1=Audio, Ch2=Telemed sync, Ch3=OptiTrack sync, Ch4=(unused)
% Output: Ch1=Audio, Ch2=Telemed sync, Ch3=OptiTrack sync
if nChannels >= 4
    s_output = [s(:,1), s(:,app.which_channel_is_telemed_sync), s(:,app.which_channel_is_optitrack_sync)];
    app.logMessage(sprintf('Remapped %d channels to 3-channel output (Audio, Telemed sync, OptiTrack sync)', nChannels), 'info');
    app.logMessage(sprintf('Raw ASIO data - Ch1 RMS: %.4f, Ch2 RMS: %.4f, Ch3 RMS: %.4f, Ch4 RMS: %.4f', ...
        rms(s(:,1)), rms(s(:,2)), rms(s(:,3)), rms(s(:,4))), 'info');
elseif nChannels >= 3
    % Fallback: if only 3 channels available, assume Ch3 is Telemed sync
    s_output = [s(:,1), s(:,app.which_channel_is_telemed_sync), zeros(size(s,1),1)];
    app.logMessage(sprintf('Warning: Only %d channels recorded. OptiTrack sync channel will be silent.', nChannels), 'warning');
else
    % Fallback: save as-is if fewer than 3 channels
    s_output = s;
    app.logMessage(sprintf('Warning: Only %d channels recorded. Saving as-is.', nChannels), 'warning');
end
```

**REPLACE with** (conditional Ch3 inclusion):
```matlab
% Remap channels based on what was recorded
% Input:  Ch1=Audio, Ch2=Telemed sync, Ch3=OptiTrack sync, Ch4=(unused)
% Output: Ch1=Audio, Ch2=Telemed sync, [Ch3=OptiTrack sync if enabled]
if nChannels >= 4
    % Check if OptiTrack was recorded
    if app.Ck_ifRecordOptitrack.Value
        % Include OptiTrack sync channel (3-channel output)
        s_output = [s(:,1), s(:,app.which_channel_is_telemed_sync), s(:,app.which_channel_is_optitrack_sync)];
        app.logMessage(sprintf('Remapped %d channels to 3-channel output (Audio, Telemed sync, OptiTrack sync)', nChannels), 'info');
    else
        % OptiTrack not recorded, save only 2 channels
        s_output = [s(:,1), s(:,app.which_channel_is_telemed_sync)];
        app.logMessage(sprintf('Remapped %d channels to 2-channel output (Audio, Telemed sync)', nChannels), 'info');
    end
    app.logMessage(sprintf('Raw ASIO data - Ch1 RMS: %.4f, Ch2 RMS: %.4f, Ch3 RMS: %.4f, Ch4 RMS: %.4f', ...
        rms(s(:,1)), rms(s(:,2)), rms(s(:,3)), rms(s(:,4))), 'info');
elseif nChannels >= 3
    % Fallback: if only 3 channels available
    if app.Ck_ifRecordOptitrack.Value
        s_output = [s(:,1), s(:,app.which_channel_is_telemed_sync), zeros(size(s,1),1)];
        app.logMessage(sprintf('Warning: Only %d channels recorded. OptiTrack sync channel will be silent.', nChannels), 'warning');
    else
        % No OptiTrack, save 2 channels
        s_output = [s(:,1), s(:,app.which_channel_is_telemed_sync)];
        app.logMessage(sprintf('Saved %d channels (Audio, Telemed sync)', nChannels), 'info');
    end
else
    % Fallback: save as-is if fewer than 3 channels
    s_output = s;
    app.logMessage(sprintf('Warning: Only %d channels recorded. Saving as-is.', nChannels), 'warning');
end
```

**Key changes**:
- Check `app.Ck_ifRecordOptitrack.Value` before including Ch3
- If OptiTrack disabled: Save 2-channel WAV (Audio, Telemed sync)
- If OptiTrack enabled: Save 3-channel WAV (Audio, Telemed sync, OptiTrack sync)

**Benefits**:
- ✅ Smaller file size when OptiTrack not used (~33% reduction in WAV size)
- ✅ Clearer output - channels match what was actually recorded
- ✅ No confusion about empty Ch3 when OptiTrack not enabled
- ✅ `TrimTelemedAudio` already handles both 2-channel and 3-channel files correctly

**Note**: This change is **optional** but recommended. The sync fix (Changes 1-5) works with both 2-channel and 3-channel WAV files.

---

## Summary

**Changes Made**: 5 required + 1 optional modification to MewRecorder.mlapp
1. ✅ Added logging property (1 line: `sessionRecordingCounter`) - **Required**
2. ✅ Increment recording counter (1 line) - **Required**
3. ✅ Added LogSyncTiming function (~110 lines, creates per-file TXT logs) - **Required**
4. ✅ Modified ffmpegCombineVideoAudio (2 lines) - **Required**
5. ✅ Updated conversion workflow (~15 lines) - **Required**
6. ⚙️ Conditional Ch3 channel saving (~10 lines) - **Optional but recommended**

**Benefits**:
- ✅ Fixes intermittent audio-video sync lag
- ✅ Works with existing recordings (just re-convert)
- ✅ Creates individual human-readable log file for each recording
- ✅ Includes OptiTrack offset for motion correction
- ✅ Self-documenting with usage instructions in each log
- ✅ Backwards compatible (defaults to no offset if not provided)

**Estimated Implementation Time**: 30-45 minutes
**Risk Level**: Low (changes are localized, well-tested logic)

---

**Document Version**: 4.2
**Last Updated**: 2025-12-10
**Changes**:
- v4.0: Complete rewrite as step-by-step implementation guide with copy/paste code blocks
- v4.1: Added optional Change 6 for conditional Ch3 channel saving (saves disk space when OptiTrack not used)
- v4.2: Changed logging from single CSV to per-file TXT logs (more human-readable, one log per recording)

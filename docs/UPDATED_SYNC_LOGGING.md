# Updated Sync Logging Implementation

**Change from CSV to Per-File TXT Logs**

Instead of one `_sync_timing.csv` file for all conversions, this creates individual `_sync.txt` log files for each TVD/audio file.

Example: `recording_001.wav` → `recording_001_sync.txt`

---

## CHANGE 1: Remove syncTimingLogFilename Property

**Location**: Properties section (around line 102)

**FIND**:
```matlab
%% Sync timing logging
sessionRecordingCounter = 0;  % Track recording number for sync logging
syncTimingLogFilename = '_sync_timing.csv';  % Log file for frameStart values
```

**REPLACE WITH**:
```matlab
%% Sync timing logging
sessionRecordingCounter = 0;  % Track recording number for sync logging
```

**Note**: Remove the `syncTimingLogFilename` line completely.

---

## CHANGE 2: Rewrite LogSyncTiming Function

**Location**: Function `LogSyncTiming` (around lines 768-840)

**FIND THE ENTIRE FUNCTION** (from `function LogSyncTiming` to the `end` statement):
```matlab
function LogSyncTiming(app, filename, frameStart, sampleRate, locs, status)
    % Log sync timing data for video-audio alignment verification
    % Includes OptiTrack sync pulse detection from Ch3
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

    % Detect OptiTrack sync pulse (Ch3)
    try
        [wav, sr] = audioread(filename);
        if size(wav, 2) >= 3
            ch3 = abs(wav(:, 3));
            [~, ot_locs] = findpeaks(ch3, sr, 'MinPeakHeight', 0.3, 'NPeaks', 2, 'SortStr', 'descend');
            if ~isempty(ot_locs)
                optitrackStart = min(ot_locs);  % First pulse = recording start
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
        % Fail silently - don't interrupt conversion
    end
end
```

**REPLACE WITH** (creates individual TXT log per file):
```matlab
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

## Example Output

**File**: `recording_001_sync.txt`

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

---

## Benefits of This Approach

✅ **One log per recording** - Easy to find sync data for specific files
✅ **Human-readable TXT format** - No CSV parsing needed
✅ **Self-documenting** - Clear labels explain what each value means
✅ **Includes usage instructions** - Shows how to use the offset values
✅ **Preserves all sync data** - OptiTrack offset, frame rate, pulse count
✅ **Graceful error handling** - Warns if sync pulses not detected

---

## Changes Summary

1. **Remove** `syncTimingLogFilename` property (line 102)
2. **Replace** entire `LogSyncTiming` function (lines 768-840)

That's it! No other changes needed.

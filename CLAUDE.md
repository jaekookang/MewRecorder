# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
When creating docs for updates and fixes, make it under session_logs/ with prefix 'task_*'

**IMPORTANT**: All development history and session notes are saved under `session_logs/` as markdown files. Before starting work, always check:
- `session_logs/SESSION_SUMMARY.md` - Overview of the most recent session
- Session files with date suffixes (e.g., `session_251012.md`) - Detailed development history

## Project Overview

MewRecorder is a MATLAB-based multimodal recording application for synchronized capture of:
- **Ultrasound video** via Telemed EchoWave II
- **Multi-channel audio** (up to 4 channels)
- **3D motion tracking** via OptiTrack NatNet SDK

**Current Version**: v1.3.2 (October 2025)
**Latest Build**: compiled_251019v6
**Latest Checkpoint**: MewRecorder_backup_251020v3 (Verified working - All 16 fixes applied)

## Commands

### Development Commands
```matlab
% Run the application in MATLAB (requires Administrator mode)
>> MewRecorder

% Compile standalone executable (current working version)
mcc -m -W WinMain:MewRecorder -T link:exe 'MewRecorder.mlapp' ...
  -a 'NatNet_SDK_4.3\NatNetSDK\lib\x64\NatNetML.dll' ...
  -a 'NatNet_SDK_4.3\NatNetSDK\lib\x64\NatNetLib.dll' ...
  -a 'NatNet_SDK_4.3\NatNetSDK\lib\x64\NatNetML.xml' ...
  -a 'NatNet_SDK_4.3\NatNet_SDK_3.1\NatNetSDK\Samples\Matlab\natnet.p' ...
  -d 'compiled_YYYYMMDD'
```

### System Requirements
- **Platform**: Windows only (Telemed hardware dependency)
- **MATLAB**: R2022b+ with Audio Toolbox
- **Administrator Mode**: Required for hardware COM automation
- **RAM**: Minimum 16GB (64GB preferred)
- **FFmpeg**: Must be installed in system PATH for video conversion

## Architecture

### Main Application
- **Entry point**: `MewRecorder.mlapp` (MATLAB App Designer file)
- **Backup**: `MewRecorder_backup_*.mlapp`
- **Architecture**: Single monolithic App Designer application with external SDK integration

### Key Integration Points

1. **Telemed EchoWave II**: COM automation via `AutoInt1Client.dll`
   - Requires EchoWave II software running
   - Controls ultrasound recording and cine file generation

2. **MATLAB Audio Toolbox**: Native multi-channel audio recording
   - Supports up to 4 audio channels
   - Built-in normalization and WAV export

3. **OptiTrack NatNet SDK**: 3D motion tracking integration
   - Uses compiled `natnet.p` interface
   - Requires `NatNetML.dll` for .NET assembly access
   - SDK files in `NatNet_SDK_4.3/` directory

4. **FFmpeg**: External process for video/audio combination
   - Converts Telemed .tvd files to MP4
   - Merges ultrasound video with synchronized audio

### Core Workflow Functions

**Initialization** (`startupFcn` → `initialize`):
- `DetectEchoWave()`: Connects to Telemed software
- `selectAudioDevice()`: Configures audio hardware
- `CheckIfAudioDeviceSettingSupported()`: Validates audio settings

**Recording** (`StartRecordButtonPushed` → `Bn_StopPushed`):
- Simultaneous capture across all modalities
- Automatic timestamping and file naming
- Real-time UI updates for recording status

**Conversion** (`ConvertTVDtoVideo`):
- `TrimTelemedAudio()`: Synchronizes audio with ultrasound
- `ffmpegCombineVideoAudio()`: Merges streams into MP4

### File Output Structure
- `.wav`: **3-channel audio** (Ch1: Audio, Ch2: Telemed sync, Ch3: OptiTrack sync)
- `.tvd`: Telemed native ultrasound cine files
- `.mat`: OptiTrack 3D marker trajectories (via NatNet)
- `.mp4`: Combined ultrasound video + synchronized audio
- `_MewRecorder.log`: Session metadata and timestamps

## Key Directories

- `/libraries/`: Compiled SDK interfaces (`natnet.p`, `NatNetML.dll`)
- `/NatNet_SDK_4.3/`: Complete OptiTrack SDK with samples
- `/docs/`: Technical documentation and analysis
- `/compiled_*/`: Standalone application builds
- `/sessions/`: Recording output directory

## Development Setup

### Development Environment
**Remote Lab (Windows)**:
- MATLAB R2022b+, Motive, EchoWave II, Focusrite Control 2
- Hardware: Focusrite 4i4 audio interface, OptiTrack cameras, Telemed ultrasound probe
- Code editing via MATLAB App Designer (`.mlapp` format - cannot edit as text)

**Local Machine (macOS)**:
- Code planning via CursorAI/Claude Code
- Remote access via Parsec (manual copy/paste for code transfer)

### Prerequisites
1. Install Telemed EchoWave II, register `AutoInt1Client.dll` (Admin CMD), allocate 5GB+ RAM
2. Install FFmpeg to system PATH
3. Run MATLAB in **Administrator mode** (required for hardware COM automation)

### Build & Testing
- **Compile**: Use `mcc` command (see Commands section), include all OptiTrack SDK DLLs
- **Testing**: Requires full hardware setup; audio-only testing possible without specialized devices
- **Version Control**: Backup `.mlapp` files, preserve compiled executables in `compiled_YYYYMMDD/`

## Audio Sync Signal Architecture

### Hardware: Focusrite Scarlett 4i4
**4 Input Channels:**
- Ch1: Microphone audio
- Ch2: Telemed/Ultrasound sync (TTL pulses)
- Ch3: OptiTrack sync (TTL pulses)
- Ch4: Unused - no signal connected

**3 Output Channels (WAV):**
- Ch1: Audio (from hardware Ch1)
- Ch2: Telemed sync (from hardware Ch2)
- Ch3: OptiTrack sync (from hardware Ch3)

### Implementation
- **Driver**: ASIO via `audioDeviceReader` (Windows DirectSound and WASAPI limited to 2 channels)
- **Device**: 'Focusrite USB ASIO' (provides full 4-channel access)
- **Sync Processing**: `TrimTelemedAudio()` detects frame timing via `findpeaks()` on Ch2 pulses
- **Code Properties**:
  ```matlab
  num_audio_channels = 4  % Record all 4 hardware channels
  which_channel_is_telemed_sync = 2
  which_channel_is_optitrack_sync = 3  % Changed from 4 to 3 (Oct 20, 2025)
  ```
- **Reference**: See `session_logs/session_251020.md` for complete ASIO implementation details

## Known Issues & Solutions

### ✓ RESOLVED ISSUES

**1. NatNet SDK Path Issues in Standalone Build** (Fixed: 2025-10-14)
- **Problem**: OptiTrack SDK failed to load in compiled executable
- **Solution**: Corrected DLL paths to `NatNet_SDK_4.3\NatNetSDK\lib\x64\` and included both `NatNetML.dll` + `NatNetLib.dll`
- **Note**: Files deploy under `ctfroot\MewRecorder\` in standalone builds

**2. Timer Display Delay on First Run** (Fixed: 2025-10-19)
- **Problem**: Timer visualization lagged 5-7 seconds on initial recording
- **Solution**: Replaced blocking loop with background timer (`UpdateRecordingDisplay()`)
- **Implementation**: See `session_logs/fix_timer_delay.md`

**3. WASAPI Only Exposes 2 Channels** (Fixed: 2025-10-20)
- **Problem**: WASAPI driver only provided 2 channels from Focusrite 4i4
- **Solution**: Switched to ASIO driver ('Focusrite USB ASIO') which provides all 4 channels
- **Implementation**: See `session_logs/session_251020.md` (Issues 1-12)

**4. OptiTrack Sync Wrong Hardware Channel** (Fixed: 2025-10-20)
- **Problem**: OptiTrack hardware pulses connected to Input 3, code expected Input 4
- **Solution**: Changed `which_channel_is_optitrack_sync` from 4 to 3, removed software sync generation
- **Implementation**: See `session_logs/task_fix_optitrack_input3.md` (Issue 13)

**5. App Freezes After OptiTrack Starts** (Fixed: 2025-10-20)
- **Problem**: UI completely frozen during recording, Stop button unresponsive
- **Solution**: Simplified blocking while loop, removed `drawnow` (background timers handle UI)
- **Implementation**: See `session_logs/FIX_timer_and_duration.md` (Issue 14)

**6. Timer Display and Duration Check Broken** (Fixed: 2025-10-20)
- **Problem**: Timer frozen, record-by-duration runs forever, `recordStartTime` never set
- **Solution**: Set `recordStartTime` before starting `recordingTimer`
- **Implementation**: See `session_logs/FIX_timer_and_duration.md` (Issue 15)

### ✅ CURRENT STATUS
**All known issues resolved as of October 20, 2025**
- ✅ Full 4-channel ASIO recording working
- ✅ Timer display updates properly
- ✅ UI stays responsive during recording
- ✅ Stop button works without Ctrl+C
- ✅ Record-by-duration feature works correctly
- ✅ OptiTrack sync captured from correct hardware channel (Input 3)
- ✅ All sync signals (Telemed Ch2, OptiTrack Ch3) recording correctly
- ✅ 3-channel WAV output format verified
- ✅ Multiple recording sessions work without restart
- ✅ No crashes, freezes, or errors

**Verified with full hardware setup**: Focusrite 4i4, Telemed EchoWave II, OptiTrack motion capture

### Development Workflow Constraints
- **Remote Development**: Code changes must be manually transferred via Parsec remote desktop
- **Hardware Dependencies**: Full testing requires physical lab setup with specialized hardware
- **Platform Limitation**: Development and deployment restricted to Windows due to hardware dependencies

## Future Enhancements

### Completed Improvements ✅
- [x] **4-channel ASIO recording** (Oct 20, 2025)
  - ✅ All audio lamps work (Ch1, Ch2, Ch3)
  - ✅ Sync pulse detection validated in Ch2 and Ch3
  - ✅ 3-channel WAV output format confirmed

- [x] **OptiTrack sync recording** (Oct 20, 2025)
  - ✅ OptiTrack sync pulses recorded from hardware Ch3
  - ✅ Saved to WAV Ch3 for post-processing
  - ✅ Hardware TTL pulses (passive reception, no software generation needed)

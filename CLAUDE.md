# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MewRecorder is a MATLAB-based multimodal recording application for synchronized capture of:
- **Ultrasound video** via Telemed EchoWave II
- **Multi-channel audio** (up to 4 channels)
- **3D motion tracking** via OptiTrack NatNet SDK

Current version: v1.3.2-dev (January 2025)
**In Progress:** 4-channel WASAPI recording with 3-channel sync output

## Commands

### Development Commands
```matlab
% Run the application in MATLAB (requires Administrator mode)
>> MewRecorder

% Compile standalone executable
mcc -m -W WinMain:MewRecorder -T link:exe 'MewRecorder.mlapp' ...
   -a 'libraries/natnet.p' ...
   -a 'libraries/NatNetML.dll' ...
   -a 'libraries/' ...
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

### Current Development Environment
**Remote Development Setup**:
- **Remote lab computer (Windows OS)**:
  - MATLAB, Motive, EchoWave II, and Focusrite Control 2 installed
  - MewRecorder running (`MewRecorder.mlapp`)
  - Hardware devices connected via Focusrite interface (Ultrasound, OptiTrack, Audio)
  - Sync signal handling through Focusrite, with direct data cable connections

- **Local development machine (macOS)**:
  - CursorAI and Claude Code for planning and coding
  - Code transfer via manual copy/paste through Parsec remote desktop client

### Prerequisites for Development
1. Install Telemed EchoWave II software
2. Register `AutoInt1Client.dll` (requires Admin CMD)
3. Configure EchoWave RAM allocation (minimum 5GB)
4. Install FFmpeg in system PATH
5. Run MATLAB in Administrator mode

### Code Editing
- Main code is in `MewRecorder.mlapp` (App Designer format)
- Cannot be edited as plain text - requires MATLAB App Designer
- All GUI components and callbacks are contained within this single file

### Build Process
- Uses MATLAB Compiler (`mcc`) to create standalone executable
- Must include OptiTrack SDK libraries in compilation
- Output directory follows `compiled_YYYYMMDD` naming convention

### Testing
- Requires hardware connections for full testing
- EchoWave II software must be running for ultrasound features
- OptiTrack Motive software required for motion tracking
- Audio device testing can be done without specialized hardware

### Version Control
- Backup files maintained for major versions (`*_backup_*.mlapp`)
- Compiled executables preserved for distribution
- Clean separation between source and build artifacts via `.gitignore`

## Audio Sync Signal Architecture (NEW - January 2025)

### Hardware Setup
**Focusrite Scarlett 4i4** captures 4 input channels:
- **Channel 1**: Microphone audio
- **Channel 2**: Telemed/Ultrasound sync signal (hardware-generated pulse)
- **Channel 3**: (unused)
- **Channel 4**: OptiTrack sync signal (hardware-generated pulse)

### Recording Configuration
- **Input**: 4 channels via WASAPI driver (Windows DirectSound limited to 2 channels)
- **Output**: 3 channels saved to WAV file
  - Ch1: Audio (from hardware Ch1)
  - Ch2: Telemed sync (from hardware Ch2)
  - Ch3: OptiTrack sync (from hardware Ch4)

### Sync Signal Processing
- **Hardware sync generation**: Telemed and OptiTrack devices send TTL pulses to Focusrite inputs
- **Recording**: All 4 channels captured via `audioDeviceReader` (WASAPI)
- **Post-processing**: `TrimTelemedAudio()` analyzes Ch2 sync pulses via `findpeaks()` to detect frame timing
- **Future**: OptiTrack sync processing can be added similarly using Ch3

### Key Properties
```matlab
num_audio_channels = 4  % Record all 4 hardware channels
which_channel_is_telemed_sync = 2    % Hardware input channel
which_channel_is_optitrack_sync = 4  % Hardware input channel
```

### Implementation Files
- `updates.md`: Initial 3-channel format changes
- `updates_wasapi.md`: WASAPI driver enablement for 4-channel capture

## Known Issues

### NatNet SDK Path Issues in Standalone Build ✓ RESOLVED
- **Problem**: OptiTrack NatNet SDK works correctly when running in MATLAB but fails to find DLL and related files when built as standalone executable
- **Root Cause**: Path resolution issues for `NatNetML.dll` and deployment directory structure mismatch
- **Solution**:
  1. Use correct SDK path: `NatNet_SDK_4.3\NatNetSDK\lib\x64\NatNetML.dll` (not `Samples\bin\x64\`)
  2. Account for deployment structure: `ctfroot\MewRecorder\` subfolder in standalone builds
  3. Include required files in compilation: both `NatNetML.dll` and `NatNetML.xml`
  4. Unblock downloaded DLL files to resolve security restrictions
- **Implementation**: Updated `getNatNetDLLPath()` function to handle deployment vs development paths

### Current Build Configuration
- **Compilation Command**:
  ```matlab
  mcc -m -W WinMain:MewRecorder -T link:exe 'MewRecorder.mlapp' ...
    -a 'NatNet_SDK_4.3\NatNetSDK\lib\x64\NatNetML.dll' ...
    -a 'NatNet_SDK_4.3\NatNetSDK\lib\x64\NatNetML.xml' ...
    -a 'NatNet_SDK_4.3\NatNet_SDK_3.1\NatNetSDK\Samples\Matlab\natnet.p' ...
    -d 'compiled_YYYYMMDD'
  ```
- **Deployment Structure**: Files placed under `ctfroot\MewRecorder\` in standalone builds
- **Path Resolution**: Use `fullfile(ctfroot, 'MewRecorder', relDLL)` for deployed applications

### Development Workflow Constraints
- **Remote Development**: Code changes must be manually transferred via Parsec remote desktop
- **Hardware Dependencies**: Full testing requires physical lab setup with specialized hardware
- **Platform Limitation**: Development and deployment restricted to Windows due to hardware dependencies

## Current TODO (January 2025)

### 🔴 HIGH PRIORITY - In Progress
- [ ] **Apply WASAPI changes from `updates_wasapi.md`**
  - Currently: Code written but not yet applied to MewRecorder.mlapp
  - Reason: Enables true 4-channel recording from Focusrite 4i4
  - Expected result: "Recording via WASAPI (4 ch)." message on recording start
  - Files: See `updates_wasapi.md` for complete change list

### 🟡 MEDIUM PRIORITY - Testing
- [ ] **Test 4-channel WASAPI recording**
  - Verify all 4 audio lamps light up (Ch1, Ch2, Ch4)
  - Check saved WAV files have exactly 3 channels
  - Validate Telemed sync (Ch2) contains pulses
  - Validate OptiTrack sync (Ch3) contains pulses
  - Run `audioread()` to inspect channel data

- [ ] **Test TrimTelemedAudio with new format**
  - Confirm sync pulse detection works with Ch2
  - Check frame timing calculation accuracy
  - Verify trimmed audio aligns with ultrasound video

- [ ] **Test video conversion pipeline**
  - Record sample with all modalities enabled
  - Run "Convert TVD to Video" function
  - Confirm MP4 output has synchronized audio

### 🟢 LOW PRIORITY - Future Enhancements
- [ ] **Add OptiTrack sync processing function**
  - Create `TrimOptiTrackData()` similar to `TrimTelemedAudio()`
  - Use Ch3 sync pulses to timestamp OptiTrack marker data
  - Align OptiTrack .mat file with ultrasound video timing

- [ ] **Add sync signal visualization**
  - Real-time waveform display during recording
  - Show pulse detection in GUI
  - Help debug sync signal issues

- [ ] **Document WASAPI fallback behavior**
  - What happens if WASAPI fails?
  - How to troubleshoot driver issues?
  - Alternative configurations for different audio interfaces

### ⚠️ Known Limitations
- **Windows DirectSound**: Only exposes 2 channels from Focusrite 4i4
- **WASAPI Requirement**: Needs Audio Toolbox license
- **Audio Device Name**: Must be set correctly for WASAPI to work
- **Channel 3 Empty**: Hardware input Ch3 has no signal (intentional)
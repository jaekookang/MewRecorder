# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MewRecorder is a MATLAB-based multimodal recording application for synchronized capture of:
- **Ultrasound video** via Telemed EchoWave II
- **Multi-channel audio** (up to 4 channels)
- **3D motion tracking** via OptiTrack NatNet SDK

Current version: v1.3.1 (October 2025)

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
- `.wav`: Normalized multi-channel audio
- `.tvd`: Telemed native ultrasound cine files
- `.csv/.mat`: OptiTrack 3D marker trajectories (planned)
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
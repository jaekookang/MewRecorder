# MewRecorder: Simplified Code Structure and Logic Summary (with OptiTrack)

## Overview
**MewRecorder.mlapp** is a MATLAB App Designer GUI for synchronized **ultrasound (Telemed EchoWave II)**, **audio**, and now **OptiTrack motion tracking** recording. It captures and synchronizes multimodal data, then optionally converts ultrasound `.tvd` files into combined `.mp4` video using **FFmpeg**.

---

## Main Functions

### 1. Initialization (`startupFcn` → `initialize`)
- Sets up UI and verifies MATLAB version.
- Detects and connects to EchoWave II (Telemed ultrasound).
- Initializes audio device.
- Checks FFMPEG installation.
- Prepares optional OptiTrack recording control (if enabled).
- Sets app status: `inactive`, `ready`, or `busy`.

**Key calls:**
- `DetectEchoWave()` → Connect to EchoWave.
- `selectAudioDevice()` → Configure audio input.
- `CheckIfAudioDeviceSettingSupported()` → Validate sampling rate and channel count.

---

### 2. Recording Workflow

#### (a) Start Recording (`StartRecordButtonPushed`)
1. Checks for active EchoWave and probe (if ultrasound selected).
2. Enables optional **OptiTrack recording** (future logic can start a NatNet or Motive stream here).
3. Sets state to `busy` and generates timestamped filename via `GenFilename()`.
4. Starts **audio recorder** using `audiorecorder`.
5. Starts **Telemed recording** using EchoWave commands.
6. Continuously updates UI (record duration, lamp signals) until:
   - Stop pressed, OR
   - Duration/timeout reached.

#### (b) Stop Recording (`Bn_StopPushed`)
- Stops audio, EchoWave, and (if applicable) OptiTrack recording.
- Saves `.wav` (normalized audio), `.tvd` (ultrasound cine), and optionally OptiTrack data file.
- Updates `_MewRecorder.log` with timestamps, filename, and annotation.

---

### 3. Data Conversion
**Menu → Tools → Convert TVD to MP4 (via AVI)**

- Converts all recorded `.tvd` ultrasound files using EchoWave CLI.
- Extracts synchronized audio from `.wav` via sync pulses.
- Merges audio and video with FFmpeg if installed.

**Core functions:**
- `ConvertTVDtoVideo()` → Convert `.tvd` to AVI/MP4.
- `TrimTelemedAudio()` → Aligns Telemed sync channel.
- `ffmpegCombineVideoAudio()` → Combines audio/video.

---

### 4. OptiTrack Integration
**New Component:** `Ck_ifRecordOptitrack` (checkbox)

- Enables or disables OptiTrack motion tracking recording.
- Intended to synchronize with audio and ultrasound capture.
- Future versions may call external MATLAB or Python scripts to record via **NatNet SDK** or **Motive API**.
- Placeholder hook exists in the recording logic to extend later.

---

### 5. Utility Functions
| Function | Description |
|-----------|-------------|
| `appSetStatus` | Updates GUI state. |
| `do_log` | Appends session info (filename, times, notes). |
| `CheckOutputFolderAccess` | Validates output folder permissions. |
| `FindTelemedEchoWavePath` | Locates EchoWave installation. |
| `hasFFmpegInstalled` | Checks if FFmpeg is in PATH. |
| `NextAvailableFileName` | Avoids overwriting files. |

---

### 6. Key UI Components
| Element | Purpose |
|----------|----------|
| **Record Telemed Ultrasound** | Enable ultrasound video acquisition. |
| **Record OptiTrack** | Enable OptiTrack 3D motion tracking (new). |
| **Normalize Audio** | Normalize waveform before saving. |
| **Start / Stop Buttons** | Begin and end multimodal recording. |
| **Audio Lamps (1–4)** | Show per-channel audio activity. |
| **Filename Controls** | Auto-generate timestamped filenames. |
| **Tools / Info Menus** | Conversion, preset loading, and info display. |

---

## File Outputs
| Type | Extension | Description |
|------|------------|-------------|
| Audio | `.wav` | Normalized audio signal. |
| Ultrasound | `.tvd` | Telemed cine file. |
| OptiTrack | `.csv` / `.mat` *(planned)* | 3D marker trajectories. |
| Log | `_MewRecorder.log` | Session metadata. |
| Video | `.mp4` | Combined ultrasound + audio. |

---

## Dependencies
- MATLAB R2022b or newer.
- Windows (Admin mode recommended).
- **Telemed EchoWave II** with `AutoInt1Client.dll`.
- **FFmpeg** installed in system PATH.
- **OptiTrack NatNet SDK** *(for future full integration).*  

---

## Simplified Workflow
```text
Start App → Initialize (Audio, EchoWave, OptiTrack)
        ↓
Press "Record" → Start audio, ultrasound, (and OptiTrack)
        ↓
Stop/AutoStop → Save .wav, .tvd, .csv/.mat
        ↓
Convert → Merge to MP4 (optional)
        ↓
Log saved in _MewRecorder.log
```

---

## Notes
- The OptiTrack checkbox adds multimodal flexibility for 3D motion + ultrasound research.
- Sync can be managed by time alignment or external trigger channels.
- The GUI design remains modular for easy future integration of new sensors.


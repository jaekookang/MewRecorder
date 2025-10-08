# Procedure to compile as a standalone exe file

- `mcc -m -W WinMain:MewRecorder -T link:exe MewRecorder.mlapp`

## Option Meaning
- `-m`	Create a standalone application (main function type).
- `-W WinMain:MewRecorder`	Builds a Windows GUI executable (no command window). The app name will be MewRecorder.exe.
- `-T link:exe`	Links the output as a Windows executable.
- `MewRecorder.mlapp`	The main App Designer file (entry point).
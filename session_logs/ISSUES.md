# Issues


## Current dev setup
- The current development set up is as follows:
    - (1) Remote lab computer (windows os)
        - Matlab, Motiv, EchoWave and Focusrite Control 2 are installed
        - MewRecorder is running (MewRecorder.mlapp)
        - Data collection devices are connected via Focusrite (Ultrasound, OptiTrack, Audio) where sync signal is handled. Data cable is also connected with computer directly
    - (2) Local macbook (macOS)
        - Using CursorAI and Claude Code to plan and code
        - I have to copy and past the code manually via Parsec client program that is connecting me to the remote lab computer

- MewRecorder
    - It is a Matlab-based GUI program
    - Main file is MewRecorder.mlapp
    - The source code is copied as MewRercorder.txt file (for record)
    - When in 'deployed mode' the ctfroot becomes "C:\Users\Boram Kim\AppData\Local\MathWorks\MatlabRuntimeCache\R2025b\MewRec13"

## Issues
- NatNet SDK is used to control OptiTrack, but the path for dll and relevant files are troubling when built standalone
    - When run on Matlab, MewRecorder is working fine
    - When built and run as standalone, MewRecorder doesn't seem to find the path correctly.

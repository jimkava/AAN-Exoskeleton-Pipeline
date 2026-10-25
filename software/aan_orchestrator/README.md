# AAN Research Orchestrator (P3 foundation)

A local-first, phone-friendly browser app for organizing pseudonymized gait sessions and coordinating the P3 toolchain from the research PC.

## Run on the research PC

1. Install Python 3.10 or newer.
2. Copy `settings.example.json` to `settings.json` and set local paths. Do not put database passwords or service-role keys in this file.
3. On Windows, run `run_windows.bat`. On other systems:
   ```sh
   python -m venv .venv
   .venv/bin/pip install -r requirements.txt
   .venv/bin/uvicorn app:app --host 127.0.0.1 --port 8765
   ```
4. Open http://127.0.0.1:8765.

The server binds to loopback by default. This first version is for use in the PC's browser. The page is responsive, but phone-to-PC access over Wi-Fi needs an authenticated pairing mode before it should be enabled for participant data.

## Current workflow support

- Record a pseudonymous participant code, anthropometry, knee-extensor dynamometry and the P2 `beta = 1 - T_right/T_left` input. The app stores the raw input and does not clamp beta to the P2 range.
- Upload one synchronized video per camera, containing the static pose followed by gait, to match the measurement protocol. Files stay on the PC in `local_data/<session-id>/`.
- Upload a reviewed `Config.toml` and per-camera intrinsics/extrinsics calibration assets for the Pose2Sim run.
- Launch Pose2Sim when the session has videos, calibration assets, a reviewed `Config.toml`, and the Python environment is configured.
- Launch the existing `p2s_gait2392.py` Scale+IK step from the session's `_LSTM.trc`; the static interval is selected from that same synchronized recording.
- Track what still needs research/code integration: participant-specific MocoTrack, a P3 MATLAB entry point, cloud motor selection handoff, and section 14 target-joint selection.

The app deliberately refuses to run the P2 MATLAB scripts against the new session yet. Those scripts use fixed subject01 / fixed weakness scenarios. Calling them now could create a motor result that looks participant-specific when it is not.

## Data and security

- Session files and the SQLite database stay in the local data folder; video is not sent to Supabase.
- Use study codes only. Do not enter names, addresses or other direct identifiers.
- For participant recordings, follow the approved ethics protocol and consent process.
- The app has no login in this research prototype. Keep it on loopback; do not expose it to a network with participant data.

## Next integration milestone

1. Generate and validate Pose2Sim configuration from the uploaded calibration/video layout.
2. Add the MocoTrack contact-sphere workflow and validate GRFs against the existing subject01 measured trial.
3. Refactor the MATLAB workflow to accept the new scaled model, IK, MocoTrack outputs, measured beta and target joint from a session manifest.
4. Generalize motor selection to the identified joint and read candidate motors from Supabase through the existing MATLAB connection.

# Agent Context: Logging & Monitoring (Offline)

## Architecture

- **Package**: `logging` (Dart standard) + `talker_flutter` (for on-screen console).
- **Sinks**:
  1.  **Console**: Development only.
  2.  **File**: `app_logs.txt` (Circular buffer, max 5MB). Useful for analysing crashes on user devices (if they send the file manually).
  3.  **Screen**: `TalkerScreen` for runtime debugging without ADB attached.

## Structure

- Log entries must be structured: `[Subsystem] [Action] {metadata}`.
- Example: `[WORLD] [CHUNK_LOAD] {x: 10, y: 5, duration: 12ms}`.

## Severity Levels

- `SHOUT`: App crash imminent.
- `SEVERE`: Feature failure (Sound engine died), gameplay continues.
- `WARNING`: Performance degradation (FPS < 30), Asset missing.
- `INFO`: State changes (Level Start, Mode Switch).
- `FINE`: Detailed logic (A\* node calculation) - OFF by default in efficient builds.

## Performance

- Logging must be **asynchronous**. Writing to the file sink must not block the Game Loop.
- Logs in `update()` loops are forbidden unless the debug flag `trace_physics` is active.

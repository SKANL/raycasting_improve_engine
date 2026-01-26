# Agent Context: Error Handling & Logging

## Philosophy

- **Game Loops Don't Crash**: An error in a single entity update should not crash the entire app. Catch exceptions in component `update()` and log them, optionally removing the buggy entity.
- **Fail Gracefully**: If map generation fails, fallback to a safety "void" map or specific error screen, do not leave the user in a black screen.

## Logging Strategy

- **Use `Logger`**: Never use `print()`.
- **Levels**:
  - `severe`: Critical failures (load failed, crash).
  - `warning`: Recoverable issues (sound missing, texture 404).
  - `info`: Key lifecycle events (level start, persistence saved).
  - `fine`: Debugging verbose data (raycast hits).

## Error Boundary

- Wrap the main `GameWidget` in a Flutter `ErrorBoundary` (custom widget) to catch and display UI crashes nicely.

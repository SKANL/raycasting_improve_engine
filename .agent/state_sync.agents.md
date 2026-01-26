# Agent Context: Game Loop & State Synchronization

## The "Who Drives?" Problem

Flame has a `update(dt)` loop. Bloc has an Event-driven stream. Mixing them is complex.

## The Hybrid Loop Strategy

1.  **Driver**: Flame's `update(dt)` is the Master Clock.
2.  **Input**: Flame receives raw input -> Converts to Event -> Adds to `Bloc`.
3.  **State Logic**: `WorldBloc` processes event -> Emits `NewState`.
4.  **Reaction**:
    - Flame `WorldComponent` listens to `NewState`.
    - **Interpolation**: Since Bloc is not 60Hz, Flame _must_ interpolate positions between the "Last Known State" and "Current State" for smooth rendering.
    - _Correction_: If the Bloc state says "Player at (10,10)" but visual is at (9.8, 10), we LERP towards (10,10).

## Anti-Pattern Warning

- **NEVER** `await` a Bloc state inside `update(dt)`. Frame drop is guaranteed.
- **NEVER** put physics logic inside the `CustomPainter` or Shader. Physics happens in the Bloc (or a dedicated Physics isolate if needed, though likely overkill).

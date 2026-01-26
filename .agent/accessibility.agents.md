# Agent Context: Accessibility (A11y)

## Professional Standard

A game engine is not professional if it excludes players.

## Visual Aids

- **High Contrast Mode**: Shader uniform flag `u_high_contrast`. Changes texture generation to use distinct black/white patterns instead of subtle noisy colors.
- **UI Scaling**: All HUD text must respond to system text scale factor (or a custom slider).

## Input Accessibility

- **Remapping**: All actions (Move, Fire, Perspective) must be remappable. `InputBloc` must support a dynamic `KeyMap`.
- **One-Handed Mode**: Portrait mode support (optional but recommended for mobile) or moving all UI controls to one side.

## Cognitive Aids

- **Slow Mode**: Option to reduce game speed (`timeDilation`) to 0.8x or 0.5x for players with slower reaction times.
- **Objective Markers**: Always visible AR-style indicators in 3D view (no getting lost).

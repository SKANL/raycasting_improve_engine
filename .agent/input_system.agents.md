# Agent Context: Input System

## Abstraction Layer

- **ActionMapper**: Converts raw inputs (Keys, Touches, Gamepad) into semantic `GameActions` (e.g., `MoveForward`, `Interact`, `ToggleView`).
- **Input Blocs**: `InputBloc` listens to hardware events and emits `GameActions` to the `PlayerBloc`.

## Schemes per Platform

- **Mobile**:
  - Virtual Joystick (Left) -> Movement.
  - Invisible Touch Area (Right) -> Camera Pan.
  - Floating Action Button -> Interaction/Jump.
- **Desktop/Web**:
  - WASD / Arrows -> Movement.
  - Mouse Delta -> Camera Pan (Pointer Lock required for 3D).
  - Space -> Jump.
  - E -> Interact.

## View-Independant Inputs

- The `ToggleView` action (e.g., 'Tab' key or specific UI button) is always global and high-priority.

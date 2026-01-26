# Agent Context: Rendering & Perspectives

## Multi-View Specifications

1. **2D Overview**: Top-down view (Cenital). Used for tactical planning and navigation.
2. **3D Raycast**: First-person view. Used for immersion and interaction.
3. **2.5D Isometric**: Angle view. Used for platforming and vertical puzzle resolution.

## Perspective State

- Managed by a `PerspectiveBloc`.
- Switching between views triggers an **Interpolated Camera Motion**.
- Camera parameters:
  - View 2D: `fov: 0` (ortho), `angle: 90`, `distance: top`.
  - View 3D: `fov: 60-90`, `angle: eye-level`, `distance: 0`.
  - View Iso: `fov: 30`, `angle: 45`, `rotation: 45`.

## Mechanics per Perspective

- **Transitions**: Changing perspective must be functional (e.g., certain clues only visible in 3D, certain paths only traversable in 3D).
- **Synchronization**: All views render off the same `WorldState` Bloc.

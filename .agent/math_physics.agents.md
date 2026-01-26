# Agent Context: Math & Physics

## Coordinate Systems

- **World Space**: 2D Grid `(x, y)`. `0,0` is Top-Left. `+x` is Right. `+y` is Down.
  - _Note_: This matches Flutter's Canvas coordinates, simplifying debugging.
- **3D Camera Space**:
  - `x`: Stays World `x`.
  - `z`: Becomes World `y` (Depth).
  - `y`: Vertical axis (Height).
- **Angles**: Radians. `0` is East (`+x`). `PI/2` is South (`+y`).

## Formulas

- **Raycasting**:
  - `perpWallDist = (sideDist - deltaDist)` (Standard DDA).
  - `lineHeight = (h / perpWallDist)`.
- **Isometric Projection**:
  - `isoX = (x - y) * cos(30)`.
  - `isoY = (x + y) * sin(30) - z`.

## Unified Physics Simulation

- **Master Simulation**: Physics runs on the 2D Grid (x,y) + Height (z).
- **Consistent State**: If a player falls into a pit in Iso, their state updates to `falling`. If they switch to 3D mid-fall, they see the fall continue (or the "Game Over" screen if deep).
- **Collisions**:
  - **2D/3D Shared**: AABB vs Grid Walls. The wall is solid in both.
  - **Vertical (Iso)**: Gravity applies. Raycasting view "fakes" the ground plane, but logically the Z position exists. If Z < Floor, player falls.
- **Projectiles**: Calculations for trajectory `(dx, dy, dz)` are global. A bullet fired in 3D travels through the implementation-agnostic world and hits an enemy visible in 2D.

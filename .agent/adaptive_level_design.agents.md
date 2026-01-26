# Agent Context: Adaptive Level Design

## Core Concept

The level is **ONE data structure**, but interpreted differently by each perspective to force gameplay variety.

## Perspective Mechanics

### 1. 2D Top-Down (The Tactician)

- **Reveals**: Hidden switches, secret room layouts, enemy patrol paths.
- **Obscures**: Pitfalls (look like floors), ceiling traps.
- **Gameplay**: Logic puzzles, planning routes.

### 2. 3D Raycasting (The Warrior)

- **Reveals**: Wall details (cracks, writing), vertical nuance (eye-level levers), atmosphere.
- **Obscures**: What's behind the wall, the overall maze layout.
- **Gameplay**: Combat, twitch reactions, searching surfaces.

### 3. Mesh/Isometric (The Acrobat)

- **Reveals**: Height differences, platforming routes, stacked crates/bridges.
- **Obscures**: Detailed wall textures (low res/small), specific enemy facings.
- **Gameplay**: Jumping puzzles, using verticality to bypass blocked ground paths.

## Design Rules

- **Multi-Pathing**: A door blocked in 3D might be jumpable in Iso. A pit impassable in Iso might have a hidden bridge visible only in 2D radar.
- **Forced Switching**: The player MUST switch perspectives to progress. It's not optional.

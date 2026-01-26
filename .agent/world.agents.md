# Agent Context: World Logic & Procedural Generation

## Data Structure

- **Master Matrix**: A 2D/3D array of `Cell` objects.
- **Cell Definition**:
  - `type`: Air, Wall, Door, Secret, etc.
  - `height`: For Isometric verticality.
  - `id`: Index for procedural texture mapping.

## Algorithms

- **BSP (Binary Space Partitioning)**: Used for high-level dungeon/building structural layout (rooms and corridors).
- **WFC (Wave Function Collapse)**: Used for micro-detailing (decorations, logical placements) within the BSP-generated rooms.
- **Fast Noise**: Use `fast_noise` for organic terrain variation and biomes.

## Constraints

- **Seed Persistence**: Every level must be recreatable from a single `Seed` (integer).
- **Navigation Safety**: Always ensure a clear path exists between start and goal points using A\* or flood-fill verification.

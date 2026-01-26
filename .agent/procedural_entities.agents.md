# Agent Context: Procedural Entities (Code Only)

## No Static Assets

- **Strict Rule**: No `.png`, `.jpg`, `.wav` files imported for entities.
- **Generation**: Vectors, Particles, and Shaders.

## Visual Implementation

### Enemies & NPCs

- **Style**: Vectorized abstract or Retro-Pixel (generated at runtime).
- **Technique**:
  - **Canvas API**: `CustomPainter` drawing shapes for 2D/Iso.
  - **Billboards**: In 3D Raycasting, entities are flat sprites always facing the camera. We generate these sprites into a texture buffer at startup.
  - **Procedural Parts**: An enemy is composed of "Head + Body + Weapon" parts chosen by code.

### Particles

- **Blood/Explosions**: Mathematical particle systems (position, velocity, decay).
- **Rendering**: Instanced drawing in shaders for performance.

## Behavior

- **State Machine**: Idle -> Chase -> Attack -> Flee.
- **Perspective Awareness**: Enemies might camouflage in one view (e.g., look like a rock in Iso) but reveal as monsters in 3D.

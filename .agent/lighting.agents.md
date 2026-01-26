# Agent Context: Dynamic Lighting System

## Shader Implementation

- **Light Sources**: Point lights (torches, projectiles) and Directional lights (sun/moon).
- **Raycasting Interaction**:
  - **Wall Shading**: Diminish brightness based on `perpWallDist` (Inverse Square Law).
  - **Normal Mapping**: Procedural textures must generate "fake" normals to interact with light direction, creating depth.
  - **Shadows**: Raycasting naturally handles occlusion. Entities must cast blob shadows or projected shadows.

## Dynamic Effects

- **Flicker**: Light intensity must oscillate using `sin(time)` to simulate fire/torches.
- **Color Blending**: Support colored lights (RGB add/multiply) in the Fragment Shader.
- **Fog**: Distance fog to hide the "end of the world" or render distance limits.

## Optimization

- **Light Maps**: For static lights, bake values into the `GameMap` matrix during generation (e.g., cell `[10,10]` has lightness `0.8`).
- **Dynamic Entities**: Only calculate active lights near the player.

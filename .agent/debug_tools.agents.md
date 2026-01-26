# Agent Context: Debug Tools

## Visualization Needs

Procedural generation is a black box. We need X-Ray vision to debug it.

## Required Tools

1.  **Texture Inspector**: A hidden debug screen that displays the generated "Map Texture" and "Sprite Atlas" raw images.
2.  **Pathfinding Overlay**: In 2D view, draw lines showing the A\* path of every enemy.
3.  **Ray Gizmos**: In 2D view, draw the "Field of View" cone of the player to verify Raycasting logic matches gameplay.
4.  **FPS & Memory HUD**: Permanent overlay in debug mode.

## Logger Channels

- Filter logs by channel: `[PHYSICS]`, `[AI]`, `[GEN]`.
- Ability to mute specific channels at runtime.

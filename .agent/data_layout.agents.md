# Agent Context: Data Data Layout & Shader Packing

## The Critical Problem

Passing a 1024x1024 map to a shader via Uniform Arrays is impossible (too much data, slow). We MUST use Textures.

## Map Data Texture Strategy

We encode the `GameMap` into a `ui.Image` (RGBA 8888) to be read by the shader.

- **Size**: `N x N` pixels (where N is map width).
- **Pixel Encoding**:
  - **R (Red)**: Wall ID / Type (0 = Air, 1-255 = Wall Types).
  - **G (Green)**: Floor Height / Ceiling Height (Packed: 4 bits each?).
  - **B (Blue)**: Meta (Breakable status, Door state 0.0-1.0).
  - **A (Alpha)**: Lighting / Fog / Visited state.

## Dynamic Updates

- **Partial Updates**: When a door opens, we do NOT regenerate the whole texture. We use `Canvas.drawRect` on the `PictureRecorder` to update just that pixel (1x1 rect) and upload the new texture.

## Sprite/Entity Atlas

- Entities are not 3D models. They are sprites in a simplified "Billboarding" style.
- **Atlas**: All procedural enemy parts are drawn into a _single_ 2048x2048 texture atlas at startup.
- **Lookup**: The shader receives `uv_rects` (uniform array) telling it where "Enemy_Type_1" lives in the atlas.

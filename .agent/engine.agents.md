# Agent Context: Raycasting Engine & Shaders

## Goal

A custom 3D simulation engine using Raycasting, optimized for 60+ FPS on Flutter.

## Core Techniques

- **Algorithm**: DDA (Digital Differential Analyzer). Researched and confirmed as superior to Raymarching for grid-based worlds due to exact integer stepping and O(N) complexity.
- **Renderer**: Fragment Shaders (GLSL) via `flutter_shaders`.
- **Pipeline**:
  1.  **Init**: Generate procedural textures (bricks, stone) into a static Texture Atlas using helper shaders.
  2.  **Frame**: Pass `GameMap` + Texture Atlas + Camera to Main Shader.
  3.  **Draw**: DDA runs per-pixel, reading from the Atlas.

## Performance Strategies

- **Texture Caching**: DO NOT generate static wall noise per-pixel every frame. Generate once -> Cache -> Sample.
- **Branchless GLSL**: Use `step()`, `mix()`, and `fract()` instead of `if/else` for texture patterns.

## Shader Requirements

- Must support dynamic FOV (Field of View).
- Must handle transparency/glass via multiple ray hits if needed (advanced phase).

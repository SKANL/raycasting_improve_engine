# Raycasting Engine: AI Minigame Development Guide

This guide serves as the technical context for an AI Agent to develop minigames using this custom Raycasting Engine built with Flutter and Flame.

## 1. Engine Core Architecture

The game uses a **Hybrid Raycasting Engine**:

- **FlameGame**: Managing the lifecycle, input, and component tree.
- **Custom Shader**: The heavy lifting of 3D rendering (raycasting, textures, lighting) is done in a fragment shader (`shaders/raycaster.frag`).
- **RaycastRenderer**: A Flame component that listens to the `WorldBloc` and sends data (map, textures, entity positions) to the shader every frame.

### Key Classes

- `RaycastingGame`: Main entry point (loads shaders, initializes Blocs).
- `RaycastRenderer`: The bridge between Game Logic and GPU.
- `ShaderManager`: Handles shader loading and uniforms.

## 2. State Management (Blocs)

The engine follows a strict BLoC architecture for state synchronization:

| Bloc              | Responsibility                                                               |
| :---------------- | :--------------------------------------------------------------------------- |
| `WorldBloc`       | **System Source of Truth**. Simulates the world, entities, physics, and map. |
| `GameBloc`        | High-level game state (Score, Progress, Health, Global Status).              |
| `InputBloc`       | Maps raw keyboard/touch input to `GameAction`.                               |
| `WeaponBloc`      | Manages weapon selection, ammo, and cooldowns.                               |
| `PerspectiveBloc` | Toggles between Raycasting (3D) and Top-down (2D) views.                     |

## 3. ECS (Entity-Component System)

Entities in the world are not Flame Components; they are pure data objects inside `WorldBloc`.

### Components (`lib/features/core/ecs/components/`)

- `TransformComponent`: Position (`Vector2`) and rotation.
- `RenderComponent`: Sprite path/index in the atlas.
- `HealthComponent`: Current/Max HP.
- `AIComponent`: AI state machine and detection logic.
- `AnimationComponent`: Sprite animation frames and timing.

### Entities (`GameEntity`)

A `GameEntity` is a collection of components.
_Example of spawning an enemy in `WorldBloc`:_

```dart
final enemy = GameEntity(
  id: 'enemy_1',
  components: [
    TransformComponent(position: Vector2(10.5, 10.5)),
    RenderComponent(spritePath: 'enemy_grunt'),
    HealthComponent(current: 50, max: 50),
    AIComponent(detectionRange: 10),
  ],
);
```

## 4. Key Systems

Systems process entities and world state during `WorldTick`:

- **PhysicsSystem**: Handles DDA (Digital Differential Analyzer) raycasting for wall collisions and entity-to-entity radius collisions.
- **DamageSystem**: Processes hitscan and projectile damage results.
- **ProjectileSystem**: Simulates bullet movement, bouncing, and collision detection.
- **AISystem**: Computes behavior trees (Idle -> Chase -> Attack).

## 5. Assets & Textures

The engine uses **Procedural Texture Generation** to avoid external file dependencies:

- `TextureGenerator`: Generates the wall atlas, sprite atlas, and weapon atlas using `dart:ui`.
- `TexturePacker`: Converts the `GameMap` into a compact texture that the shader reads as a 2D array of cells.

## 6. How to Implement a New Minigame

To create a minigame, follow these steps:

### Step 1: Define the Map

Modify `MapGenerator` or create a new generator that returns a `GameMap`.

- `Cell.wall`: Solid block.
- `Cell.empty`: Walkable space.
- Max size: 128x128.

### Step 2: Custom Spawning Logic

In `WorldBloc._onInitialized`, define how the player and entities are placed.

```dart
// Example: Survival Mode Spawning
for (int i = 0; i < roundNumber * 5; i++) {
   entities.add(spawnEnemyAtRandomLocation());
}
```

### Step 3: Implement Win/Loss Logic

Listen to `WorldBloc` state changes (e.g., in a new `MinigameBloc` or within `GameBloc`):

- **Win**: All entities with `AIComponent` are inactive.
- **Loss**: `playerHealth <= 0`.

### Step 4: UI & Overlays

Use Flame's `OverlayManager` or Flutter widgets to show "Victory" or "Menu" screens based on `GameBloc.state`.

## 7. Important Constraints

- **Coordinates**: The world is a grid. `(0,0)` is top-left.
- **Raycasting**: Vertical look is not supported (standard 2.5D).
- **Collision**: Use `PhysicsSystem.tryMove` for all entity movement to ensure they don't walk through walls.

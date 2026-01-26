# Agent Context: Memory Lifecycle

## The "Manual" Reality

Because we use `ui.Image` and `FragmentProgram` heavily, we cannot rely solely on Dart's GC.

- **Rule**: If you create a `ui.Image` or `ui.Shader`, you MUST call `.dispose()`.

## Lifecycle Hooks

- **Level Load**:
  - Allocate Texture Atlas.
  - Compile Shaders.
  - Pre-calculate Loot Tables.
- **Level Unload**:
  - `atlas.dispose()`
  - `shader.dispose()`
  - `Flame.images.clearCache()`
- **App Paused (Background)**:
  - Consider freeing heavy procedural textures if OS pressure is high, recreate on resume.

## Leaks Prevention

- **Blocs**: All `StreamSubscriptions` must be closed in `close()`.
- **Flame Components**: `onRemove()` is the destructor. Dispose logic goes here.
- **Monitoring**: Tracking alive `Image` count in the Debug HUD.

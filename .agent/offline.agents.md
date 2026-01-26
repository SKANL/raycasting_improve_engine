# Agent Context: Offline Architecture

## Zero Network Dependency

- **Requirement**: The game must run 100% offline. No API calls for assets, authentication, or leaderboards that block gameplay.
- **Asset Generation**: All assets (textures, sounds, levels) are generated LOCALLY at runtime using pure math and code. No downloading from buckets.

## Persistence (Local Storage)

- **Save System**: Use `hive` or `shared_preferences` (for simple data) to serialize the `WorldState`.
- **State Serialization**:
  - The `GameMap` matrix must be serializable to JSON/Binary.
  - Player position `(x,y,z)` and inventory.
  - Seed of the current world.

## Updates

- **Code Push**: Not applicable. Updates come via app store binaries only.

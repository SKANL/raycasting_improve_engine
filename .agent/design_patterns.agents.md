# Agent Context: Design Patterns & SOLID

## Applied Principles (SOLID)

- **SRP (Single Responsibility)**: A `Weapon` class calculates damage. It does NOT draw itself to the screen (Component does that) or play sounds (AudioController does that).
- **OCP (Open/Closed)**: Enemies should be extendable. Create a base `Enemy` class and extend it for `Soldier`, `Robot`, etc., without modifying the core engine.
- **DIP (Dependency Inversion)**: High-level game logic should not depend on low-level implementation. Use interfaces (abstract classes in Dart) for things like `MapGenerator` or `InputSource`.

## Architecture Patterns

- **ECS (Entity Component System)**:
  - **Entities**: Mere containers (IDs).
  - **Components**: Data/Behavior (Position, Health, Sprite).
  - **Systems**: Logic that iterates over components (PhysicsSystem, RenderSystem).
- **Bloc Pattern**:
  - **Events**: Pure user intentions (`MovePlayer`, `FireWeapon`).
  - **States**: Pure data snapshots (`PlayerIdle`, `PlayerRun`).
  - **B LoC**: Business logic that transforms Events to States.

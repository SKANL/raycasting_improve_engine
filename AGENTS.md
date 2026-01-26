# AGENTS.MD - PROJECT CONTEXT INDEX

> **ATTENTION AI AGENT**: This project uses a **Modular Context System**.
> Do NOT hallucinate rules. Read the specific `agents.md` files in `.agent/` before writing code.

## 1. Project Identity

- **Goal**: Build a "Professional Grade" Raycasting Engine in Flutter (No Unity/Godot).
- **Core Philosophy**: Zero Assets (Procedural), 60 FPS, Offline First, Feature-First Architecture.
- **Engine**: Hybrid (Flame for Loop + Custom GLSL Shaders for 3D).

## 2. Context Map (Reading Order)

### Phase A: Architecture & Rules (READ FIRST)

1.  **[Architecture](.agent/architecture.agents.md)**: Feature-First structure & Bloc/Flame integration.
2.  **[Coding Standards](.agent/coding_standards.agents.md)**: Clean Code, Linter rules, Naming conventions.
3.  **[Workflow](.agent/workflow.agents.md)**: Git, commits, definition of done.
4.  **[Performance Limits](.agent/performance_limits.agents.md)**: Hard budgets for Map Size (128x128) and Ray Dist.

### Phase B: The Engine (Raycasting Core)

5.  **[Engine Specs](.agent/engine.agents.md)**: DDA Algorithm, Texture Atlas strategy.
6.  **[Data Layout](.agent/data_layout.agents.md)**: How Map Data is packed into RGBA Textures for the Shader.
7.  **[Math & Physics](.agent/math_physics.agents.md)**: Unification of 2D/3D physics, gravity in Iso view.
8.  **[State Sync](.agent/state_sync.agents.md)**: The "Flame Update vs Bloc Event" loop.

### Phase C: Gameplay Systems

9.  **[World & ProcGen](.agent/world.agents.md)**: BSP/WFC algorithms for level generation.
10. **[AI Behavior](.agent/ai_behavior.agents.md)**: The FSM (Atormentado/Alerte/Caza) and Sensory System.
11. **[Lighting](.agent/lighting.agents.md)**: Dynamic lighting, Flicker, Normal maps.
12. **[Audio](.agent/audio_system.agents.md)**: Spatial Audio logic.

### Phase D: Guidelines & Polish

13. **[UI/UX](.agent/ui_ux.agents.md)**: HUD states per perspective.
14. **[Accessibility](.agent/accessibility.agents.md)**: High contrast, input remapping.
15. **[Logging](.agent/logging_system.agents.md)**: Telemetry structure.
16. **[Memory](.agent/memory_lifecycle.agents.md)**: Manual `dispose()` rules.

### Phase E: Reference

17. **[Legacy Blueprints](.agent/legacy_blueprints.agents.md)**: Validated logic saved from the old project.
18. **[Dependencies](.agent/dependencies.agents.md)**: Allowed/Banned packages.

## 3. Immediate Priorities

- Run `flutter pub get`.
- Generate the "Texture Atlas" loader (see `engine.agents.md`).
- Implement the `WorldBloc` (see `architecture.agents.md`).

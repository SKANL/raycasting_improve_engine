# Agent Context: Folder Structure (Feature First)

## Location Rules

1.  **Where does it go?**
    - Is it global? -> `lib/app/` or `lib/bootstrap.dart`.
    - Is it a specific game mechanic? -> `lib/features/[mechanic]/`.
    - Is it a helper for `Math` or `Strings`? -> `package:vector_math` or separate utility package.

## Feature Structure

Inside `lib/features/name/`:

- `bloc/`: State management (Blocs, Events, States).
- `components/`: Flame Components (`PositionComponent`, `SpriteComponent`).
- `models/`: Pure Dart data classes (json_serializable).
- `view/`: API agnostic Widgets (HUD, Menus).
- `logic/`: Pure algorithms (BSP, Pathfinding).

## File Naming

- `[feature]_page.dart`: Entry point widget.
- `[feature]_game.dart`: FlameGame instance (if isolated).
- `[name]_component.dart`: Flame components.
- `[name]_repository.dart`: Data access.

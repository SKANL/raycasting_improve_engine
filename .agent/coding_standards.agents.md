# Agent Context: Coding Standards & Best Practices

## General Style

- **Linter**: Follow `very_good_analysis` strictly.
- **Naming**: `camelCase` for variables/functions, `PascalCase` for classes, `snake_case` for files.
- **Comments**: Documentation comments (`///`) for all public APIs. Explain _WHY_, not _WHAT_.

## Dart Specifics

- **Immutability**: Prefer `final` fields. Use `copyWith` for state updates.
- **Enums**: Use Enhanced Enums for game states (e.g., `Direction`, `WeaponType`) to encapsulate logic.
- **Async**: Use `Future` and `Stream` carefully. Avoid `await` inside the hot game loop (`update()` methods).

## Clean Code Rules

- **Small Functions**: Methods should generally fit on one screen (< 50 lines).
- **Early Return**: Prefer returning early over deep nesting.
- **Magic Numbers**: Extract all gameplay constants (speed, damage, map size) to `const` or configuration classes.

# Agent Context: Dependencies & Packages

## Approved Packages (Whitelist)

- **Core Framework**: `flutter`, `flame`, `flame_bloc`.
- **State Management**: `bloc`, `flutter_bloc`, `equatable`.
- **Graphics/Shaders**: `flutter_shaders`, `vector_math`.
- **ProcGen**: `fast_noise`.
- **Audio**: `flame_audio`.
- **Utilities**: `collection` (Dart), `intl` (Localization).

## STRICTLY FORBIDDEN

- **NO Generic State Managers**: Do not use `provider`, `get_x`, or `riverpod` (we use Bloc exclusively).
- **NO Heavy 3D Engines**: Do not use `flutter_cube` or high-level 3D wrappers. We build the engine raw.
- **NO Imperative UI**: Do not use `Get` or global keys for navigation unless absolutely necessary via `Navigator`.

## Rules for New Dependencies

1. **Justification**: Must provide a 10x speedup or solve a non-trivial math problem.
2. **Flutter Web Support**: All packages MUST support Flutter Web (WASM preferred).
3. **Pure Dart**: Prefer pure Dart packages over platform channels to ensure portability.

# Agent Context: Quality Standards & Testing

## Code Quality Rules

- **Linter**: `very_good_analysis` (Strict). No lint suppressions (`// ignore:`) without written justification in PR.
- **Immutability**: All State classes must be `immutable` and use `Equatable`.
- **Typing**: No `dynamic`. Explicit types for all public APIs.

## Testing Strategy

- **Unit Tests**:
  - `bloc_test` for all Blocs (100% coverage required for logic).
  - Math algorithms (Raycasting logic, DDA) must be unit tested isolated from Flutter.
- **Widget Tests**:
  - Smoke tests for all major screens/overlays.
- **Golden Tests**:
  - Pixel-perfect verification for procedural generation outputs (render the map to an image and compare).

## Performance Budgets

- **Frame Rate**: Minimum 60 FPS on mid-range devices (Pixel 4 equivalent).
- **Memory**: Max 200MB execution heap.
- **Startup**: App interactive in < 2 seconds.

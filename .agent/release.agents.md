# Agent Context: Release & Build

## Platforms

- **Primary**: Web (WASM).
- **Secondary**: Android/iOS.
- **Tertiary**: Windows/macOS.

## Build Flags

- **Web**: `flutter build web --wasm` (Requires shader support enabled).
- **Profile Mode**: Use `flutter run --profile` for all performance testing. Never optimize based on Debug mode metrics.

## CI/CD Pipeline Operations

1. `flutter format --set-exit-if-changed .`
2. `flutter analyze .`
3. `flutter test`
4. `very_good test --coverage` (Target: 100%).

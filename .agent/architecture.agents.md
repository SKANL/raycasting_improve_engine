# Agent Context: Architecture

## Frameworks & Patterns

- **Base Template**: Very Good Flame.
- **Architecture Style**: Feature-First.
- **State Management**: Bloc / Flutter Bloc.
- **Integration**: `flame_bloc` for syncing Bloc state with Flame components.

## Directory Structure (Standardized)

```text
lib/
├── app/                  # Global providers, app-wide logic, DI.
├── features/             # Domain-specific modules.
│   ├── [feature_name]/
│   │   ├── bloc/         # Bloc events, states, and logic.
│   │   ├── components/   # Flame entity components.
│   │   ├── models/       # Data classes.
│   │   └── view/         # UI Widgets (Overlay, HUD).
├── l10n/                 # Localization.
└── main.dart             # Entry point.
```

## Key Constraints

- **Maintain DI Consistency**: Use the DI pattern established by Very Good Ventures.
- **Separation of Concerns**: Flame components should not contain business logic; they should reflect state from Blocs.

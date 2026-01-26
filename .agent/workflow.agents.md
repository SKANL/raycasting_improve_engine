# Agent Context: Workflow & Governance

## Git Strategy

- **Branching**: Feature Branch Workflow.
  - `main`: Production-ready code.
  - `feat/feature-name`: New features.
  - `fix/bug-name`: Bug fixes.
- **Commit Messages**: Conventional Commits.
  - `feat: add raycasting shader`
  - `fix: correct DDA overflow`
  - `docs: update agents.md`
  - `refactor: optimize loop`

## Code Review Checklist

- [ ] Does it maintain 60 FPS?
- [ ] Is it compatible with Flutter Web (WASM)?
- [ ] Are new files covered by an `agents.md` context?
- [ ] No `print()` statements (use `Logger`).

## Definition of Done

- Feature is implemented.
- Tests (Unit/Widget) pass.
- Context files updated if architecture changed.

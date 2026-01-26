# Agent Context: UI & User Experience

## Design Philosophy

- **Diegetic UI**: Prefer elements that exist "in the world" (e.g., ammo counter on the gun, health as screen vignette) over floating overlays, especially in 3D view.
- **Context-Sensitive**: The UI layer changes completely based on the active perspective.

## HUD States

### 1. 2D Tactical View

- **Visible**: Radar grid, enemy pings, layout tools.
- **Hidden**: Immersion elements (vignette).
- **Controls**: Tap-to-move, pinch-to-zoom.

### 2. 3D First-Person View

- **Visible**: Crosshair, weapon sprite, health vignette, minimal ammo count.
- **Hidden**: Minimap (unless a "radar" item is equipped).
- **Controls**: Virtual Joystick (movement), Swipe (look).

### 3. Isomeric View

- **Visible**: Vertical platform markers, shadow indicators (for landing).
- **Controls**: D-pad for grid alignment.

## Responsiveness

- **Mobile First**: Touch targets minimum 48x48dp.
- **Safe Areas**: HUD elements must respect notches and rounded corners.

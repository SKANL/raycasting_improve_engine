# Agent Context: Legacy Blueprints (Salvaged Logic)

This file contains specific algorithms and logic patterns "rescued" from the legacy `game_Good_dark` project. These are **validated** mechanics that should be ported to the new architecture.

## 1. AI State Machine (The "Resonance" Logic)

**Source**: `HearingBehavior.dart`
**Context**: Enemies are blind entities sensitive to sound and "Mental Noise".

### States (FSM)

- **Atormentado (Base)**:
  - _Behavior_: Random patrol / Idle.
  - _Trigger_: Ignores "Low" sound level. Only reacts to "Medium" or "High".
  - _Transition_: On (Medium/High) Sound -> Go to `Alerta` (or `Caza` if High).
- **Alerta (Investigate)**:
  - _Behavior_: Moves to `lastKnownSoundPosition`.
  - _Timer_: Gives up after 5 seconds -> Back to `Atormentado`.
  - _Transition_: on (Amy) Sound -> Go to `Caza`.
- **Caza (Hunt)**:
  - _Behavior_: A\* Pathfinding direct to Player.
  - _Persistence_: Timer resets every time a sound is heard. Cooldown 3s.
  - _Transition_: Timer expires -> Back to `Alerta`.
- **Aturdido (Stunned)**:
  - _Behavior_: No movement.
  - _Trigger_: Sonic Shield / Knockback.

## 2. Lighting Mathematics (Port to GLSL)

**Source**: `RaycastRendererComponent.dart`

### Volumetric Fog (Beer's Law)

Used to hide the lack of infinite render distance and build atmosphere.

```glsl
// GLSL Equivalent
float fogDensity = 0.15;
float fogFactor = exp(-fogDensity * perpWallDist);
fogFactor = clamp(fogFactor, 0.0, 1.0);
vec3 finalColor = mix(skyColor, wallColor, fogFactor);
```

### Specular Highlight (Blinn-Phong)

Even in a pixel art game, wet surfaces need highlights.

```glsl
// GLSL Equivalent
// L = LightDir, V = ViewDir, N = Normal
vec3 H = normalize(L + V);
float NdotH = max(dot(N, H), 0.0);
float specular = pow(NdotH, 32.0); // Shininess
```

## 3. Gameplay Mechanics

### Mental Noise (Ruido Mental)

- **Global Variable**: 0 to 100.
- **Effect 1 (Visual)**: If `Noise > 75`, start "Glitch" effect in Shader (vertex displacement).
- **Effect 2 (AI)**: If `Noise > 75`, multiply enemy Hearing Radius by 1.5x.

### Echolocation (Sonic Wave)

- **Logic**: A circular pulse expanding from Player.
- **Visual**: Walls intersect with the "Ring" (Radius) get a brightness boost or outlining color (`Color(0xFF00FFFF)` in legacy).

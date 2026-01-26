# Agent Context: Audio System

## Spatial Audio

- **3D Perspective**:
  - **Stereo Panning**: Calculate angle between Player Forward Vector and Source Vector. `dot product` determines Left/Right balance.
  - **Attenuation**: Volume = `1.0 - (distance / max_audible_range)`.
- **2D/Iso Perspective**:
  - Audio is generally centralized (mono/centered stereo) or simple distance-based volume, as directional panning can be confusing in top-down.

## Adaptive Music

- **Structure**: Vertical Layering (Stems).
  - _Base Layer_: Drums/Bass (Always on).
  - _Tension Layer_: Pads (On when enemies nearby).
  - _Action Layer_: Lead Synth (On during combat).
- **Implementation**: Sync using `flame_audio` loop players. Fading (tweens) between states is mandatory for professional feel.

## Procedural Sound

- **Synthesizer**: Investigating `dart_synth` or generating PCM buffers manually for simple effects (retro lasers, jump sounds) to avoid assets.

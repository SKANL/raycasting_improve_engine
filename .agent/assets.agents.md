# Agent Context: Assets & Resources

## Philosophy: Code Over Artifacts

We prioritize **Procedural Generation** over static assets to keep the bundle size small and the world infinite.

## Texture Strategy

- **Texture Atlases**: Generated at runtime.
  - Input: Noise functions + color palettes.
  - Output: `ui.Image` pushed to GPU memory.
- **Pixel Art**: If static sprites are needed (e.g., enemies), use strict 8-bit or 16-bit palettes to match the retro aesthetic.

## Audio Strategy

- **Format**: WAV for SFX (low latency), MP3/OGG for music.
- **Preloading**: All gameplay-critical SFX must be preloaded in `WorldBloc` initialization.

## Strings & Localization

- **l10n**: All user-facing strings must go through `l10n.yaml` and `.arb` files. No hardcoded strings in widgets.

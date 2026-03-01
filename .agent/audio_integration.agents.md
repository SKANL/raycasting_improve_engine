# Agent Context: Audio System Integration

## Overview

The Audio System provides centralized management of background music and sound effects (SFX) using the `AudioService` singleton pattern with `audioplayers` package.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│          AudioService (Singleton Pattern)                │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Features:                                        │  │
│  │ • Background music (loop, fade-in/out)          │  │
│  │ • SFX pooling (multiple simultaneous sounds)   │  │
│  │ • Volume control (master, music, SFX)           │  │
│  │ • Lifecycle management (init, dispose)          │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
       ↑                                    ↑
       │                                    │
   RaycastingGame               WeaponBloc
   (Background Music)          (SFX: Fire/Reload)
```

## Class: AudioService

**Location**: `lib/core/audio/audio_service.dart`

**Pattern**: Singleton-like (factory constructor with static instance)

### Methods

#### Initialization
```dart
/// Initialize audio service (call once on app start)
Future<void> init() async

/// Dispose all resources (call on app shutdown)
Future<void> dispose() async
```

#### Background Music
```dart
/// Play background music with optional fade-in
/// [assetPath] = asset relative path (e.g., 'audio/background.mp3')
/// [volume] = 0.0-1.0 (uses _musicVolume if null)
/// [fadeInDuration] = fade-in milliseconds (default 1000)
Future<void> playBackgroundMusic(
  String assetPath, 
  {double? volume, int fadeInDuration = 1000}
) async

/// Stop background music with fade-out
/// [fadeOutDuration] = fade-out milliseconds (default 500)
Future<void> stopBackgroundMusic({int fadeOutDuration = 500}) async
```

#### Sound Effects (SFX)
```dart
/// Play SFX with overlap support (pool-based)
/// May play multiple times simultaneously
/// [assetPath] = asset relative path (e.g., 'audio/weapons/pistol_fire.wav')
/// [volume] = 0.0-1.0 (uses _sfxVolume if null)
Future<void> playSFX(
  String assetPath, 
  {double? volume}
) async
```

#### Volume Control
```dart
/// Update master volume (affects all audio)
void setMasterVolume(double volume)  // 0.0-1.0

/// Update music volume (new music only)
void setMusicVolume(double volume)   // 0.0-1.0

/// Update SFX volume (new SFX only)
void setSFXVolume(double volume)     // 0.0-1.0

/// Getters
double get masterVolume
double get musicVolume
double get sfxVolume
```

## Integration Points

### 1. RaycastingGame (Background Music)

**File**: `lib/features/game/raycasting_game.dart`

**onLoad()**:
```dart
@override
Future<void> onLoad() async {
  // ... shader load ...
  
  // Initialize and start background music
  await AudioService().init();
  await AudioService().playBackgroundMusic(
    'audio/background.mp3',
    fadeInDuration: 1500,
  );
  
  // ... rest of initialization ...
}
```

**onDetach()**:
```dart
@override
void onDetach() {
  // Stop music on game exit
  AudioService().stopBackgroundMusic(fadeOutDuration: 300).ignore();
  super.onDetach();
}
```

### 2. WeaponBloc (Fire/Reload Sounds)

**File**: `lib/features/game/weapon/bloc/weapon_bloc.dart`

**Constructor**:
```dart
WeaponBloc({AudioService? audioService})
    : _audioService = audioService ?? AudioService(),
      super(const WeaponState()) {
  // ... handlers ...
}
```

**_onWeaponFired()**:
```dart
void _onWeaponFired(WeaponFired event, Emitter<WeaponState> emit) {
  if (!state.canFire) {
    // Play empty clip sound if no ammo
    if (state.currentAmmo <= 0) {
      _audioService.playSFX('audio/weapons/empty_clip.wav', volume: 0.6);
    }
    return;
  }

  // Play weapon fire sound
  _audioService.playSFX(state.currentWeapon.fireSound, volume: 0.8);

  emit(state.copyWith(currentAmmo: state.currentAmmo - 1, lastFireTime: DateTime.now()));
}
```

**_onWeaponReloaded()**:
```dart
void _onWeaponReloaded(WeaponReloaded event, Emitter<WeaponState> emit) {
  _audioService.playSFX(state.currentWeapon.reloadSound, volume: 0.7);
  emit(state.copyWith(currentAmmo: state.currentWeapon.maxAmmo));
}
```

**_onWeaponSwitched()**:
```dart
void _onWeaponSwitched(WeaponSwitched event, Emitter<WeaponState> emit) {
  _audioService.playSFX('audio/weapons/weapon_switch.wav', volume: 0.6);
  emit(WeaponState(currentWeapon: event.weapon, currentAmmo: event.weapon.maxAmmo));
}
```

### 3. GamePage (Dependency Injection)

**File**: `lib/features/game/view/game_page.dart`

**MultiBlocProvider**:
```dart
BlocProvider(create: (_) => WeaponBloc(audioService: AudioService())),
```

## Audio Assets Mapping

### Background Music

| Asset | Location | Usage | Notes |
|-------|----------|-------|-------|
| `background.mp3` | `assets/audio/` | Game loop | Fade-in: 1500ms |
| `effect.mp3` | `assets/audio/` | Alternative ambiance | Not currently used |
| `Vertical_Layering.mp3` | `assets/audio/musica_fondo/` | Wave escalation (future) | Adaptive layers |

### Weapon SFX

| Event | Asset | Location | Volume | Notes |
|-------|-------|----------|--------|-------|
| Pistol Fire | `pistol_fire.wav` | `assets/audio/weapons/` | 0.8 | Default fire sound |
| Shotgun Fire | `shotgun_fire.wav` | `assets/audio/weapons/` | 0.9 | Higher volume for impact |
| Rifle Fire | `pistol_fire.wav` | `assets/audio/weapons/` | 0.8 | Fallback (no rifle sound) |
| Reload | `reload.wav` | `assets/audio/weapons/` | 0.7 | All weapons |
| Weapon Switch | `weapon_switch.wav` | `assets/audio/weapons/` | 0.6 | UI feedback |
| Empty Clip | `empty_clip.wav` | `assets/audio/weapons/` | 0.6 | No ammo feedback |

## Weapon Model Updates

**File**: `lib/features/game/weapon/models/weapon.dart`

### New Fields
```dart
/// Fire sound asset path (relative to assets/)
final String fireSound;

/// Reload sound asset path (relative to assets/)
final String reloadSound;
```

### Weapon Definitions with Sounds
```dart
static const pistol = Weapon(
  // ... existing fields ...
  fireSound: 'audio/weapons/pistol_fire.wav',
  reloadSound: 'audio/weapons/reload.wav',
);

static const shotgun = Weapon(
  // ... existing fields ...
  fireSound: 'audio/weapons/shotgun_fire.wav',
  reloadSound: 'audio/weapons/reload.wav',
);
```

## Volume Guidelines

| Type | Default | Min | Max | Use Case |
|------|---------|-----|-----|----------|
| **Master** | 1.0 | 0.0 | 1.0 | Global mute/volume |
| **Music** | 0.6 | 0.0 | 1.0 | Background music level |
| **SFX** | 0.8 | 0.0 | 1.0 | Weapon/effect volume |

## SFX Pool (Internal)

The AudioService maintains a pool of `AudioPlayer` instances per asset to allow simultaneous playback:

```
Asset: 'audio/weapons/pistol_fire.wav'
Pool: [AudioPlayer(1), AudioPlayer(2), AudioPlayer(3)]
       ↓ in use          ↓ available         ↓ available

playSFX('audio/weapons/pistol_fire.wav')
  → Checks pool for available player
  → Uses first stopped player (or creates new)
  → Plays sound
```

**Benefits**:
- ✅ Multiple gunshots can overlap
- ✅ No memory churn (reuse players)
- ✅ Automatic pool expansion if needed

## Fade Effects

### Fade-In (playBackgroundMusic)
- Default: **1000 ms** (1 second)
- Current: **1500 ms** for game start (smooth introduction)
- Steps: 20 increments
- Easing: Linear

### Fade-Out (stopBackgroundMusic)
- Default: **500 ms** (0.5 seconds)
- Current: **300 ms** for inventory/pause (quick transition)
- Steps: 10 increments
- Easing: Linear

## Lifecycle Management

### Initialization Flow
1. **RaycastingGame.onLoad()**
   - Calls `AudioService().init()`
   - Starts background music with fade-in

2. **GamePage.build()** 
   - Injects `AudioService` into `WeaponBloc` via constructor

### Cleanup Flow
1. **Game Exit / Back Pressed**
   - `RaycastingGame.onDetach()` is called
   - Calls `AudioService().stopBackgroundMusic(fadeOut: 300ms)`
   - Music fades out gently

2. **Shutdown**
   - `AudioService.dispose()` stops all players
   - Resources freed (audio context closed)

## Testing Checklist

- [ ] Background music starts on game launch (fade-in 1500ms)
- [ ] Pistol fire plays when pistol.fireSound triggers
- [ ] Shotgun fire plays with higher volume (0.9)
- [ ] Reload sound plays on weapon reload
- [ ] Weapon switch sound plays on cycle
- [ ] Empty clip sound plays when ammo = 0
- [ ] Multiple gunshots can overlap (pool)
- [ ] Master volume mutes all audio
- [ ] Music stops (fade-out 300ms) on game exit
- [ ] No memory leaks (players disposed properly)
- [ ] Works on mobile (iOS/Android)
- [ ] Works on web (WASM)

## Future Enhancements

### Planned
- [ ] **Adaptive Music** (LevelBloc integration)
  - Change music intensity based on wave number
  - Use `Vertical_Layering.mp3` with layer control

- [ ] **Spatial Audio** (Position-based)
  - Stereo panning based on enemy position
  - Distance-based attenuation

- [ ] **UI SFX** (Menu interactions)
  - Button click sounds
  - Navigation transitions

- [ ] **Enemy SFX** (WorldBloc integration)
  - Footsteps (when enemies move)
  - Enemy death sounds
  - Ambient background noise

- [ ] **Settings Menu**
  - Volume sliders (Master/Music/SFX)
  - Mute option
  - Persistence (SharedPreferences)

### Nice-to-Have
- [ ] 3D positional audio (doppler effect)
- [ ] Audio ducking (music quiets during SFX)
- [ ] HRTF processing (3D audio immersion)

## Troubleshooting

### Audio Not Playing
1. Check asset path is correct (relative to `assets/`)
2. Verify audio file exists in `pubspec.yaml` assets list
3. Check volume is > 0.0 (not muted)
4. Check `AudioService().init()` was called

### Audio Crackling/Quality Issues
1. Reduce simultaneous SFX count (SFX pool limit)
2. Lower master volume if device is overdriven
3. Ensure device audio output is not clipping

### Memory Leak
1. Verify `dispose()` is called in cleanup
2. Check `onDetach()` is stopping background music
3. Ensure WeaponBloc is destroyed properly

## References

- **Package**: `audioplayers: ^6.5.1`
- **Dart Docs**: https://pub.dev/packages/audioplayers
- **Flame Integration**: Use directly (no flame_audio required for SFX)

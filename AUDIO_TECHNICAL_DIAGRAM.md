# 🎵 INTEGRACIÓN DE AUDIO - DIAGRAMA TÉCNICO COMPLETO

## 1. ARQUITECTURA GENERAL

```
┌────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                         APP LIFECYCLE                              │
│                                                                     │
│  bootstrap()                                                        │
│    └─ WidgetsFlutterBinding.ensureInitialized()                   │
│    └─ SystemChrome.setPreferredOrientations([landscape])          │
│    └─ runApp(App)                                                  │
│         └─ AppView                                                 │
│              └─ MaterialApp                                        │
│                   └─ home: MenuPage                                │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                      MENU SCREEN                                   │
│                                                                     │
│  MenuPage._initAudio()                                              │
│    └─ _audioPlayer = AudioPlayer()                                │
│    └─ setSource(AssetSource('audio/menu_music.ogg'))             │
│    └─ setReleaseMode(ReleaseMode.loop)                           │
│    └─ setVolume(0.0)  ← Muted initially                          │
│    └─ resume()                                                    │
│    └─ _fadeInAudio()  ← Over 2 seconds                           │
│         └─ Volume: 0.0 → 0.5 (20 steps)                          │
│                                                                     │
│  User presses: "INICIAR"                                           │
│    └─ _audioPlayer.stop()  ← Stop menu music                      │
│    └─ Navigator.pushReplacement → GamePage()                      │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                   GAME PAGE (Build)                                │
│                                                                     │
│  MultiBlocProvider.providers:                                      │
│    ├─ WorldBloc()                                                  │
│    ├─ InputBloc()                                                  │
│    ├─ PerspectiveBloc()                                            │
│    ├─ WeaponBloc(audioService: AudioService())  ✨ NEW            │
│    │   └─ Inyecta singleton AudioService aquí                     │
│    ├─ GameBloc(worldBloc: ...)                                    │
│    └─ LevelBloc()                                                  │
│                                                                     │
│  BlocBuilder<WorldBloc>: determina LoadingScreen vs GameView       │
│    ├─ status=loading → LoadingScreen                               │
│    │   └─ WorldBloc._onInitialized (GenerateMap, Entities)        │
│    └─ status=active → GameView                                    │
│         └─ _GameViewState.initState()                             │
│              └─ RaycastingGame(all blocs) ← Flame game init        │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────────┐
│                                                                     │
│              RAYCASTING GAME (FlameGame)                           │
│                                                                     │
│  RaycastingGame.onLoad()                                            │
│    ├─ await ShaderManager.load()                                   │
│    ├─ await super.onLoad()                                         │
│    ├─ Initialize Audio ✨                                          │
│    │   ├─ await AudioService().init()                             │
│    │   └─ await AudioService().playBackgroundMusic(               │
│    │       'audio/background.mp3',                                 │
│    │       fadeInDuration: 1500ms                                  │
│    │   )                                                           │
│    │       └─ Background player: 0.0 → 0.6 (20 steps × 75ms)     │
│    │                                                               │
│    ├─ RaycastRenderer setup                                         │
│    │   ├─ FlameBlocProvider<GameBloc>                             │
│    │   ├─ FlameBlocProvider<WorldBloc>                            │
│    │   ├─ FlameBlocProvider<PerspectiveBloc>                      │
│    │   └─ FlameBlocProvider<WeaponBloc>  ← Audio linked here      │
│    │                                                               │
│    ├─ World effects listener                                       │
│    │   └─ Listen for PlayerDamagedEffect, etc.                    │
│    │                                                               │
│    └─ Initialize Mobile Controls                                  │
│        ├─ Joystick (movement)                                     │
│        ├─ Fire Button → WeaponBloc.add(WeaponFired)              │
│        ├─ Reload Button → WeaponBloc.add(WeaponReloaded)         │
│        └─ Weapon Cycle → WeaponBloc.add(WeaponSwitched(...))     │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────────┐
│                                                                     │
│           MAIN GAME LOOP (RaycastingGame.update)                   │
│                                                                     │
│  Every frame @ 60 Hz:                                              │
│    ├─ levelBloc.add(SurvivalTick(dt))                              │
│    ├─ worldBloc.add(WorldTick(dt))                                │
│    ├─ _processInput(dt)                                            │
│    │   └─ Read inputBloc.state.activeActions                      │
│    │   └─ If FIRE_PRESSED → weaponBloc.add(WeaponFired())         │
│    │   └─ If RELOAD_PRESSED → weaponBloc.add(WeaponReloaded())   │
│    │   └─ If SWITCH_PRESSED → weaponBloc.add(WeaponSwitched(...)) │
│    │                                                               │
│    └─ _renderer?.update(dt)  ← Render frame                       │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ WeaponBloc Event Handlers (Audio Triggers) ✨               │ │
│  │                                                               │ │
│  │ _onWeaponFired():                                            │ │
│  │   if (canFire):                                              │ │
│  │     AudioService.playSFX(fireSound, volume: 0.8)  ← DISPARO│ │
│  │     emit(state with ammo-1)                                 │ │
│  │   else:                                                      │ │
│  │     if (ammo==0):                                            │ │
│  │       AudioService.playSFX('empty_clip.wav', vol: 0.6) ← VAC│ │
│  │                                                               │ │
│  │ _onWeaponReloaded():                                         │ │
│  │   AudioService.playSFX(reloadSound, volume: 0.7)  ← RECARGA│ │
│  │   emit(state with ammo=max)                                 │ │
│  │                                                               │ │
│  │ _onWeaponSwitched():                                         │ │
│  │   AudioService.playSFX('weapon_switch.wav', vol: 0.6) ← CAM│ │
│  │   emit(new weapon state)                                    │ │
│  │                                                               │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ AudioService SFX Pool (Background)                          │ │
│  │                                                               │ │
│  │ When playSFX() is called:                                    │ │
│  │   1. Look up pool for asset                                 │ │
│  │   2. Find first stopped player (or create new)              │ │
│  │   3. setVolume(volume × masterVolume)                       │ │
│  │   4. setSource(AssetSource(path))                           │
│  │   5. setReleaseMode(ReleaseMode.release)                    │ │
│  │   6. resume()  ← Play starts                                │ │
│  │                                                               │ │
│  │ Result: Multiple shots can overlap without conflict         │ │
│  │                                                               │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ Background Music (Continuous Loop)                          │ │
│  │                                                               │ │
│  │ State:                                                       │ │
│  │   After fade-in completes:                                  │ │
│  │   • Volume: 0.6 (60% of master)                             │ │
│  │   • ReleaseMode: ReleaseMode.loop  ← Repeats forever       │ │
│  │   • State: Playing (continues throughout game)              │ │
│  │                                                               │ │
│  │ No action needed - just plays in background                 │ │
│  │                                                               │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
                              ↓
                   (User presses ESC or Victory)
                              ↓
┌────────────────────────────────────────────────────────────────────┐
│                                                                     │
│            RAYCASTING GAME EXIT (onDetach)                         │
│                                                                     │
│  RaycastingGame.onDetach()                                          │
│    ├─ _worldEffectsSub?.cancel()                                   │
│    ├─ Stop Background Music ✨                                     │
│    │   ├─ AudioService().stopBackgroundMusic(                      │
│    │   │   fadeOutDuration: 300ms                                  │
│    │   │ )                                                         │
│    │   │   └─ Background player: 0.6 → 0.0 (10 steps × 30ms)     │
│    │   └─ _backgroundMusic?.dispose()                             │
│    │   └─ _backgroundMusic = null                                 │
│    │                                                               │
│    └─ super.onDetach()  ← Flame cleanup                           │
│                                                                     │
│  Result: Music fades out smoothly over 300ms                      │
│           No jarring silence or volume jump                        │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────────┐
│                                                                     │
│              BACK TO MENU (Navigator.pop)                          │
│                                                                     │
│  MenuPage._initAudio() runs again                                   │
│    └─ Menu music fades in again (2 seconds)                       │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

---

## 2. SINGLESHOT FIRE AUDIO FLOW

```
USER PRESSES: Fire Button
       ↓
RaycastingGame._processInput()
  checks inputBloc.state.isPressed(FIRE)
       ↓
weaponBloc.add(WeaponFired())
       ↓
WeaponBloc._onWeaponFired()
  ├─ Check canFire? 
  │   ├─ If false:
  │   │   ├─ If ammo==0:
  │   │   │   AudioService.playSFX('empty_clip.wav', vol: 0.6)
  │   │   │       ↓ plays ~200ms "click" sound  🔊
  │   │   │   return (no fire)
  │   │   └─ If cooldown active: return (no sound)
  │   │
  │   └─ If true:
  │       ├─ AudioService.playSFX(weapon.fireSound, vol: 0.8)
  │       │     ↓
  │       │     AudioService._sfxPools[fireSound]
  │       │       └─ Find or create available player
  │       │       └─ setVolume(0.8 * masterVolume) = 0.64
  │       │       └─ setSource(AssetSource(fireSound))
  │       │       └─ resume() ← Sound plays  🔥
  │       │     ↓ ~150-200ms duration
  │       │
  │       └─ emit(state with ammo-1, lastFireTime=now)
  │           └─ RaycastRenderer listens & shows muzzle flash
  │           └─ Projectile spawned (hitscan/bullet)
  │           └─ HUD updates ammo count
  │
  └─ Weapon cooldown starts
      └─ Next fire available after 1/fireRate seconds
         (Pistol: 0.5s cooldown = 2 shots/sec)

AUDIO TIMELINE:
T=0ms:    ┌─ fireSound STARTS  [gunshot audio]
          │
T=150ms:  │ fireSound ENDS ─────┘
          │
T=200ms:  │ Player CAN'T fire (cooldown active)
          │ If fire pressed: empty_clip.wav plays [click sound]
          │
T=500ms:  └─ Cooldown ends → Player CAN fire again
```

---

## 3. STATE DIAGRAM: WeaponBloc Audio Events

```
                 ┌─────────────────────────────────────┐
                 │   INITIAL STATE                     │
                 │  weapon: Pistol                     │
                 │  ammo: 12                           │
                 │  canFire: true                      │
                 └─────────┬───────────────────────────┘
                           │
          ┌────────────────┼─────────────────┐
          │                │                 │
          ↓                ↓                 ↓
    ┌──────────┐      ┌──────────┐    ┌──────────┐
    │FIRE PRESS│      │RELOAD    │    │SWITCH    │
    │(canFire) │      │PRESSED   │    │PRESSED   │
    └────┬─────┘      └────┬─────┘    └────┬─────┘
         │                 │               │
         ↓                 ↓               ↓
    🔊FIRE SOUND      🔊RELOAD SND    🔊SWITCH SND
    (0.8 volume)      (0.7 volume)   (0.6 volume)
         │                 │               │
         ↓                 ↓               ↓
    ammo -= 1         ammo = MAX      ammo = NEW_MAX
    cooldown = 0.5s   cooldown = 0  cooldown = 0
         │                 │               │
         └────────────────┬┴───────────────┘
                          │
          ┌───────────────┼──────────────┐
          │               │              │
          ↓               ↓              ↓
    🔄COOLDOWN      ✅READY         ⚙️SAME STATE
    canFire=F      canFire=T      (instant)
          │               │
          ├─ 0.5sec ──────→
          │
    ┌──────────┐
    │FIRE PRESS│
    │(canFire  │
    │   = F)   │
    └────┬─────┘
         │
         ↓
    🔊EMPTY SND  (0.6 volume)  [if ammo == 0]
    OR: 🔕 NO SOUND [if cooldown active]
         │
         └─ ammo unchanged
            cooldown unchanged
            (no state change sent)
```

---

## 4. AUDIO SERVICE SINGLETON STATE

```
┌──────────────────────────────────────────────────────────┐
│           AudioService Instance (Memory)                 │
│                                                           │
│  Static Member:                                          │
│  _instance: AudioService = AudioService._internal()   │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Background Music State                            │ │
│  │  _backgroundMusic: AudioPlayer                    │ │
│  │    └─ Loaded: background.mp3                      │ │
│  │    └─ ReleaseMode: loop                           │ │
│  │    └─ Volume: 0.6 (after fade-in)                │ │
│  │    └─ State: PLAYING                              │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │ SFX Pool                                           │ │
│  │  _sfxPools: Map<String, List<AudioPlayer>>        │ │
│  │                                                    │ │
│  │  'audio/weapons/pistol_fire.wav':                │ │
│  │    [Player(stopped), Player(stopped), ...]        │ │
│  │  'audio/weapons/shotgun_fire.wav':               │ │
│  │    [Player(stopped), ...]                         │ │
│  │  'audio/weapons/reload.wav':                     │ │
│  │    [Player(stopped), ...]                         │ │
│  │  'audio/weapons/weapon_switch.wav':               │ │
│  │    [Player(stopped), Player(stopped)]             │ │
│  │  'audio/weapons/empty_clip.wav':                 │ │
│  │    [Player(stopped), ...]                         │ │
│  │                                                    │ │
│  │  Pool Behavior:                                    │ │
│  │  • First call creates lazy                         │ │
│  │  • Expands as needed                               │ │
│  │  • Only "stopped" players are reused              │ │
│  │  • Allows overlap (simultaneous playback)         │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Volume Settings                                   │ │
│  │  _masterVolume: 1.0   (global mute/volume)        │ │
│  │  _musicVolume: 0.6    (background music)          │ │
│  │  _sfxVolume: 0.8      (weapon sounds)             │ │
│  │                                                    │ │
│  │  Effective Volume = baseVolume × masterVolume     │ │
│  │  Ex: SFX @ 0.8 × 1.0 master = 80% device volume │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  Initialization Flag:                                    │
│  _isInitialized: bool = false (set to true on init()) │ │
│                                                           │
└──────────────────────────────────────────────────────────┘

Factory Constructor:
  factory AudioService() => _instance
  ├─ Always returns SAME instance (singleton)
  ├─ No matter how many times called
  └─ Ensures single audio context
```

---

## 5. CODE CALL CHAIN: Fire Event → Sound

```
1️⃣ GAMEPAD/KEYBOARD/TOUCH EVENT
   └─ RaycastingGame._processInput(dt)
       └─ Reads: inputBloc.state.activeActions
       └─ Checks: isPressed(GameAction.fire)
       └─ Calls: weaponBloc.add(WeaponFired())

2️⃣ WEAPON BLOC PROCESSES EVENT
   └─ WeaponBloc._onWeaponFired(event, emit)
       ├─ Guard: if (!state.canFire) return
       ├─ Guard: if (state.currentAmmo <= 0)
       │   └─ _audioService.playSFX(
       │       'audio/weapons/empty_clip.wav',
       │       volume: 0.6  ← Override to 0.6
       │     )
       │   └─ return  (no fire)
       │
       └─ Action: Fire is allowed!
           ├─ _audioService.playSFX(
           │   state.currentWeapon.fireSound,  ← Path from weapon
           │   volume: 0.8  ← Fire default volume
           │ )
           └─ emit(state.copyWith(
               currentAmmo: ammo - 1,
               lastFireTime: now
             ))

3️⃣ AUDIO SERVICE PLAYS SFX
   └─ AudioService.playSFX(path, volume)
       ├─ Get or create pool for path
       ├─ Find available player (stopped state)
       │  (or create new if none available)
       ├─ Calculate final volume:
       │   finalVolume = volume × _masterVolume
       │            = 0.8 × 1.0 = 0.8
       ├─ player.setVolume(0.8)
       ├─ player.setSource(AssetSource(path))
       ├─ player.setReleaseMode(release)  ← Don't loop SFX
       ├─ player.resume()  ← START PLAYBACK ← 🔊
       └─ Log: 'audio/weapons/pistol_fire.wav @ 0.8 vol'

4️⃣ AUDIO PLAYS FOR ~150-200ms
   ├─ Device speaker emits sound
   ├─ Meanwhile, other actions continue:
   │   ├─ RaycastRenderer draws muzzle flash
   │   ├─ ProjectileSystem spawns bullet
   │   ├─ GameBloc updates UI
   │   └─ Next shot queued if fire still held
   │
   └─ After duration: Audio ends naturally
        └─ Player state → STOPPED
        └─ Available for pool reuse

5️⃣ COOLDOWN & NEXT FIRE
   ├─ cooldown = 1.0 / fireRate
   │  (Pistol: 1.0 / 2.0 = 0.5s)
   ├─ During cooldown:
   │   └─ if (fire pressed):
   │       └─ canFire check fails
   │       └─ Empty clip sound plays if ammo==0
   │       └─ Otherwise: silent (no state change)
   └─ After 0.5s:
       └─ canFire reset to true
       └─ Next WeaponFired event fires weapon again
           └─ Next shot audio plays
```

---

## 6. MULTI-SHOT OVERLAPPING (Pool Behavior)

```
Scenario: Rapid Shotgun Bursts

T=0ms:    User presses fire
          weaponBloc.add(WeaponFired()) [1st]
          AudioService.playSFX('shotgun_fire.wav')
            └─ _sfxPools['shotgun_fire'].Player[0] plays
               ┌─ shotgun sound STARTS ────────────────┐
               │                                       │

T=100ms:  Still holding fire, next shot cooldown done
          weaponBloc.add(WeaponFired()) [2nd]
          AudioService.playSFX('shotgun_fire.wav')
            └─ Player[0] still playing!
            └─ Find next stopped player: Player[1]
               ├─ shotgun sound STARTS ────┐
               │                          │
               │ ┌─ shotgun sound 1 continues playing ┘


T=200ms:  Another shot
          weaponBloc.add(WeaponFired()) [3rd]
          AudioService.playSFX('shotgun_fire.wav')
            └─ Players [0], [1] still playing!
            └─ Find next: Player[2]
               │          │────┐
               │ ┌──────────────┐
               │ │  shotgun 1   │  3rd shotgun STARTS
               │ │  shotgun 2   │
               │ │  shotgun 3   │
               └─┴──────────────┘

AUDIO RESULT (Stereo Mix):
  └─ All 3 shots overlap in stereo
  └─ Total volume ≈ 0.9 (loud!)  [But not distorted due to pool]
  └─ Players auto-return to STOPPED state after ~150ms
  └─ Pool expands if needed (never lost audio)


Pool Memory:
Initial:  'shotgun_fire.wav' → [Player[0], Player[1]]
After 3x: 'shotgun_fire.wav' → [Player[0], Player[1], Player[2]]
         (auto-expanded to 3 to handle burst)
```

---

## 7. VOLUME HIERARCHY

```
┌─────────────────────────────────────────────────────┐
│ Device Hardware Volume                              │
│ (0% ────────────────────────────────────── 100%)   │
│                    ↑                                │
│              Master Volume                          │
│              (_masterVolume = 1.0)                 │
│              ×────────────────────────────×         │
│              ↓                            ↓         │
│   ┌──────────────────┐   ┌──────────────────┐     │
│   │ Music Sub-mixer  │   │  SFX Sub-mixer   │     │
│   │(_musicVolume)    │   │(_sfxVolume)      │     │
│   │  = 0.6 (60%)     │   │  = 0.8 (80%)     │     │
│   │  ↓               │   │  ↓               │     │
│   ├─ Background.mp3  │   ├─ pistol_fire     │     │
│   │  @ 60%           │   │  @ 64%            │     │
│   │  (0.6 * 1.0)     │   │  (0.8 * 0.8)      │     │
│   │                  │   │                  │     │
│   └──────────────────┘   ├─ shotgun_fire    │     │
│                          │  @ 72%            │     │
│                          │  (0.9 * 0.8)      │     │
│                          │                  │     │
│                          ├─ reload           │     │
│                          │  @ 56%            │     │
│                          │  (0.7 * 0.8)      │     │
│                          │                  │     │
│                          └──────────────────┘     │
│                                                     │
│  If Master suddenly set to 0.5:                    │
│   └─ Music: 60% × 50% = 30%                      │
│   └─ SFX:   64% × 50% = 32%                      │
│   └─ All audio reduced proportionally             │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## 8. LIFECYCLE: Init → Play → Cleanup

```
┌─────────────────────────────────────────────────────┐
│ APPLICATION STARTED                                 │
└─────────────────────────────────────────┬───────────┘
                                          ↓
┌─────────────────────────────────────────────────────┐
│ bootstrap() → runApp()                              │
│ →  AppView → MaterialApp → MenuPage                │
│                                                     │
│ MenuPage._initAudio()                              │
│ ├─ _audioPlayer = AudioPlayer()  (isolated for menu)
│ ├─ Load: 'audio/menu_music.ogg'                   │
│ ├─ Fade in: 0.0 → 0.5 (2 seconds)                │
│ └─ State: PLAYING (in background)                │
└─────────────────────────────────────────┬───────────┘
                                          ↓
┌─────────────────────────────────────────────────────┐
│ USER PRESSES "PLAY"                                 │
│                                                     │
│ MenuPage._handleMenuAction(0)                      │
│ ├─ _audioPlayer.stop()  ← Stop menu music         │
│ └─ Navigator.pushReplacement(GamePage)            │
└─────────────────────────────────────────┬───────────┘
                                          ↓
┌─────────────────────────────────────────────────────┐
│ GAME PAGE BUILD                                     │
│                                                     │
│ MultiBlocProvider:                                  │
│ ├─ WeaponBloc(audioService: AudioService())        │
│ └─ (Singleton created here, shared globally)      │
│                                                     │
│ Load Screen → Generate World                       │
│ RaycastingGame(all blocs)                          │
└─────────────────────────────────────────┬───────────┘
                                          ↓
┌─────────────────────────────────────────────────────┐
│ RAYCASTING GAME ONLOAD ✨                          │
│                                                     │
│ ├─ ShaderManager.load()                            │
│ ├─ super.onLoad()                                  │
│ ├─ AudioService().init()                           │
│ │   └─ _isInitialized = true                      │
│ ├─ AudioService().playBackgroundMusic(...)         │
│ │   ├─ Create _backgroundMusic player              │
│ │   ├─ Load: 'audio/background.mp3'               │
│ │   ├─ Fade in: 0.0 → 0.6 (1500ms)               │
│ │   └─ _backgroundMusic.state = PLAYING           │
│ │                                                   │
│ ├─ RaycastRenderer setup (with WeaponBloc link)   │
│ └─ Mobile controls setup                           │
│                                                     │
│ AUDIO STATE:                                        │
│ ├─ Background Player: PLAYING (loops forever)     │
│ ├─ SFX Pools: Empty (created lazily)              │
│ └─ Ready for weapon sounds                         │
└─────────────────────────────────────────┬───────────┘
                                          ↓
┌─────────────────────────────────────────────────────┐
│ GAME LOOP (60 Hz Update) ← runs 60×/sec           │
│                                                     │
│ ├─ Input processing                                │
│ ├─ WeaponBloc SFX triggers (as above)             │
│ ├─ Background music continues (no action needed)  │
│ ├─ Render frame                                   │
│ └─ Repeat...                                       │
│                                                     │
│ AudioService Internal State (unchanged):           │
│ ├─ _backgroundMusic still PLAYING                 │
│ ├─ _sfxPools grow from repeated use               │
│ │  (e.g., after 10 shots: [P1, P2, ...])         │
│ └─ No audio cleanup happens                       │
└─────────────────────────────────────────┬───────────┘
                                          ↓
┌─────────────────────────────────────────────────────┐
│ USER PRESSES ESC / VICTORY SCREEN                   │
│                                                     │
│ LevelBloc status → victory                         │
│ Navigator shows VictoryScreen                      │
│ RaycastingGame.onDetach() is called ✨            │
└─────────────────────────────────────────┬───────────┘
                                          ↓
┌─────────────────────────────────────────────────────┐
│ CLEANUP (onDetach) ✨                              │
│                                                     │
│ ├─ _worldEffectsSub?.cancel()                      │
│ ├─ AudioService().stopBackgroundMusic(300ms)      │
│ │   ├─ Fade out: 0.6 → 0.0 (300ms)               │
│ │   ├─ _backgroundMusic.stop()                    │
│ │   ├─ _backgroundMusic.dispose()                 │
│ │   └─ _backgroundMusic = null                    │
│ │                                                   │
│ │   NOTE: SFX pools left as-is (could call         │
│ │         dispose() but not critical for one game) │
│ │                                                   │
│ └─ super.onDetach()                                │
│                                                     │
│ AUDIO RESULT:                                       │
│ └─ Music stops gracefully (not abrupt)             │
│    SFX pools freed on next AudioService use      │
└─────────────────────────────────────────┬───────────┘
                                          ↓
┌─────────────────────────────────────────────────────┐
│ BACK TO MENU                                        │
│                                                     │
│ MenuPage again                                      │
│ → _initAudio() runs → menu music fades in          │
│                                                     │
│ Loop can restart (NEW AudioService or reuse)      │
└─────────────────────────────────────────────────────┘
```

---

**Done!** 🎉 Full integration ready to test. Compile and press fire to hear the weapons! 🔊

import 'dart:async';
import 'dart:math' as math;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_bloc/flame_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'; // For KeyEventResult
import 'package:vector_math/vector_math_64.dart' as v64;
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/foundation.dart'; // For defaultTargetPlatform
import 'dart:io'; // For Platform check

import 'package:raycasting_game/features/core/input/action_mapper.dart';
import 'package:raycasting_game/features/core/input/bloc/input_bloc.dart';
import 'package:raycasting_game/features/core/input/models/game_action.dart';
import 'package:raycasting_game/features/core/level/bloc/bloc.dart';
import 'package:raycasting_game/features/core/perspective/bloc/perspective_bloc.dart';
import 'package:raycasting_game/features/core/world/bloc/world_bloc.dart';
import 'package:raycasting_game/features/game/bloc/bloc.dart';
import 'package:raycasting_game/features/game/render/raycast_renderer.dart';
import 'package:raycasting_game/features/game/render/shader_manager.dart';
import 'package:raycasting_game/features/game/systems/physics_system.dart';
import 'package:raycasting_game/features/game/weapon/bloc/weapon_bloc.dart';
import 'package:raycasting_game/features/game/weapon/models/weapon.dart';

class RaycastingGame extends FlameGame with KeyboardEvents {
  RaycastingGame({
    required this.gameBloc,
    required this.worldBloc,
    required this.inputBloc,
    required this.perspectiveBloc,
    required this.weaponBloc,
    required this.levelBloc,
  }) : super();

  final GameBloc gameBloc;
  final WorldBloc worldBloc;
  final InputBloc inputBloc;
  final PerspectiveBloc perspectiveBloc;
  final WeaponBloc weaponBloc;
  final LevelBloc levelBloc;

  RaycastRenderer? _renderer;
  // DamageFlashComponent removed — see game_hud.dart

  /// StreamSubscription for world effects — must be cancelled on dispose
  StreamSubscription<WorldState>? _worldEffectsSub;

  // Mobile Controls
  JoystickComponent? _joystick;
  HudButtonComponent? _fireButton;
  HudButtonComponent? _reloadButton;
  HudButtonComponent? _switchWeaponButton;

  /// Sync flag for the touch fire button.
  /// Using a bool instead of InputBloc avoids the async-Bloc-vs-sync-update
  /// timing gap where onPressed emits an event but the Bloc hasn't processed
  /// it yet by the time _processInput reads inputBloc.state in the same tick.
  bool _touchFireHeld = false;

  @override
  Future<void> onLoad() async {
    await ShaderManager.load();
    await super.onLoad();

    // Initialize World
    worldBloc.add(const WorldInitialized(width: 32, height: 32));

    final renderer = RaycastRenderer();
    _renderer = renderer;

    await add(
      FlameBlocProvider<GameBloc, GameState>.value(
        value: gameBloc,
        children: [
          FlameBlocProvider<WorldBloc, WorldState>.value(
            value: worldBloc,
            children: [
              FlameBlocProvider<PerspectiveBloc, PerspectiveState>.value(
                value: perspectiveBloc,
                children: [
                  FlameBlocProvider<WeaponBloc, WeaponState>.value(
                    value: weaponBloc,
                    children: [
                      renderer,
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    // Listen for Game State changes
    // gameBloc.stream.listen((state) async {
    //   if (state.status == GameStatus.gameOver) {
    //     await add(GameOverOverlay());
    //   }
    // });

    // Listen for World Effects (Sound, Damage, etc.)
    // Stored so it can be cancelled in onRemove and avoids EngineFlutterView disposed assertion.
    _worldEffectsSub = worldBloc.stream.listen((worldState) {
      if (worldState.effects.isNotEmpty) {
        for (final effect in worldState.effects) {
          if (effect is PlayerDamagedEffect) {
            gameBloc.add(PlayerDamaged(effect.amount));
          } else if (effect is EnemyKilledEffect) {
            levelBloc.add(const EnemyKilledRegistered());
          } else if (effect is BounceEffect) {
            _renderer?.spawnBounceEffect(
                v64.Vector2(effect.position.x, effect.position.y));
          } else if (effect is WallHitEffect) {
            _renderer?.spawnWallDecal(
                v64.Vector2(effect.position.x, effect.position.y));
          } else if (effect is AmmoPickedUpEffect) {
            weaponBloc.add(
              AmmoAdded(ammoType: effect.ammoType, amount: effect.quantity),
            );
          }
        }
      }
    });

    // Initialize Mobile Controls AFTER the game world so they render on top
    // (Flame renders equal-priority siblings in insertion order: later = on top).
    // Additionally all controls use priority:10 > FlameBlocProvider default 0.
    await _initMobileControls();
  }

  @override
  void onDetach() {
    // Cancel the stream subscription to avoid rendering on a disposed EngineFlutterView
    _worldEffectsSub?.cancel();
    _worldEffectsSub = null;
    super.onDetach();
  }

  bool _isMobile() {
    if (kIsWeb) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    return true;
  }

  Future<void> _initMobileControls() async {
    // ── Left joystick — Y = move forward/back, X = camera turn ───────────
    _joystick = JoystickComponent(
      knob: CircleComponent(
          radius: 28, paint: Paint()..color = const Color(0xAAFFFFFF)),
      background: CircleComponent(
          radius: 62, paint: Paint()..color = const Color(0x44FFFFFF)),
      margin: const EdgeInsets.only(left: 48, bottom: 48),
      priority: 10,
    );
    await add(_joystick!);

    // ── Fire button — bottom-center-right, left of minimap ─────────────
    // Minimap occupies bottom:16–166, right:16–166. All buttons use right>166
    // so they sit to the LEFT of the minimap and never overlap it.
    _fireButton = HudButtonComponent(
      button: CircleComponent(
        radius: 42,
        paint: Paint()..color = const Color(0xAAFF2200),
      ),
      margin: const EdgeInsets.only(right: 196, bottom: 24),
      priority: 10,
      onPressed: () => _touchFireHeld = true,
      onReleased: () => _touchFireHeld = false,
    );
    await add(_fireButton!);

    // ── Reload button — same row as fire, further left ───────────────────
    // Fire left-edge is at right:280 (196+84); reload right-edge at right:300 → 20px gap.
    _reloadButton = HudButtonComponent(
      button: CircleComponent(
        radius: 26,
        paint: Paint()..color = const Color(0xAA0088FF),
      ),
      margin: const EdgeInsets.only(right: 300, bottom: 24),
      priority: 10,
      onPressed: () => weaponBloc.add(const WeaponReloaded()),
      onReleased: () {},
    );
    await add(_reloadButton!);

    // ── Weapon cycle — above fire button, same column ────────────────────
    // Fire top-edge is at bottom:108 (24+84); switch bottom-edge at bottom:124 → 16px gap.
    _switchWeaponButton = HudButtonComponent(
      button: CircleComponent(
        radius: 22,
        paint: Paint()..color = const Color(0xAA00CC66),
      ),
      margin: const EdgeInsets.only(right: 196, bottom: 124),
      priority: 10,
      onPressed: () {
        const all = [Weapon.pistol, Weapon.shotgun, Weapon.rifle,
                     Weapon.bouncePistol, Weapon.bounceRifle];
        final cur = weaponBloc.state.currentWeapon;
        weaponBloc.add(WeaponSwitched(all[(all.indexOf(cur) + 1) % all.length]));
      },
      onReleased: () {},
    );
    await add(_switchWeaponButton!);
  }

  void _spawnMuzzleFlash(v64.Vector2 position, double direction) {
    _renderer?.spawnMuzzleFlash(position, direction);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Tick the survival timer every frame
    levelBloc.add(SurvivalTick(dt));

    worldBloc.add(WorldTick(dt));
    if (!worldBloc.state.isPlayerDead) {
      _processInput(dt);
    }
  }

  void _processInput(double dt) {
    if (worldBloc.state.isPlayerDead) return;

    final inputState = inputBloc.state;
    var moveStep = 0.0;
    var strafeStep = 0.0;
    var rotStep = 0.0;

    // Movement
    if (inputState.isPressed(GameAction.moveForward)) moveStep += 1.0;
    if (inputState.isPressed(GameAction.moveBackward)) moveStep -= 1.0;
    if (inputState.isPressed(GameAction.strafeLeft)) strafeStep -= 1.0;
    if (inputState.isPressed(GameAction.strafeRight)) strafeStep += 1.0;

    // Rotation
    if (inputState.isPressed(GameAction.lookLeft)) rotStep -= 1.0;
    if (inputState.isPressed(GameAction.lookRight)) rotStep += 1.0;

    // Analog Input from Joystick
    if (_joystick != null) {
      // Joystick delta is normalized (0 to 1)
      // Standard fps controls:
      // UP/DOWN -> Move Forward/Backward
      // LEFT/RIGHT -> Turn Left/Right (or Strafe if preferred)
      // Usually mobile FPS use two sticks. One for move, one for look.
      // With single stick, we can do:
      // Y -> Move
      // X -> Turn

      final joyDelta = _joystick!.relativeDelta;
      // Deadzone
      if (joyDelta.length > 0.1) {
        // Forward is negative Y in screen/joystick coordinates usually?
        // Let's check. Joystick up is usually negative Y.
        // So -Y is forward.
        moveStep += -joyDelta.y;
        rotStep += joyDelta.x * 2.0; // Turn faster with joystick
      }
    }

    // Handle shooting — _touchFireHeld is a sync bool set by the HUD button
    // (InputBloc routes are async and would miss single-frame taps).
    if (_touchFireHeld || inputState.isPressed(GameAction.fire)) {
      if (weaponBloc.state.canFire) {
        final currentWeapon = weaponBloc.state.currentWeapon;

        // 1. Update Weapon State (Ammo/Cooldown)
        weaponBloc.add(const WeaponFired());

        // 2. Notify World (Handles hitscan/projectiles and damage)
        worldBloc.add(PlayerFired(currentWeapon));

        // 3. Visuals (Muzzle flash)
        final playerPos = worldBloc.state.effectivePosition;
        final playerDir = worldBloc.state.playerDirection;
        final flashPos =
            playerPos +
            v64.Vector2(math.cos(playerDir) * 0.5, math.sin(playerDir) * 0.5);
        _spawnMuzzleFlash(flashPos, playerDir);
      }
    }

    if (inputState.isPressed(GameAction.reload)) {
      weaponBloc.add(const WeaponReloaded());
    }

    if (moveStep != 0 || strafeStep != 0 || rotStep != 0) {
      final currentRot = worldBloc.state.playerDirection;
      final currentPos = worldBloc.state.effectivePosition;

      const moveSpeed = 4.0;
      const rotSpeed = 2.5;

      final newRot = currentRot + (rotStep * rotSpeed * dt);
      final dirX = math.cos(newRot);
      final dirY = math.sin(newRot);

      final moveVec = v64.Vector2(dirX, dirY) * (moveStep * moveSpeed);
      final strafeVec = v64.Vector2(-dirY, dirX) * (strafeStep * moveSpeed);
      final velocity = moveVec + strafeVec;

      final map = worldBloc.state.map;

      // Use PhysicsSystem for movement (handles walls AND entities)
      final finalPos = PhysicsSystem.tryMove(
        'player',
        currentPos,
        velocity,
        dt,
        map,
        worldBloc.state.entities,
        radius: 0.3,
      );

      worldBloc.add(PlayerMoved(position: finalPos, direction: newRot));
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final action = ActionMapper.getAction(event.logicalKey);
    if (action == null) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      if (action == GameAction.togglePerspective) {
        perspectiveBloc.add(const PerspectiveToggled());
      }

      // Weapon Switching
      if (action == GameAction.switchWeapon1) {
        weaponBloc.add(const WeaponSwitched(Weapon.pistol));
      }
      if (action == GameAction.switchWeapon2) {
        weaponBloc.add(const WeaponSwitched(Weapon.shotgun));
      }
      if (action == GameAction.switchWeapon3) {
        weaponBloc.add(const WeaponSwitched(Weapon.rifle));
      }
      if (action == GameAction.switchWeapon4) {
        weaponBloc.add(const WeaponSwitched(Weapon.bouncePistol));
      }
      if (action == GameAction.switchWeapon5) {
        weaponBloc.add(const WeaponSwitched(Weapon.bounceRifle));
      }

      inputBloc.add(ActionStarted(action));
      return KeyEventResult.handled;
    } else if (event is KeyUpEvent) {
      inputBloc.add(ActionEnded(action));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

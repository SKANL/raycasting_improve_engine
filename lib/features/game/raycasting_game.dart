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
  HudButtonComponent? _switchWeaponButton;

  @override
  Future<void> onLoad() async {
    await ShaderManager.load();
    await super.onLoad();

    // Initialize World
    worldBloc.add(const WorldInitialized(width: 32, height: 32));

    final renderer = RaycastRenderer();
    _renderer = renderer;

    // Initialize Mobile Controls if on mobile
    if (_isMobile()) {
      await _initMobileControls();
    }

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
          }
        }
      }
    });

    // Start with fully restored health
    // gameBloc.add(GameReset());
  }

  @override
  void onDetach() {
    // Cancel the stream subscription to avoid rendering on a disposed EngineFlutterView
    _worldEffectsSub?.cancel();
    _worldEffectsSub = null;
    super.onDetach();
  }

  bool _isMobile() {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> _initMobileControls() async {
    final knobPaint = Paint()..color = const Color(0x80FFFFFF);
    final backgroundPaint = Paint()..color = const Color(0x40FFFFFF);

    _joystick = JoystickComponent(
      knob: CircleComponent(radius: 20, paint: knobPaint),
      background: CircleComponent(radius: 50, paint: backgroundPaint),
      margin: const EdgeInsets.only(left: 40, bottom: 40),
    );
    await add(_joystick!);

    // Fire Button
    _fireButton = HudButtonComponent(
      button: CircleComponent(
        radius: 30,
        paint: Paint()..color = const Color(0x80FF0000),
      ),
      margin: const EdgeInsets.only(right: 40, bottom: 60),
      onPressed: () {
        inputBloc.add(const ActionStarted(GameAction.fire));
      },
      onReleased: () {
        inputBloc.add(const ActionEnded(GameAction.fire));
      },
    );
    await add(_fireButton!);

    // Weapon Switch Button (Cycle)
    _switchWeaponButton = HudButtonComponent(
      button: CircleComponent(
        radius: 20,
        paint: Paint()..color = const Color(0x8000FF00),
      ),
      margin: const EdgeInsets.only(right: 40, bottom: 140),
      onPressed: () {
        // Simple cycling logic or specific weapon switch
        // For now, let's just cycle to next available
        // Or maybe just switch to shotgun for testing
        weaponBloc.add(const WeaponSwitched(Weapon.shotgun));
      },
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

    // Handle shooting
    if (inputState.isPressed(GameAction.fire)) {
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

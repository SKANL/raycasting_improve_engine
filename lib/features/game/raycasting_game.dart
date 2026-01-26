import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_bloc/flame_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'; // For KeyEventResult
import 'package:raycasting_game/features/core/input/action_mapper.dart';
import 'package:raycasting_game/features/core/input/bloc/input_bloc.dart';
import 'package:raycasting_game/features/core/input/models/game_action.dart';
import 'package:raycasting_game/features/core/perspective/bloc/perspective_bloc.dart';
import 'package:raycasting_game/features/core/world/bloc/world_bloc.dart';
import 'package:raycasting_game/features/core/world/models/game_map.dart';
import 'package:raycasting_game/features/game/bloc/bloc.dart';
import 'package:raycasting_game/features/game/render/raycast_renderer.dart';
import 'package:raycasting_game/features/game/render/shader_manager.dart';
import 'package:raycasting_game/features/game/weapon/bloc/weapon_bloc.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

class RaycastingGame extends FlameGame with KeyboardEvents {
  RaycastingGame({
    required this.gameBloc,
    required this.worldBloc,
    required this.inputBloc,
    required this.perspectiveBloc,
    required this.weaponBloc,
  }) : super();

  final GameBloc gameBloc;
  final WorldBloc worldBloc;
  final InputBloc inputBloc;
  final PerspectiveBloc perspectiveBloc;
  final WeaponBloc weaponBloc;

  RaycastRenderer? _renderer;

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
  }

  void _spawnMuzzleFlash(v64.Vector2 position, double direction) {
    _renderer?.spawnMuzzleFlash(position, direction);
  }

  @override
  void update(double dt) {
    super.update(dt);
    worldBloc.add(WorldTick(dt));
    _processInput(dt);
  }

  void _processInput(double dt) {
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

    // Handle shooting
    if (inputState.isPressed(GameAction.fire)) {
      weaponBloc.add(const WeaponFired());
      if (weaponBloc.state.canFire) {
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

      final moveVec = v64.Vector2(dirX, dirY) * (moveStep * moveSpeed * dt);
      final strafeVec =
          v64.Vector2(-dirY, dirX) * (strafeStep * moveSpeed * dt);
      final totalMove = moveVec + strafeVec;

      final map = worldBloc.state.map;
      var finalPos = currentPos.clone();

      if (map != null) {
        final nextX = currentPos.x + totalMove.x;
        if (!_isSolid(map, nextX + 0.2 * totalMove.x.sign, currentPos.y))
          finalPos.x = nextX;
        final nextY = currentPos.y + totalMove.y;
        if (!_isSolid(map, finalPos.x, nextY + 0.2 * totalMove.y.sign))
          finalPos.y = nextY;
      } else {
        finalPos = currentPos + totalMove;
      }

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
      if (action == GameAction.togglePerspective)
        perspectiveBloc.add(const PerspectiveToggled());
      inputBloc.add(ActionStarted(action));
      return KeyEventResult.handled;
    } else if (event is KeyUpEvent) {
      inputBloc.add(ActionEnded(action));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _isSolid(GameMap map, double x, double y) =>
      map.getCell(x.floor(), y.floor()).isSolid;
}

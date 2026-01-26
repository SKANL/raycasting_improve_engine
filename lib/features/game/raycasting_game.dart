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
import 'package:vector_math/vector_math_64.dart' as v64;

class RaycastingGame extends FlameGame with KeyboardEvents {
  RaycastingGame({
    required this.gameBloc,
    required this.worldBloc,
    required this.inputBloc,
    required this.perspectiveBloc,
  }) : super();

  final GameBloc gameBloc;
  final WorldBloc worldBloc;
  final InputBloc inputBloc;
  final PerspectiveBloc perspectiveBloc;

  @override
  Future<void> onLoad() async {
    await ShaderManager.load();
    await super.onLoad();

    // Initialize World if not already?
    // Usually via Bloc but we can do it here for now to be sure map exists.
    worldBloc.add(const WorldInitialized(width: 32, height: 32));

    // We inject blocs into the Flame component tree
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
                  RaycastRenderer(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
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
    var rotStep = 0.0;

    if (inputState.isPressed(GameAction.moveForward)) {
      moveStep += 1.0;
    }
    if (inputState.isPressed(GameAction.moveBackward)) {
      moveStep -= 1.0;
    }
    if (inputState.isPressed(GameAction.strafeLeft)) {
      rotStep -= 1.0;
    }
    if (inputState.isPressed(GameAction.strafeRight)) {
      rotStep += 1.0;
    }
    if (inputState.isPressed(GameAction.lookLeft)) {
      rotStep -= 1.0;
    }
    if (inputState.isPressed(GameAction.lookRight)) {
      rotStep += 1.0;
    }

    if (moveStep != 0 || rotStep != 0) {
      final currentRot = worldBloc.state.playerDirection;
      final currentPos = worldBloc.state.effectivePosition;

      // Adjust speed by dt for frame-rate independence
      const moveSpeed = 3.0; // Units per second
      const rotSpeed = 2.0; // Radians per second

      final newRot = currentRot + (rotStep * rotSpeed * dt);
      final dirX = math.cos(newRot);
      final dirY = math.sin(newRot);

      final moveVec = v64.Vector2(dirX, dirY) * (moveStep * moveSpeed * dt);

      // Collision Detection
      final map = worldBloc.state.map;
      var finalPos = currentPos.clone();

      if (map != null) {
        final nextX = currentPos.x + moveVec.x;
        final margin = 0.2 * (moveVec.x.sign);
        if (!_isSolid(map, nextX + margin, currentPos.y)) {
          finalPos.x = nextX;
        }

        final nextY = currentPos.y + moveVec.y;
        final marginY = 0.2 * (moveVec.y.sign);
        if (!_isSolid(map, finalPos.x, nextY + marginY)) {
          finalPos.y = nextY;
        }
      } else {
        finalPos = currentPos + moveVec;
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
      if (action == GameAction.togglePerspective) {
        perspectiveBloc.add(const PerspectiveToggled());
      }
      inputBloc.add(ActionStarted(action));
      return KeyEventResult.handled;
    } else if (event is KeyUpEvent) {
      inputBloc.add(ActionEnded(action));
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool _isSolid(GameMap map, double x, double y) {
    return map.getCell(x.floor(), y.floor()).isSolid;
  }
}

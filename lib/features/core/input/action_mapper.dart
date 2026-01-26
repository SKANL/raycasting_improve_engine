import 'package:flutter/services.dart';
import 'package:raycasting_game/features/core/input/models/game_action.dart';

/// Helper class to map physical keys to semantic actions.
class ActionMapper {
  static final Map<LogicalKeyboardKey, GameAction> defaultKeyMap = {
    // Movement
    LogicalKeyboardKey.keyW: GameAction.moveForward,
    LogicalKeyboardKey.keyS: GameAction.moveBackward,
    LogicalKeyboardKey.keyA: GameAction.strafeLeft,
    LogicalKeyboardKey.keyD: GameAction.strafeRight,
    LogicalKeyboardKey.arrowUp: GameAction.moveForward,
    LogicalKeyboardKey.arrowDown: GameAction.moveBackward,
    LogicalKeyboardKey.arrowLeft: GameAction.lookLeft,
    LogicalKeyboardKey.arrowRight: GameAction.lookRight,

    // Interaction
    LogicalKeyboardKey.space: GameAction.fire,
    LogicalKeyboardKey.keyE: GameAction.interact,
    LogicalKeyboardKey.keyR: GameAction.reload,

    // System
    LogicalKeyboardKey.tab: GameAction.togglePerspective,
    LogicalKeyboardKey.escape: GameAction.pause,
    LogicalKeyboardKey.f3: GameAction.toggleDebug,
  };

  /// Returns the action associated with [key], or null if none.
  static GameAction? getAction(LogicalKeyboardKey key) {
    return defaultKeyMap[key];
  }
}

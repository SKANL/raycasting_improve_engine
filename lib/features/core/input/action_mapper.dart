import 'package:flutter/services.dart';
import 'package:raycasting_game/features/core/input/models/game_action.dart';

/// Helper class to map physical keys to semantic actions.
class ActionMapper {
  static final Map<LogicalKeyboardKey, GameAction> defaultKeyMap = {
    // Movement & Looking
    LogicalKeyboardKey.keyW: GameAction.moveForward,
    LogicalKeyboardKey.keyS: GameAction.moveBackward,
    LogicalKeyboardKey.keyA: GameAction.lookLeft,
    LogicalKeyboardKey.keyD: GameAction.lookRight,
    LogicalKeyboardKey.arrowUp: GameAction.moveForward,
    LogicalKeyboardKey.arrowDown: GameAction.moveBackward,
    LogicalKeyboardKey.arrowLeft: GameAction.lookLeft,
    LogicalKeyboardKey.arrowRight: GameAction.lookRight,

    // Interaction
    LogicalKeyboardKey.space: GameAction.fire,
    LogicalKeyboardKey.keyE: GameAction.interact,
    LogicalKeyboardKey.keyR: GameAction.reload,

    // Weapon Switching
    LogicalKeyboardKey.digit1: GameAction.switchWeapon1,
    LogicalKeyboardKey.numpad1: GameAction.switchWeapon1,
    LogicalKeyboardKey.digit2: GameAction.switchWeapon2,
    LogicalKeyboardKey.numpad2: GameAction.switchWeapon2,
    LogicalKeyboardKey.digit3: GameAction.switchWeapon3,
    LogicalKeyboardKey.numpad3: GameAction.switchWeapon3,
    LogicalKeyboardKey.digit4: GameAction.switchWeapon4,
    LogicalKeyboardKey.numpad4: GameAction.switchWeapon4,
    LogicalKeyboardKey.digit5: GameAction.switchWeapon5,
    LogicalKeyboardKey.numpad5: GameAction.switchWeapon5,

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

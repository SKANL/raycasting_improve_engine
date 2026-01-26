/// Semantically meaningful actions that a player can perform.
///
/// These actions are decoupled from physical inputs (keyboard keys, touch gestures, gamepads).
enum GameAction {
  // --- Movement ---
  /// Move forward relative to camera.
  moveForward,

  /// Move backward relative to camera.
  moveBackward,

  /// Move left (strafe) relative to camera.
  strafeLeft,

  /// Move right (strafe) relative to camera.
  strafeRight,

  /// Turn left (rotate player).
  turnLeft,

  /// Turn right (rotate player).
  turnRight,

  // --- Camera ---
  /// Rotate camera left.
  lookLeft,

  /// Rotate camera right.
  lookRight,

  /// Look up (for 3D view usually).
  lookUp,

  /// Look down (for 3D view usually).
  lookDown,

  // --- Interaction ---
  /// Interact with object in front (open door, press switch).
  interact,

  /// Fire primary weapon.
  fire,

  /// Reload weapon.
  reload,

  // --- System ---
  /// Toggle between perspective views (3D, 2D, Iso).
  togglePerspective,

  /// Pause the game / Open menu.
  pause,

  /// Toggle debug information (minimap, stats).
  toggleDebug,
}

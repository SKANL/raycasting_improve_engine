/// AI behavior states for enemy entities
enum AIState {
  /// Wandering or following waypoints
  patrol,

  /// Moving toward player after detection
  chase,

  /// In range, attacking player
  attack,
}

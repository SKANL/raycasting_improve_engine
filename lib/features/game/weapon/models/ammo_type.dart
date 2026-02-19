/// Defines the type of ammunition a weapon fires.
enum AmmoType {
  /// Standard bullet: travels in a straight line, disappears on hit or max range.
  normal,

  /// Bouncing bullet: reflects off walls using vector reflection.
  /// Loses [ProjectileSystem.bounceFactor] energy per bounce.
  bouncing,
}

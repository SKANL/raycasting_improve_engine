import 'package:equatable/equatable.dart';
import 'package:raycasting_game/features/game/weapon/models/ammo_type.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

/// A physical projectile traveling through the world.
///
/// Used for bouncing bullets and enemy attacks.
/// Each game tick, [ProjectileSystem] updates all active projectiles.
class Projectile extends Equatable {
  const Projectile({
    required this.id,
    required this.ownerId,
    required this.position,
    required this.velocity,
    required this.damage,
    this.ammoType = AmmoType.normal,
    this.bouncesLeft = 0,
    this.maxRange = 30.0,
    this.distanceTraveled = 0.0,
    this.isEnemy = false,
    this.isVisualOnly = false,
  });

  /// Unique projectile identifier (UUID)
  final String id;

  /// ID of the entity that fired this projectile (prevents self-damage)
  final String ownerId;

  /// Current world position
  final v64.Vector2 position;

  /// Current velocity vector (direction × speed in world-units/sec)
  final v64.Vector2 velocity;

  /// Damage applied on entity hit
  final int damage;

  /// Whether this bullet bounces off walls
  final AmmoType ammoType;

  /// How many bounces remain before the projectile is destroyed
  final int bouncesLeft;

  /// Maximum total distance before the projectile despawns
  final double maxRange;

  /// Distance traveled so far (for range check)
  final double distanceTraveled;

  /// True if fired by an enemy (used to prevent enemy-vs-enemy damage)
  final bool isEnemy;

  /// True if this projectile is purely visual (tracer) and causes no damage/collision.
  final bool isVisualOnly;

  bool get isBouncing => ammoType == AmmoType.bouncing && bouncesLeft > 0;

  Projectile copyWith({
    String? id,
    String? ownerId,
    v64.Vector2? position,
    v64.Vector2? velocity,
    int? damage,
    AmmoType? ammoType,
    int? bouncesLeft,
    double? maxRange,
    double? distanceTraveled,
    bool? isEnemy,
    bool? isVisualOnly,
  }) {
    return Projectile(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      position: position ?? this.position,
      velocity: velocity ?? this.velocity,
      damage: damage ?? this.damage,
      ammoType: ammoType ?? this.ammoType,
      bouncesLeft: bouncesLeft ?? this.bouncesLeft,
      maxRange: maxRange ?? this.maxRange,
      distanceTraveled: distanceTraveled ?? this.distanceTraveled,
      isEnemy: isEnemy ?? this.isEnemy,
      isVisualOnly: isVisualOnly ?? this.isVisualOnly,
    );
  }

  @override
  List<Object?> get props => [
    id,
    ownerId,
    position,
    velocity,
    damage,
    ammoType,
    bouncesLeft,
    maxRange,
    distanceTraveled,
    isEnemy,
  ];
}

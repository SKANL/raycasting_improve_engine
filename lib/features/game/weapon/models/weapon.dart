import 'package:equatable/equatable.dart';
import 'package:raycasting_game/features/game/weapon/models/ammo_type.dart';

/// Weapon configuration and stats
class Weapon extends Equatable {
  const Weapon({
    required this.id,
    required this.name,
    required this.damage,
    required this.maxAmmo,
    required this.fireRate,
    required this.range,
    this.ammoType = AmmoType.normal,
    this.isHitscan = true,
    this.spreadAngle = 0.0,
    this.pellets = 1,
    this.projectileSpeed = 12.0,
    this.maxBounces = 0,
    this.muzzleFlashTextureIndex = 0,
  });

  /// Unique weapon identifier
  final String id;

  /// Display name
  final String name;

  /// Damage per shot (or per pellet for spread weapons)
  final int damage;

  /// Maximum ammunition capacity
  final int maxAmmo;

  /// Shots per second
  final double fireRate;

  /// Maximum effective range in world units (for hitscan)
  final double range;

  /// Type of ammo this weapon fires
  final AmmoType ammoType;

  /// True = instant DDA hitscan. False = physical projectile entity.
  final bool isHitscan;

  /// Half-angle spread in radians (0 = no spread). Used for shotgun pellets.
  final double spreadAngle;

  /// Number of pellets per shot (shotgun = 7)
  final int pellets;

  /// World-units per second for projectile weapons (isHitscan = false)
  final double projectileSpeed;

  /// Number of wall bounces before destruction (bouncing ammo only)
  final int maxBounces;

  /// Texture atlas index for muzzle flash particle
  final int muzzleFlashTextureIndex;

  /// Time between shots in seconds
  double get cooldown => 1.0 / fireRate;

  @override
  List<Object?> get props => [
    id,
    name,
    damage,
    maxAmmo,
    fireRate,
    range,
    ammoType,
    isHitscan,
    spreadAngle,
    pellets,
    projectileSpeed,
    maxBounces,
  ];

  // ─── Predefined Weapons ───────────────────────────────────────────────────

  /// Standard sidearm. Reliable, accurate, hitscan.
  static const pistol = Weapon(
    id: 'pistol',
    name: 'Pistol',
    damage: 10,
    maxAmmo: 12,
    fireRate: 2.0,
    range: 20.0,
    muzzleFlashTextureIndex: 0,
  );

  /// Wide spread, close-range devastation. 7 pellets per shot.
  static const shotgun = Weapon(
    id: 'shotgun',
    name: 'Shotgun',
    damage: 8,
    maxAmmo: 8,
    fireRate: 0.8,
    range: 10.0,
    pellets: 7,
    spreadAngle: 0.12, // ~7 degrees half-angle
    muzzleFlashTextureIndex: 1,
  );

  /// Fast automatic hitscan. Low spread, medium damage.
  static const rifle = Weapon(
    id: 'rifle',
    name: 'Rifle',
    damage: 30,
    maxAmmo: 30,
    fireRate: 5.0,
    range: 30.0,
    spreadAngle: 0.02,
    muzzleFlashTextureIndex: 2,
  );

  /// Fires a physical projectile that bounces off walls up to 3 times.
  static const bouncePistol = Weapon(
    id: 'bounce_pistol',
    name: 'Bounce Pistol',
    damage: 25,
    maxAmmo: 12,
    fireRate: 1.5,
    range: 40.0,
    ammoType: AmmoType.bouncing,
    isHitscan: false,
    projectileSpeed: 12.0,
    maxBounces: 3,
    muzzleFlashTextureIndex: 3,
  );

  /// Rapid-fire bouncing rifle. Bullets ricochet 5 times.
  static const bounceRifle = Weapon(
    id: 'bounce_rifle',
    name: 'Bounce Rifle',
    damage: 15,
    maxAmmo: 25,
    fireRate: 3.0,
    range: 50.0,
    ammoType: AmmoType.bouncing,
    isHitscan: false,
    projectileSpeed: 16.0,
    maxBounces: 5,
    muzzleFlashTextureIndex: 4,
  );
}

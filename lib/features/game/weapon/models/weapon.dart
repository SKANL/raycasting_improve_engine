import 'package:equatable/equatable.dart';

/// Weapon configuration and stats
class Weapon extends Equatable {
  const Weapon({
    required this.id,
    required this.name,
    required this.damage,
    required this.maxAmmo,
    required this.fireRate,
    required this.range,
    this.muzzleFlashTextureIndex = 0,
  });

  /// Unique weapon identifier
  final String id;

  /// Display name
  final String name;

  /// Damage per shot
  final int damage;

  /// Maximum ammunition capacity
  final int maxAmmo;

  /// Shots per second
  final double fireRate;

  /// Maximum effective range in world units
  final double range;

  /// Texture atlas index for muzzle flash particle
  final int muzzleFlashTextureIndex;

  /// Time between shots in seconds
  double get cooldown => 1.0 / fireRate;

  @override
  List<Object?> get props => [id, name, damage, maxAmmo, fireRate, range];

  /// Predefined weapons
  static const pistol = Weapon(
    id: 'pistol',
    name: 'Pistol',
    damage: 10,
    maxAmmo: 12,
    fireRate: 2.0,
    range: 20.0,
  );

  static const shotgun = Weapon(
    id: 'shotgun',
    name: 'Shotgun',
    damage: 50,
    maxAmmo: 8,
    fireRate: 0.8,
    range: 10.0,
  );
}

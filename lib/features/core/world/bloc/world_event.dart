part of 'world_bloc.dart';

/// Events that can occur in the game world.
sealed class WorldEvent extends Equatable {
  const WorldEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when the world should be initialized with a new map.
final class WorldInitialized extends WorldEvent {
  const WorldInitialized({
    required this.width,
    required this.height,
    this.seed,
  });

  /// Width of the map in cells.
  final int width;

  /// Height of the map in cells.
  final int height;

  /// Optional seed for reproducible generation.
  final int? seed;

  @override
  List<Object?> get props => [width, height, seed];
}

/// Triggered when the player moves or rotates.
final class PlayerMoved extends WorldEvent {
  const PlayerMoved({
    required this.position,
    required this.direction,
  });

  final Vector2 position;
  final double direction;

  @override
  List<Object?> get props => [position, direction];
}

/// Triggered when the player fires a weapon.
final class PlayerFired extends WorldEvent {
  const PlayerFired(this.weapon);

  final Weapon weapon;

  @override
  List<Object?> get props => [weapon];
}

/// Triggered when an entity's state changes.
final class EntityUpdated extends WorldEvent {
  const EntityUpdated({
    required this.entityId,
    required this.position,
    this.rotation,
  });

  final String entityId;
  final Vector2 position;
  final double? rotation;

  @override
  List<Object?> get props => [entityId, position, rotation];
}

/// Triggered when a cell in the map changes (e.g., door opens).
final class CellChanged extends WorldEvent {
  const CellChanged({
    required this.x,
    required this.y,
    required this.newCell,
  });

  final int x;
  final int y;
  final Cell newCell;

  @override
  List<Object?> get props => [x, y, newCell];
}

/// Triggered when a light source is added or updated.
final class LightUpdated extends WorldEvent {
  const LightUpdated({required this.light});

  final LightSource light;

  @override
  List<Object?> get props => [light];
}

/// Triggered when a light source is removed.
final class LightRemoved extends WorldEvent {
  const LightRemoved({required this.lightId});

  final String lightId;

  @override
  List<Object?> get props => [lightId];
}

/// Triggered periodically to update world/sim logic (e.g. lights).
final class WorldTick extends WorldEvent {
  const WorldTick(this.dt);
  final double dt;

  @override
  List<Object?> get props => [dt];
}

/// Triggered when a loud sound is emitted (e.g. gunshot).
final class SoundEmitted extends WorldEvent {
  const SoundEmitted({
    required this.source,
    required this.radius,
    required this.volume,
  });

  final Vector2 source;
  final double radius;
  final double volume;

  @override
  List<Object?> get props => [source, radius, volume];
}

/// Triggered when an entity takes damage.
final class EntityDamaged extends WorldEvent {
  const EntityDamaged({
    required this.entityId,
    required this.damage,
  });

  final String entityId;
  final int damage;

  @override
  List<Object?> get props => [entityId, damage];
}

/// Triggered when transitioning to a new level.
/// Disposes all current world textures and resets state to empty.
final class LevelCleanup extends WorldEvent {
  const LevelCleanup();
}

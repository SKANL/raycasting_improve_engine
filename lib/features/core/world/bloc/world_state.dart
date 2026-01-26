part of 'world_bloc.dart';

/// Represents the complete state of the game world.
///
/// This is the single source of truth for all world data.
/// All renderers (3D, 2D, Isometric) read from this state.
class WorldState extends Equatable {
  const WorldState({
    this.status = WorldStatus.initial,
    this.map,
    this.mapTexture,
    this.textureAtlas,
    this.spriteAtlas,
    this.entities = const [],
    this.lights = const [],
    this.playerPosition,
    this.playerDirection = 0.0,
    this.time = 0.0,
  });

  /// Creates an empty initial state.
  factory WorldState.empty() => const WorldState();

  /// Current status of the world.
  final WorldStatus status;

  /// The game map grid.
  final GameMap? map;

  /// Packed RGBA texture of the map for shader consumption.
  final ui.Image? mapTexture;

  /// Procedural texture atlas (walls, floors).
  final ui.Image? textureAtlas;

  /// Procedural sprite atlas (enemies, items).
  final ui.Image? spriteAtlas;

  /// All entities in the world (enemies, items, NPCs).
  final List<GameEntity> entities;

  /// All light sources in the world.
  final List<LightSource> lights;

  /// Player position in world coordinates.
  final Vector2? playerPosition;

  /// Player facing direction in radians.
  final double playerDirection;

  /// Elapsed game time for shader animations.
  final double time;

  /// Default spawn position if playerPosition is null.
  static final _defaultPosition = Vector2(1.5, 1.5);

  /// Returns player position, defaulting to spawn point if null.
  Vector2 get effectivePosition => playerPosition ?? _defaultPosition;

  /// Creates a copy with optional overrides.
  WorldState copyWith({
    WorldStatus? status,
    GameMap? map,
    ui.Image? mapTexture,
    ui.Image? textureAtlas,
    ui.Image? spriteAtlas,
    List<GameEntity>? entities,
    List<LightSource>? lights,
    Vector2? playerPosition,
    double? playerDirection,
    double? time,
  }) {
    return WorldState(
      status: status ?? this.status,
      map: map ?? this.map,
      mapTexture: mapTexture ?? this.mapTexture,
      textureAtlas: textureAtlas ?? this.textureAtlas,
      spriteAtlas: spriteAtlas ?? this.spriteAtlas,
      entities: entities ?? this.entities,
      lights: lights ?? this.lights,
      playerPosition: playerPosition ?? this.playerPosition,
      playerDirection: playerDirection ?? this.playerDirection,
      time: time ?? this.time,
    );
  }

  @override
  List<Object?> get props => [
    status,
    map,
    mapTexture,
    textureAtlas,
    spriteAtlas,
    entities,
    lights,
    playerPosition,
    playerDirection,
    time,
  ];
}

/// Status of the world simulation.
enum WorldStatus {
  /// World has not been initialized yet.
  initial,

  /// World is being generated.
  loading,

  /// World is active and running.
  active,

  /// World simulation is paused.
  paused,
}

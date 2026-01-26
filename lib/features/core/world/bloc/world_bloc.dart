import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:raycasting_game/core/logging/log_service.dart';
import 'package:raycasting_game/features/core/ecs/components/health_component.dart';
import 'package:raycasting_game/features/core/ecs/components/render_component.dart';
import 'package:raycasting_game/features/core/ecs/components/transform_component.dart';
import 'package:raycasting_game/features/core/ecs/models/component.dart';
import 'package:raycasting_game/features/core/world/models/game_entity.dart';
import 'package:raycasting_game/features/core/world/models/game_map.dart';
import 'package:raycasting_game/features/core/world/models/light_source.dart';
import 'package:raycasting_game/features/game/ai/components/ai_component.dart';
import 'package:raycasting_game/features/game/ai/systems/ai_system.dart';
import 'package:raycasting_game/features/game/utils/map_generator.dart';
import 'package:raycasting_game/features/game/utils/texture_generator.dart';
import 'package:raycasting_game/features/game/utils/texture_packer.dart';
import 'package:vector_math/vector_math_64.dart';

part 'world_event.dart';
part 'world_state.dart';

/// The core simulation bloc for the game world.
class WorldBloc extends Bloc<WorldEvent, WorldState> {
  WorldBloc() : super(WorldState.empty()) {
    on<WorldInitialized>(_onInitialized);
    on<PlayerMoved>(_onPlayerMoved);
    on<EntityUpdated>(_onEntityUpdated);
    on<CellChanged>(_onCellChanged);
    on<LightUpdated>(_onLightUpdated);
    on<LightRemoved>(_onLightRemoved);
    on<WorldTick>(_onWorldTick);
  }

  final AISystem _aiSystem = AISystem();

  Future<void> _onInitialized(
    WorldInitialized event,
    Emitter<WorldState> emit,
  ) async {
    emit(state.copyWith(status: WorldStatus.loading));

    // 1. Generate Procedural Map
    final map = MapGenerator.generate(event.width, event.height);

    // 2. Find valid spawn point & spawn entities
    var spawn = Vector2(1.5, 1.5);
    final entities = <GameEntity>[];

    var spawnFound = false;
    var enemiesToSpawn = 5;

    for (var y = 1; y < map.height - 1; y++) {
      for (var x = 1; x < map.width - 1; x++) {
        if (!map.grid[y][x].isSolid) {
          if (!spawnFound) {
            spawn = Vector2(x + 0.5, y + 0.5);
            spawnFound = true;
          } else if (enemiesToSpawn > 0 && (x + y) % 5 == 0) {
            // Create ECS components for Enemy
            final transform = TransformComponent(
              position: Vector2(x + 0.5, y + 0.5),
            );
            const render = RenderComponent(
              spritePath: 'enemy_grunt',
            );
            const health = HealthComponent(current: 100, max: 100);
            final ai = AIComponent(
              detectionRange: 8,
              attackRange: 2,
              moveSpeed: 1.5,
            );

            entities.add(
              GameEntity(
                id: 'enemy_$enemiesToSpawn',
                components: [transform, render, health, ai],
              ),
            );
            enemiesToSpawn--;
          }
        }
      }
    }

    // 3. Generate Textures
    final mapTexture = await TexturePacker.packMap(map);
    final textureAtlas = await TextureGenerator.generateAtlas();
    final spriteAtlas = await TextureGenerator.generateSpriteAtlas();

    LogService.info('WORLD', 'TEXTURES_GENERATED', {
      'mapTexture': mapTexture != null,
      'textureAtlas': textureAtlas != null,
      'spriteAtlas': spriteAtlas != null,
      'mapSize': '${map.width}x${map.height}',
    });

    // 4. Initial Lights
    final lights = [
      LightSource(
        id: 'spawn_light',
        position: ui.Offset(spawn.x, spawn.y),
        radius: 6,
        intensity: 0.8,
        color: const ui.Color(0xFFFFAA00),
        flickerSpeed: 1.5,
      ),
      // Player Flashlight
      LightSource(
        id: 'player_light',
        position: ui.Offset(spawn.x, spawn.y),
        radius: 8,
        color: const ui.Color(0xFFFFFFFF),
      ),
    ];

    emit(
      state.copyWith(
        status: WorldStatus.active,
        map: map,
        mapTexture: mapTexture,
        textureAtlas: textureAtlas,
        spriteAtlas: spriteAtlas,
        entities: entities,
        lights: lights,
        playerPosition: spawn,
        playerDirection: 0,
      ),
    );
  }

  void _onPlayerMoved(PlayerMoved event, Emitter<WorldState> emit) {
    // Update player light position
    final newLights = state.lights.map((l) {
      if (l.id == 'player_light') {
        return l.copyWith(
          position: ui.Offset(event.position.x, event.position.y),
        );
      }
      return l;
    }).toList();

    emit(
      state.copyWith(
        playerPosition: event.position,
        playerDirection: event.direction,
        lights: newLights,
      ),
    );
  }

  void _onEntityUpdated(EntityUpdated event, Emitter<WorldState> emit) {
    final updatedEntities = state.entities.map((e) {
      if (e.id == event.entityId) {
        final transform = e.getComponent<TransformComponent>();
        if (transform != null) {
          final newTransform = transform.copyWith(
            position: event.position,
            rotation: event.rotation,
          );

          final newComponents = List<GameComponent>.from(e.components);
          final index = newComponents.indexWhere(
            (c) => c is TransformComponent,
          );
          if (index != -1) {
            newComponents[index] = newTransform;
          } else {
            newComponents.add(newTransform);
          }

          return e.copyWith(components: newComponents);
        }
      }
      return e;
    }).toList();

    emit(state.copyWith(entities: updatedEntities));
  }

  Future<void> _onCellChanged(
    CellChanged event,
    Emitter<WorldState> emit,
  ) async {
    if (state.map == null) return;
    final newMap = state.map!.withCellAt(event.x, event.y, event.newCell);
    final newTexture = await TexturePacker.packMap(newMap);
    emit(
      state.copyWith(
        map: newMap,
        mapTexture: newTexture,
      ),
    );
  }

  void _onLightUpdated(LightUpdated event, Emitter<WorldState> emit) {
    final newLights = List<LightSource>.from(state.lights);
    final index = newLights.indexWhere((l) => l.id == event.light.id);
    if (index >= 0) {
      newLights[index] = event.light;
    } else {
      newLights.add(event.light);
    }
    emit(state.copyWith(lights: newLights));
  }

  void _onLightRemoved(LightRemoved event, Emitter<WorldState> emit) {
    final newLights = List<LightSource>.from(state.lights)
      ..removeWhere((l) => l.id == event.lightId);
    emit(state.copyWith(lights: newLights));
  }

  void _onWorldTick(WorldTick event, Emitter<WorldState> emit) {
    // Update light flicker
    final updatedLights = state.lights.map((light) {
      if (light.flickerSpeed > 0) {
        final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
        final flicker =
            math.sin(time * light.flickerSpeed * math.pi) * 0.1 + 0.9;
        return light.copyWith(intensity: light.intensity * flicker);
      }
      return light;
    }).toList();

    // Update AI entities
    final aiUpdates = _aiSystem.update(
      event.dt,
      state.entities,
      state.effectivePosition,
    );

    // Apply AI updates to entities
    var updatedEntities = List<GameEntity>.from(state.entities);
    for (final update in aiUpdates) {
      final index = updatedEntities.indexWhere((e) => e.id == update.entityId);
      if (index >= 0) {
        final entity = updatedEntities[index];
        // Replace components with updated versions
        final newComponents = entity.components.map((comp) {
          if (comp is TransformComponent) {
            return update.newTransform;
          } else if (comp is AIComponent) {
            return update.newAI;
          }
          return comp;
        }).toList();

        updatedEntities[index] = GameEntity(
          id: entity.id,
          components: newComponents,
          isActive: entity.isActive,
        );
      }
    }

    emit(
      state.copyWith(
        lights: updatedLights,
        entities: updatedEntities,
      ),
    );
  }
}

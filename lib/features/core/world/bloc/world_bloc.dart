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
import 'package:raycasting_game/features/game/systems/animation_system.dart';
import 'package:raycasting_game/features/core/ecs/components/animation_component.dart';
import 'package:raycasting_game/features/game/models/projectile.dart';
import 'package:raycasting_game/features/game/systems/damage_system.dart';
import 'package:raycasting_game/features/game/systems/physics_system.dart';
import 'package:raycasting_game/features/game/systems/projectile_system.dart';
import 'package:raycasting_game/features/game/utils/map_generator.dart';
import 'package:raycasting_game/features/game/utils/texture_generator.dart';
import 'package:raycasting_game/features/game/utils/texture_packer.dart';
import 'package:raycasting_game/features/game/weapon/models/weapon.dart';
import 'package:raycasting_game/features/game/weapon/models/ammo_type.dart';
import 'package:uuid/uuid.dart';
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
    on<SoundEmitted>(_onSoundEmitted);
    on<EntityDamaged>(_onEntityDamaged);
    on<PlayerFired>(_onPlayerFired);
    on<WorldTick>(_onWorldTick);
  }

  final AISystem _aiSystem = AISystem();
  final AnimationSystem _animationSystem = AnimationSystem();

  Future<void> _onInitialized(
    WorldInitialized event,
    Emitter<WorldState> emit,
  ) async {
    emit(state.copyWith(status: WorldStatus.loading));

    // Validate Dimensions (Enforce min 32x32)
    var width = event.width;
    var height = event.height;
    if (width < 32) width = 32;
    if (height < 32) height = 32;

    // 1. Generate Procedural Map
    final map = MapGenerator.generate(width, height);

    // 2. Find valid spawn points
    // Collect all valid empty cells
    final validCells = <Vector2>[];
    for (var y = 1; y < map.height - 1; y++) {
      for (var x = 1; x < map.width - 1; x++) {
        if (!map.grid[y][x].isSolid) {
          validCells.add(Vector2(x + 0.5, y + 0.5));
        }
      }
    }

    if (validCells.isEmpty) {
      // Fallback if map is solid (shouldn't happen with BSP)
      validCells.add(Vector2(1.5, 1.5));
    }

    // Shuffle to randomize placement
    validCells.shuffle();

    // 2.1 Spawn Player (First valid cell)
    var spawn = validCells.isNotEmpty
        ? validCells.removeAt(0)
        : Vector2(1.5, 1.5);

    // 2.2 Spawn Enemies (Next 5 cells)
    final entities = <GameEntity>[];
    var enemiesToSpawn = 5;

    while (enemiesToSpawn > 0 && validCells.isNotEmpty) {
      final pos = validCells.removeAt(0);

      // Ensure enemies aren't too close to player spawn
      if (pos.distanceTo(spawn) < 4.0) {
        // Put back at end and try next
        validCells.add(pos);
        continue;
      }

      final transform = TransformComponent(position: pos);
      const render = RenderComponent(spritePath: 'enemy_grunt');
      const health = HealthComponent(current: 40, max: 40);
      final ai = AIComponent(
        detectionRange: 8,
        attackRange: 2,
        moveSpeed: 1.5,
      );

      // Define Animations (Assuming 32x32 Grid in Atlas)
      // Row 0: Idle
      // Row 1: Walk
      // Row 2: Attack
      // Row 3: Pain
      final animations = {
        'idle': const AnimationState(
          name: 'idle',
          frames: [
            ui.Rect.fromLTWH(0, 0, 32, 32),
            ui.Rect.fromLTWH(32, 0, 32, 32),
          ],
          frameDuration: 0.5,
        ),
        'walk': const AnimationState(
          name: 'walk',
          frames: [
            ui.Rect.fromLTWH(0, 32, 32, 32),
            ui.Rect.fromLTWH(32, 32, 32, 32),
          ],
          frameDuration: 0.25,
        ),
        'attack': const AnimationState(
          name: 'attack',
          frames: [
            ui.Rect.fromLTWH(0, 64, 32, 32),
            ui.Rect.fromLTWH(32, 64, 32, 32),
          ],
          frameDuration: 0.1, // Fast attack
          loop: true,
        ),
        'pain': const AnimationState(
          name: 'pain',
          frames: [ui.Rect.fromLTWH(0, 96, 32, 32)],
          frameDuration: 0.5,
        ),
        'die': const AnimationState(
          name: 'die',
          frames: [
            ui.Rect.fromLTWH(0, 96, 32, 32), // Pain frame
            ui.Rect.fromLTWH(32, 96, 32, 32), // Dead frame
          ],
          frameDuration: 0.2,
          loop: false,
        ),
      };

      final anim = AnimationComponent(
        animations: animations,
        currentState: 'idle',
      );

      entities.add(
        GameEntity(
          id: 'enemy_$enemiesToSpawn',
          components: [transform, render, health, ai, anim],
        ),
      );
      enemiesToSpawn--;
    }

    // 3. Generate Textures (Keep original step 3 here)
    final mapTexture = await TexturePacker.packMap(map);
    final textureAtlas = await TextureGenerator.generateAtlas();
    final spriteAtlas = await TextureGenerator.generateSpriteAtlas();
    final weaponAtlas = await TextureGenerator.generateWeaponAtlas();

    LogService.info('WORLD', 'TEXTURES_GENERATED', {
      'mapTexture': true,
      'textureAtlas': true,
      'spriteAtlas': true,
      'weaponAtlas': true,
      'mapSize': '${map.width}x${map.height}',
    });

    // 4. Lights
    final lights = <LightSource>[];

    // Player Flashlight
    lights.add(
      LightSource(
        id: 'player_light',
        position: ui.Offset(spawn.x, spawn.y),
        radius: 8,
        color: const ui.Color(0xFFFFFFFF),
      ),
    );

    // Procedural Torches
    var lightsToSpawn = 7;
    final rng = math.Random();

    while (lightsToSpawn > 0 && validCells.isNotEmpty) {
      final pos = validCells.removeAt(0);

      // Ensure lights aren't too close to spawn (though less critical than enemies)
      if (pos.distanceTo(spawn) < 5.0) {
        continue;
      }

      // 50% chance to spawn light at this valid spot
      // Actually, since we have a list of valid spots, let's just pick them.
      // We can skip some to create variety, but since validCells is shuffled,
      // picking sequentially is already random.

      final isBlue = rng.nextDouble() > 0.7;
      lights.add(
        LightSource(
          id: 'torch_${pos.x}_${pos.y}',
          position: ui.Offset(pos.x, pos.y),
          radius: 5.0 + rng.nextDouble() * 2.0,
          intensity: 0.7 + rng.nextDouble() * 0.3,
          color: isBlue
              ? const ui.Color(0xFF0088FF)
              : const ui.Color(0xFFFF8800),
          flickerSpeed: 1.0 + rng.nextDouble() * 2.0,
        ),
      );

      // Visual Entity for Torch
      entities.add(
        GameEntity(
          id: 'fixture_torch_${pos.x}_${pos.y}',
          components: [
            TransformComponent(position: pos),
            // Using 'enemy_grunt' as placeholder for now, visual confirmation
            const RenderComponent(spritePath: 'enemy_grunt'),
          ],
        ),
      );

      lightsToSpawn--;
    }

    emit(
      state.copyWith(
        status: WorldStatus.active,
        map: map,
        mapTexture: mapTexture,
        textureAtlas: textureAtlas,
        spriteAtlas: spriteAtlas,
        weaponAtlas: weaponAtlas,
        entities: entities,
        lights: lights,
        playerPosition: spawn,
        playerDirection: 0,
      ),
    );
  }

  void _onEntityDamaged(EntityDamaged event, Emitter<WorldState> emit) {
    LogService.info('World', 'ENTITY_DAMAGED', {
      'id': event.entityId,
      'dmg': event.damage,
    });

    final updatedEntities = state.entities.map((e) {
      if (e.id != event.entityId) return e;

      // 1. Reduce Health
      final health = e.getComponent<HealthComponent>();
      if (health == null) return e;

      final newCurrent = (health.current - event.damage).clamp(0, health.max);
      final newHealth = health.copyWith(current: newCurrent);

      // 2. Update AI State (Pain/Die)
      var newComponents = List<GameComponent>.from(e.components);

      // Update Health Component
      final hIndex = newComponents.indexWhere((c) => c is HealthComponent);
      newComponents[hIndex] = newHealth;

      final ai = e.getComponent<AIComponent>();
      if (ai != null) {
        final aiIndex = newComponents.indexWhere((c) => c is AIComponent);
        var newAI = ai;

        if (newCurrent <= 0) {
          // DIE
          newAI = ai.copyWith(
            currentState: AIState.die,
            lastStateChange: DateTime.now(),
          );
          // Disable collision? Or make it non-solid?
          // For now, let's keep it simply dead.
          // Note: PhysicsSystem might still collide with dead bodies.
        } else {
          // PAIN (Stun)
          newAI = ai.copyWith(
            currentState: AIState.pain,
            lastStateChange: DateTime.now(),
          );
        }
        newComponents[aiIndex] = newAI;
      }

      return e.copyWith(components: newComponents);
    }).toList();

    emit(state.copyWith(entities: updatedEntities));
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

  void _onSoundEmitted(SoundEmitted event, Emitter<WorldState> emit) {
    // "Wake up" enemies within range
    final updatedEntities = state.entities.map((entity) {
      if (!entity.isActive) return entity;

      final ai = entity.getComponent<AIComponent>();
      final transform = entity.getComponent<TransformComponent>();
      if (ai == null || transform == null) return entity;

      if (ai.currentState == AIState.idle ||
          ai.currentState == AIState.patrol) {
        final dist = transform.position.distanceTo(event.source);
        // If sound is loud enough or close enough
        if (dist <= event.radius) {
          LogService.info('World', 'AI_HEARD_SOUND', {
            'id': entity.id,
            'dist': dist,
          });
          // Transition to CHASE
          final newAI = ai.copyWith(
            currentState: AIState.chase,
            lastStateChange: DateTime.now(),
            lastSeenPosition: event.source, // Investigate source of sound
          );

          // Update entity components
          final newComponents = List<GameComponent>.from(entity.components);
          final index = newComponents.indexWhere((c) => c is AIComponent);
          newComponents[index] = newAI;

          return entity.copyWith(components: newComponents);
        }
      }
      return entity;
    }).toList();

    if (updatedEntities != state.entities) {
      // Only emit if changed (reference inequality might trigger, but map returns new list anyway)
      emit(state.copyWith(entities: updatedEntities));
    }
  }

  void _onPlayerFired(PlayerFired event, Emitter<WorldState> emit) {
    if (state.isPlayerDead) return;

    final weapon = event.weapon;
    const uuid = Uuid();
    var newProjectiles = List<Projectile>.from(state.projectiles);
    var damageMap = <String, int>{};
    var newEffects = <WorldEffect>[];

    // Weapon Logic
    if (weapon.isHitscan) {
      // Hitscan: Raycast immediately
      final spread = (math.Random().nextDouble() - 0.5) * weapon.spreadAngle;
      final angle = state.playerDirection + spread;
      final dir = Vector2(math.cos(angle), math.sin(angle));

      final hitEntityId = PhysicsSystem.raycastEntities(
        state.effectivePosition,
        dir,
        state.entities,
        state.map,
        maxDistance: weapon.range,
        excludeId: 'player',
      );

      LogService.info('WORLD', 'HITSCAN_DEBUG', {
        'angle': angle.toStringAsFixed(2),
        'didHit': hitEntityId != null,
        'hitId': hitEntityId ?? 'none',
      });

      if (hitEntityId != null) {
        damageMap[hitEntityId] = weapon.damage;
      }

      // Visual Tracer (Fake Projectile)
      // Even if hitscan, we want to see a bullet fly
      // We start slightly in front
      final tDir = Vector2(math.cos(angle), math.sin(angle));
      final cStart = state.effectivePosition + tDir * 0.5;

      newProjectiles.add(
        Projectile(
          id: uuid.v4(),
          ownerId: 'player',
          position: cStart,
          velocity: tDir * 40.0, // Fast tracer
          damage: 0,
          ammoType: AmmoType.normal, // Use normal sprite (Slot 2)
          isVisualOnly: true,
          maxRange: weapon.range,
        ),
      );
    } else {
      // Projectile: Spawn
      final dir = Vector2(
        math.cos(state.playerDirection),
        math.sin(state.playerDirection),
      );
      // Spawn slightly in front to avoid clipping player immediately
      final startPos = state.effectivePosition + dir * 0.5;

      newProjectiles.add(
        Projectile(
          id: uuid.v4(),
          ownerId: 'player',
          position: startPos,
          velocity: dir * weapon.projectileSpeed,
          damage: weapon.damage,
          ammoType: weapon.ammoType,
          bouncesLeft: weapon.maxBounces,
        ),
      );
    }

    // Apply Hitscan Damage Immediately
    var updatedEntities = List<GameEntity>.from(state.entities);
    if (damageMap.isNotEmpty) {
      final damageResults = DamageSystem.apply(
        updatedEntities,
        damageMap,
        math.Random(),
      );

      updatedEntities = _applyDamageResults(updatedEntities, damageResults);

      // Effects for hits
      for (final result in damageResults) {
        if (result.died) {
          newEffects.add(EnemyKilledEffect(result.entityId));
        } else {
          // Could add generic hit effect
        }
      }
    }

    emit(
      state.copyWith(
        projectiles: newProjectiles,
        entities: updatedEntities,
        effects: newEffects.isNotEmpty ? newEffects : null,
      ),
    );
  }

  void _onWorldTick(WorldTick event, Emitter<WorldState> emit) {
    if (state.isPlayerDead || state.status == WorldStatus.gameOver) return;

    // 1. Update Lights (Flicker)
    final updatedLights = state.lights.map((light) {
      if (light.flickerSpeed > 0) {
        final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
        final flicker =
            math.sin(time * light.flickerSpeed * math.pi) * 0.1 + 0.9;
        return light.copyWith(intensity: light.intensity * flicker);
      }
      return light;
    }).toList();

    // 1.1 Decrement Invulnerability
    var currentInvulnerability = math.max(
      0.0,
      state.playerInvulnerabilityTime - event.dt,
    );

    // 2. AI Update
    final aiUpdates = _aiSystem.update(
      event.dt,
      state.entities,
      state.effectivePosition,
      state.map,
    );

    // 3. Projectile Update
    final projResult = ProjectileSystem.update(
      state.projectiles,
      state.entities,
      state.effectivePosition,
      state.map,
      event.dt,
    );

    // 4. Collect & Merge Damage
    // Sources: AI (Melee/Hitscan), Projectiles (Hit Player/Entity)
    final damageMap = <String, int>{};
    var playerDamageTaken = 0;
    final newProjectiles = <Projectile>[];

    // 4a. Projectile Results
    newProjectiles.addAll(projResult.surviving);
    playerDamageTaken += projResult.playerHits;
    damageMap.addAll(projResult.entityHits); // Merge projectile damage

    // 4b. AI Results (Damage & New Projectiles)
    for (final update in aiUpdates) {
      if (update.damageDealt > 0) {
        // AI currently only attacks Player with melee/hitscan in our logic
        // But if we add AI-vs-AI, we'd check target.
        // For now, assume AI attack -> Player
        playerDamageTaken += update.damageDealt;
      }
      if (update.spawnedProjectiles.isNotEmpty) {
        newProjectiles.addAll(update.spawnedProjectiles);
      }
    }

    // 5. Apply Damage to Entities
    var updatedEntities = List<GameEntity>.from(state.entities);
    final damageResults = DamageSystem.apply(
      updatedEntities,
      damageMap,
      math.Random(),
    );

    // 6. Apply AI State Updates (Movement/Anim)
    // We do this BEFORE applying damage results so that damage/death states override movement
    for (final update in aiUpdates) {
      if (update.entityId == 'enemy_1') {
        LogService.info('WORLD', 'APPLY', {
          'state': update.newAI.currentState.toString(),
          'anim': update.newAnim?.currentState ?? 'null',
        });
      }

      final index = updatedEntities.indexWhere((e) => e.id == update.entityId);
      if (index >= 0) {
        final entity = updatedEntities[index];
        // Apply transform/ai/anim updates
        final newComponents = entity.components.map((c) {
          if (c is TransformComponent) return update.newTransform;
          if (c is AIComponent) return update.newAI;
          if (c is AnimationComponent && update.newAnim != null)
            return update.newAnim!;
          return c;
        }).toList();

        updatedEntities[index] = entity.copyWith(components: newComponents);
      }
    }

    // 7. Apply Damage Results (Health reduction, Pain/Death state override)
    updatedEntities = _applyDamageResults(updatedEntities, damageResults);

    // 8. Update Player Health
    var newPlayerHealth = state.playerHealth;
    var isPlayerDead = state.isPlayerDead;
    final newEffects = <WorldEffect>[];

    if (playerDamageTaken > 0 && !isPlayerDead) {
      if (currentInvulnerability > 0) {
        // Ignored due to invulnerability (grace period)
        playerDamageTaken = 0;
      } else {
        newPlayerHealth = DamageSystem.applyToPlayer(
          newPlayerHealth,
          playerDamageTaken,
        );
        LogService.info('World', 'PLAYER_DAMAGED', {
          'dmg': playerDamageTaken,
          'rem': newPlayerHealth,
        });
        newEffects.add(PlayerDamagedEffect(playerDamageTaken));

        // Grant momentary invincibility (0.5s)
        currentInvulnerability = 0.5;

        if (newPlayerHealth <= 0) {
          isPlayerDead = true;
          LogService.info('World', 'PLAYER_DIED', {});
        }
      }
    }

    // 9. Update Animations (Advance frames)
    updatedEntities = _animationSystem.update(event.dt, updatedEntities);

    // 10. Process Death Effects from DamageResults
    for (final res in damageResults) {
      if (res.died) {
        newEffects.add(EnemyKilledEffect(res.entityId));
      }
    }

    emit(
      state.copyWith(
        lights: updatedLights,
        entities: updatedEntities,
        projectiles: newProjectiles,
        playerHealth: newPlayerHealth,
        isPlayerDead: isPlayerDead,
        effects: newEffects.isEmpty
            ? null
            : newEffects, // Only override if we have new effects?
        // Note: Effects are "one-shot" so we should clear them if list is null/empty?
        // The bloc state usually holds "latest" effects. The UI consumes them.
        // If we emit null, UI stops showing?
        // We'll trust the listener handles it.
        playerInvulnerabilityTime: currentInvulnerability,
        status: isPlayerDead ? WorldStatus.gameOver : state.status,
      ),
    );
  }

  /// Helper to update entities based on [EntityDamageResult]
  List<GameEntity> _applyDamageResults(
    List<GameEntity> entities,
    List<EntityDamageResult> results,
  ) {
    if (results.isEmpty) return entities;

    // Create a map for fast lookup
    final resultMap = {for (var r in results) r.entityId: r};

    return entities.map((e) {
      final result = resultMap[e.id];
      if (result == null) return e;

      var newComponents = List<GameComponent>.from(e.components);

      // Update Health
      final hIndex = newComponents.indexWhere((c) => c is HealthComponent);
      if (hIndex >= 0) {
        final h = newComponents[hIndex] as HealthComponent;
        newComponents[hIndex] = h.copyWith(current: result.newHealth);
      }

      // Update AI State (Pain/Die)
      final aiIndex = newComponents.indexWhere((c) => c is AIComponent);
      if (aiIndex >= 0) {
        final ai = newComponents[aiIndex] as AIComponent;
        if (result.died) {
          newComponents[aiIndex] = ai.copyWith(
            currentState: AIState.die,
            lastStateChange: DateTime.now(),
          );
        } else if (result.enteredPain) {
          newComponents[aiIndex] = ai.copyWith(
            currentState: AIState.pain,
            lastStateChange: DateTime.now(),
          );
        }
      }

      return e.copyWith(components: newComponents);
    }).toList();
  }
}

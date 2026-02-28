import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:raycasting_game/core/logging/log_service.dart';
import 'package:raycasting_game/features/core/ecs/components/health_component.dart';
import 'package:raycasting_game/features/core/ecs/components/render_component.dart';
import 'package:raycasting_game/features/core/ecs/components/transform_component.dart';
import 'package:raycasting_game/features/core/ecs/components/pickup_component.dart';
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
    on<LevelCleanup>(_onLevelCleanup);
  }

  // --- Survival Mode: Spawn Timer ---
  double _spawnTimer = 0.0;
  int _enemyCounter = 0;
  static const double _corpseLifetime = 3.0;

  // --- Wave / Difficulty Scaling ---
  // Wave advances every 5 kills.  Wave 0 = easiest, no hard cap.
  // Spawn interval and max-alive enemies both scale with wave.
  int _waveNumber = 0;
  int _killCount = 0;
  static const int _killsPerWave = 5;

  // Dynamic spawn config (re-computed from wave each tick)
  double get _spawnInterval => math.max(2.0, 5.0 - _waveNumber * 0.4);
  int get _maxAliveEnemies => math.min(14, 4 + _waveNumber * 2);

  // OPT: AI time-slicing — full FSM/LOS at 20 Hz, velocity applied at 60 Hz.
  double _aiAccumulator = 0.0;
  static const double _aiUpdateInterval = 1.0 / 20.0; // 50 ms

  final AISystem _aiSystem = AISystem();
  final AnimationSystem _animationSystem = AnimationSystem();

  Future<void> _onInitialized(
    WorldInitialized event,
    Emitter<WorldState> emit,
  ) async {
    // [FIX-B3] Clear any previous entities/projectiles before re-initializing
    // to prevent accumulation on hot-reload or repeated WorldInitialized events.
    emit(
      state.copyWith(
        status: WorldStatus.loading,
        entities: [],
        projectiles: [],
        playerPosition: null,
      ),
    );

    // Validate Dimensions (Enforce min 32x32)
    var width = event.width;
    var height = event.height;
    if (width < 32) width = 32;
    if (height < 32) height = 32;

    // Yield to the event loop here. This is CRITICAL for UX:
    // It allows the incoming 'loading' state to actually render on the screen
    // (e.g., the LevelTransitionOverlay fade-in) before we freeze the main
    // thread with heavy synchronous procedural generation algorithms.
    await Future<void>.delayed(const Duration(milliseconds: 32));

    // 1. Generate Procedural Map (pass seed for reproducibility)
    // Removed Isolate.run because dart:isolate is unsupported on Flutter Web.
    final map = MapGenerator.generate(width, height, seed: event.seed);

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

    // 2.1 Spawn Player — use center of the first room
    //     Fall back to a raw cell if no rooms were generated.
    var spawn = map.roomRects.isNotEmpty
        ? Vector2(map.roomRects.first.centerX, map.roomRects.first.centerY)
        : (validCells.isNotEmpty ? validCells.removeAt(0) : Vector2(1.5, 1.5));

    LogService.info('WORLD', 'ARENA_INITIALIZED', {
      'rooms': map.roomRects.length,
    });

    // 3. Generate Textures with Event Loop Yielding
    // We add small delays (yields) between heavy computations to allow
    // the Flutter framework to render the loading screen overlay at 60fps
    // without starving the main UI thread.
    final mapTexture = await TexturePacker.packMap(map);
    await Future<void>.delayed(const Duration(milliseconds: 16));

    final textureAtlas = await TextureGenerator.generateAtlas();
    await Future<void>.delayed(const Duration(milliseconds: 16));

    final spriteAtlas = await TextureGenerator.generateSpriteAtlas();
    await Future<void>.delayed(const Duration(milliseconds: 16));

    final weaponAtlas = await TextureGenerator.generateWeaponAtlas();
    await Future<void>.delayed(const Duration(milliseconds: 16));

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
        radius: 4.5,
        intensity: 1.5,
        color: const ui.Color(0xFFD6F6F5),
      ),
    );

    emit(
      state.copyWith(
        status: WorldStatus.active,
        map: map,
        mapTexture: mapTexture,
        textureAtlas: textureAtlas,
        spriteAtlas: spriteAtlas,
        weaponAtlas: weaponAtlas,
        entities: _spawnInitialPickups(map, spawn),
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
    // "Wake up" idle/patrolling enemies within range.
    // They enter INVESTIGATE (not chase) — more realistic, gives player
    // a chance to prepare before the enemy actually confirms LOS.
    final updatedEntities = state.entities.map((entity) {
      if (!entity.isActive) return entity;

      final ai = entity.getComponent<AIComponent>();
      final transform = entity.getComponent<TransformComponent>();
      if (ai == null || transform == null) return entity;

      if (ai.currentState == AIState.idle ||
          ai.currentState == AIState.patrol) {
        final dist = transform.position.distanceTo(event.source);
        if (dist <= event.radius) {
          LogService.info('World', 'AI_HEARD_SOUND', {
            'id': entity.id,
            'dist': dist.toStringAsFixed(1),
          });
          // Transition to INVESTIGATE — not instant chase
          final newAI = ai.copyWith(
            currentState: AIState.investigate,
            lastStateChange: DateTime.now(),
            investigatePosition: event.source, // Walk toward the sound source
          );

          final newComponents = List<GameComponent>.from(entity.components);
          final index = newComponents.indexWhere((c) => c is AIComponent);
          newComponents[index] = newAI;

          return entity.copyWith(components: newComponents);
        }
      }
      return entity;
    }).toList();

    if (updatedEntities != state.entities) {
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
      // One raycast + one visual tracer per pellet.
      // Shotgun fires weapon.pellets == 7; pistol/rifle fire 1.
      final rng = math.Random();
      for (var pellet = 0; pellet < weapon.pellets; pellet++) {
        final spread = (rng.nextDouble() - 0.5) * weapon.spreadAngle;
        final angle = state.playerDirection + spread;
        final dir = Vector2(math.cos(angle), math.sin(angle));

        // Instant damage raycast for this pellet
        final hitEntityId = PhysicsSystem.raycastEntities(
          state.effectivePosition,
          dir,
          state.entities,
          state.map,
          maxDistance: weapon.range,
          excludeId: 'player',
        );

        if (pellet == 0) {
          LogService.info('WORLD', 'HITSCAN_DEBUG', {
            'angle': angle.toStringAsFixed(2),
            'didHit': hitEntityId != null,
            'hitId': hitEntityId ?? 'none',
          });
        }

        if (hitEntityId != null) {
          // Accumulate: multiple shotgun pellets hitting the same target stack.
          damageMap[hitEntityId] =
              (damageMap[hitEntityId] ?? 0) + weapon.damage;
        }

        // Perspective-correct tracer round — rendered as an elongated streak.
        // visualScale varies per weapon: shotgun pellets are small, rifle is thin,
        // pistol is medium.
        final double tracerScale = weapon.id == 'rifle'
            ? 0.7
            : weapon.id == 'shotgun'
            ? 0.85
            : 1.2; // pistol default
        newProjectiles.add(
          Projectile(
            id: uuid.v4(),
            ownerId: 'player',
            position: state.effectivePosition + dir * 0.5,
            velocity: dir * 80.0, // 80 u/s — cap life to <1 weapon cycle
            damage: 0,
            ammoType: AmmoType.normal,
            isVisualOnly: true,
            maxRange: 9.0, // Fog distance — 1 visible tracer per shot
            renderStyle: ProjectileRenderStyle.tracer,
            visualScale: tracerScale,
          ),
        );
      }
    } else {
      // Projectile: Spawn
      final dir = Vector2(
        math.cos(state.playerDirection),
        math.sin(state.playerDirection),
      );
      // Spawn slightly in front to avoid clipping player immediately
      final startPos = state.effectivePosition + dir * 0.5;

      // visualScale: bouncePistol is a big slow orb, bounceRifle is smaller/faster.
      final double projScale = weapon.id == 'bounce_pistol' ? 1.7 : 1.3;

      newProjectiles.add(
        Projectile(
          id: uuid.v4(),
          ownerId: 'player',
          position: startPos,
          velocity: dir * weapon.projectileSpeed,
          damage: weapon.damage,
          ammoType: weapon.ammoType,
          bouncesLeft: weapon.maxBounces,
          visualScale: projScale,
          renderStyle: ProjectileRenderStyle.plasma,
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
          _killCount++;
          if (_killCount % _killsPerWave == 0) {
            _waveNumber++;
            LogService.info('WORLD', 'WAVE_UP', {
              'wave': _waveNumber,
              'kills': _killCount,
            });
          }
        }
      }
    }

    // Alert nearby enemies to the gunshot sound (radius scales with weapon range)
    updatedEntities = _alertEnemiesFromShot(
      state.effectivePosition,
      weapon.range * 0.7,
      updatedEntities,
    );

    emit(
      state.copyWith(
        projectiles: newProjectiles,
        entities: updatedEntities,
        effects: newEffects,
      ),
    );
  }

  void _onWorldTick(WorldTick event, Emitter<WorldState> emit) {
    if (state.isPlayerDead || state.status == WorldStatus.gameOver) return;

    // OPT: Single DateTime.now() shared by lights flicker, AI timers, and
    // time-slicing gate — was called O(n_lights + n_entities) per frame.
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch / 1000.0;

    // 1. Update Lights (Flicker)
    final updatedLights = state.lights.map((light) {
      if (light.flickerSpeed > 0) {
        final flicker =
            math.sin(nowMs * light.flickerSpeed * math.pi) * 0.1 + 0.9;
        return light.copyWith(intensity: light.intensity * flicker);
      }
      return light;
    }).toList();

    // 1.1 Decrement Invulnerability
    var currentInvulnerability = math.max(
      0.0,
      state.playerInvulnerabilityTime - event.dt,
    );

    // 2. AI Update — ONLY update alive enemies to save CPU on dead ones
    final liveEntities = state.entities
        .where(
          (e) => e.getComponent<AIComponent>()?.currentState != AIState.die,
        )
        .toList(growable: false);

    // OPT: AI time-slicing — run full FSM + LOS at 20 Hz.
    // Between ticks, apply the cached velocity for smooth 60 Hz movement.
    _aiAccumulator += event.dt;
    final shouldRunFullAI = _aiAccumulator >= _aiUpdateInterval;
    if (shouldRunFullAI) _aiAccumulator -= _aiUpdateInterval;

    final aiUpdates = shouldRunFullAI
        ? _aiSystem.update(
            event.dt,
            liveEntities,
            state.effectivePosition,
            state.map,
            now: now,
          )
        : _applyVelocityOnly(event.dt, liveEntities);

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
    // Only copy the list if there's actual damage to apply (saves allocation)
    var updatedEntities = damageMap.isNotEmpty
        ? List<GameEntity>.from(state.entities)
        : state.entities.toList(); // still need a mutable list for AI updates
    final damageResults = DamageSystem.apply(
      updatedEntities,
      damageMap,
      math.Random(),
    );

    // 6. Apply AI State Updates (Movement/Anim)
    // We do this BEFORE applying damage results so that damage/death states override movement
    for (final update in aiUpdates) {
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

    // 8. Update Player Health & Persist Effects
    var newPlayerHealth = state.playerHealth;
    var isPlayerDead = state.isPlayerDead;
    final newEffects = <WorldEffect>[];

    // Process existing effects (e.g., aging the damage vignette)
    for (final effect in state.effects) {
      if (effect is PlayerDamagedEffect) {
        final newLifetime = effect.lifetime - event.dt;
        if (newLifetime > 0) {
          // Keep it but updated
          newEffects.add(
            PlayerDamagedEffect(
              effect.amount,
              lifetime: newLifetime,
              maxLifetime: effect.maxLifetime,
            ),
          );
        }
      } else {
        // Drop other immediate effects (EnemyKilled, Hit)
        // as they are consumed instantly by the UI/Audio layers.
      }
    }

    // Bounce impact sparks: emit one-shot effect per wall bounce this tick.
    for (final pos in projResult.wallBounces) {
      newEffects.add(BounceEffect(Vector2(pos.x, pos.y)));
    }

    // Wall hit decals: non-bouncing projectiles that stopped at a wall.
    for (final pos in projResult.wallHits) {
      newEffects.add(WallHitEffect(Vector2(pos.x, pos.y)));
    }

    var newPlayerPosition = state.effectivePosition;

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

        // [FIX] Capa 3 — Knockback: push the player away from the closest
        // melee attacker so they are never permanently trapped.
        // A 0.5u impulse is enough to escape the overlap zone (minDist = 0.6u).
        const knockbackStrength = 0.5;
        GameEntity? closestAttacker;
        var closestDist = double.infinity;

        for (final entity in updatedEntities) {
          if (!entity.isActive) continue;
          final aiComp = entity.getComponent<AIComponent>();
          // Only melee-type attackers generate contact-trapping situations.
          if (aiComp == null ||
              aiComp.attackType != AIAttackType.melee ||
              aiComp.currentState == AIState.die)
            continue;
          final t = entity.getComponent<TransformComponent>();
          if (t == null) continue;
          final dist = newPlayerPosition.distanceTo(t.position);
          if (dist < closestDist) {
            closestDist = dist;
            closestAttacker = entity;
          }
        }

        if (closestAttacker != null) {
          final attackerPos = closestAttacker
              .getComponent<TransformComponent>()!
              .position;
          final awayDir = newPlayerPosition - attackerPos;
          // If completely overlapping (zero vector), use a fixed direction
          final pushDir = awayDir.length < 0.01
              ? Vector2(1, 0)
              : awayDir.normalized();

          final impulse = pushDir * knockbackStrength;

          newPlayerPosition = PhysicsSystem.tryMove(
            'player',
            newPlayerPosition,
            impulse / event.dt, // Convert displacement to velocity
            event.dt,
            state.map,
            updatedEntities,
            radius: 0.3,
          );

          LogService.info('World', 'PLAYER_KNOCKBACK', {
            'attacker': closestAttacker.id,
            'pushDir':
                '(${pushDir.x.toStringAsFixed(2)}, ${pushDir.y.toStringAsFixed(2)})',
            'newPos':
                '(${newPlayerPosition.x.toStringAsFixed(2)}, ${newPlayerPosition.y.toStringAsFixed(2)})',
          });
        }

        if (newPlayerHealth <= 0) {
          isPlayerDead = true;
          LogService.info('World', 'PLAYER_DIED', {});
        }
      }
    }

    // 9. Update Animations (Advance frames)
    updatedEntities = _animationSystem.update(event.dt, updatedEntities);

    // 10. Process Death Effects from DamageResults + advance wave counter
    for (final res in damageResults) {
      if (res.died) {
        newEffects.add(EnemyKilledEffect(res.entityId));
        _killCount++;
        if (_killCount % _killsPerWave == 0) {
          _waveNumber++;
          LogService.info('WORLD', 'WAVE_UP', {
            'wave': _waveNumber,
            'kills': _killCount,
          });
        }
      }
    }

    // 11. Survival Spawn: purge corpses and spawn new enemies
    _spawnTimer += event.dt;

    // Purge corpses dead for > _corpseLifetime seconds (O(n) on ≤10 enemies)
    // OPT: Reuse `now` from top of tick — no extra DateTime allocation.
    updatedEntities = updatedEntities.where((e) {
      final ai = e.getComponent<AIComponent>();
      if (ai == null || ai.currentState != AIState.die) return true;
      if (ai.lastStateChange == null)
        return false; // dead but no timestamp → purge
      final deadFor =
          now.difference(ai.lastStateChange!).inMilliseconds / 1000.0;
      return deadFor < _corpseLifetime;
    }).toList();

    // Spawn new enemy if timer elapsed and alive count < 10
    if (_spawnTimer >= _spawnInterval && !isPlayerDead) {
      _spawnTimer = 0.0;
      final aliveCount = updatedEntities
          .where(
            (e) => e.getComponent<AIComponent>()?.currentState != AIState.die,
          )
          .length;

      if (aliveCount < _maxAliveEnemies && state.map != null) {
        final newEnemy = _createSurvivalEnemy(state.map!, newPlayerPosition);
        if (newEnemy != null) {
          updatedEntities = [...updatedEntities, newEnemy];
          LogService.info('WORLD', 'SURVIVAL_SPAWN', {
            'id': newEnemy.id,
            'alive': aliveCount + 1,
          });
        }
      }
    }

    // 11. Ammo Pickup Collection: check if player is standing on any ammo box.
    for (var i = 0; i < updatedEntities.length; i++) {
      final entity = updatedEntities[i];
      if (!entity.isActive) continue;
      final pickup = entity.getComponent<PickupComponent>();
      final transform = entity.getComponent<TransformComponent>();
      if (pickup != null && transform != null) {
        if ((transform.position - newPlayerPosition).length < 0.65) {
          updatedEntities = List<GameEntity>.from(updatedEntities);
          updatedEntities[i] = entity.copyWith(isActive: false);
          newEffects.add(
            AmmoPickedUpEffect(
              ammoType: pickup.ammoType,
              quantity: pickup.quantity,
            ),
          );
        }
      }
    }

    emit(
      state.copyWith(
        lights: updatedLights,
        entities: updatedEntities,
        projectiles: newProjectiles,
        playerHealth: newPlayerHealth,
        isPlayerDead: isPlayerDead,
        playerPosition: newPlayerPosition,
        effects: newEffects,
        playerInvulnerabilityTime: currentInvulnerability,
        status: isPlayerDead ? WorldStatus.gameOver : state.status,
      ),
    );
  }

  /// Spawns ammo pickup entities at room positions spread across the map.
  /// Called once during world initialization.
  List<GameEntity> _spawnInitialPickups(GameMap map, Vector2 playerPos) {
    const minDist = 3.0;
    final rng = math.Random(map.width * 31 + map.height);
    final pickups = <GameEntity>[];

    final availableRooms = map.roomRects
        .where(
          (r) => Vector2(r.centerX, r.centerY).distanceTo(playerPos) >= minDist,
        )
        .toList()
      ..shuffle(rng);

    // Config: [(ammoType, quantity)] — up to 5 pickups spread in rooms.
    const pickupDefs = [
      (AmmoType.normal, 15),
      (AmmoType.normal, 10),
      (AmmoType.normal, 12),
      (AmmoType.bouncing, 8),
      (AmmoType.bouncing, 6),
    ];

    for (var i = 0; i < pickupDefs.length && i < availableRooms.length; i++) {
      final room = availableRooms[i];
      final jitter = (rng.nextDouble() - 0.5) * 0.8;
      final pos = Vector2(
        room.centerX + jitter,
        room.centerY + (rng.nextDouble() - 0.5) * 0.8,
      );
      final def = pickupDefs[i];
      pickups.add(
        GameEntity(
          id: 'pickup_ammo_$i',
          components: [
            TransformComponent(position: pos),
            PickupComponent(ammoType: def.$1, quantity: def.$2),
          ],
        ),
      );
    }
    return pickups;
  }

  /// Creates a new enemy for survival mode, preferring rooms far from the player.
  /// Enemy type is wave-gated:
  ///   Wave 0-1 -> only grunts (learn the basic fight)
  ///   Wave 2-3 -> grunts 70% + shooters 30%
  ///   Wave 4+  -> weighted pool: grunts 50%, shooters 30%, guardians 20%
  GameEntity? _createSurvivalEnemy(GameMap map, Vector2 playerPos) {
    const minDist = 6.0;
    _enemyCounter++;

    // Prefer rooms far from player
    final candidateRooms =
        map.roomRects
            .where(
              (r) =>
                  Vector2(r.centerX, r.centerY).distanceTo(playerPos) >=
                  minDist,
            )
            .toList()
          ..shuffle();

    Vector2? spawnPos;
    if (candidateRooms.isNotEmpty) {
      final room = candidateRooms.first;
      spawnPos = Vector2(room.centerX, room.centerY);
    } else {
      // Fallback: any empty cell not occupied by player
      for (var y = 1; y < map.height - 1; y++) {
        for (var x = 1; x < map.width - 1; x++) {
          if (!map.grid[y][x].isSolid) {
            final p = Vector2(x + 0.5, y + 0.5);
            if (p.distanceTo(playerPos) >= minDist) {
              spawnPos = p;
              break;
            }
          }
        }
        if (spawnPos != null) break;
      }
    }
    if (spawnPos == null) return null;

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
        frameDuration: 0.1,
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
          ui.Rect.fromLTWH(0, 96, 32, 32),
          ui.Rect.fromLTWH(32, 96, 32, 32),
        ],
        frameDuration: 0.2,
        loop: false,
      ),
    };

    return GameEntity(
      id: 'enemy_dyn_$_enemyCounter',
      components: [
        TransformComponent(position: spawnPos),
        ..._buildEnemyComponents(animations),
      ],
    );
  }

  /// Returns the [HealthComponent], [RenderComponent], and [AIComponent]
  /// for the enemy type chosen by the current wave.
  List<GameComponent> _buildEnemyComponents(
    Map<String, AnimationState> animations,
  ) {
    // Wave-gated enemy type selection
    final EnemyType type;
    if (_waveNumber <= 1) {
      type = EnemyType.grunt;
    } else if (_waveNumber <= 3) {
      // 70% grunt, 30% shooter
      type = math.Random().nextDouble() < 0.70
          ? EnemyType.grunt
          : EnemyType.shooter;
    } else {
      // 50% grunt, 30% shooter, 20% guardian
      final roll = math.Random().nextDouble();
      if (roll < 0.50) {
        type = EnemyType.grunt;
      } else if (roll < 0.80) {
        type = EnemyType.shooter;
      } else {
        type = EnemyType.guardian;
      }
    }

    switch (type) {
      case EnemyType.grunt:
        return [
          const RenderComponent(spritePath: 'enemy_grunt'),
          const HealthComponent(current: 40, max: 40),
          AIComponent.grunt,
          AnimationComponent(animations: animations, currentState: 'idle'),
        ];
      case EnemyType.shooter:
        return [
          const RenderComponent(spritePath: 'enemy_shooter'),
          const HealthComponent(current: 55, max: 55), // More HP than grunt
          AIComponent.shooter,
          AnimationComponent(animations: animations, currentState: 'idle'),
        ];
      case EnemyType.guardian:
        return [
          const RenderComponent(spritePath: 'enemy_guardian'),
          const HealthComponent(current: 80, max: 80), // Tanky
          AIComponent.guardian,
          AnimationComponent(animations: animations, currentState: 'idle'),
        ];
    }
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
          // Sync AnimationComponent so death anim starts immediately,
          // without relying on the AI System (which skips dead entities).
          final animIndex = newComponents.indexWhere(
            (c) => c is AnimationComponent,
          );
          if (animIndex >= 0) {
            final anim = newComponents[animIndex] as AnimationComponent;
            newComponents[animIndex] = anim.copyWith(
              currentState: 'die',
              currentFrame: 0,
              timer: 0,
            );
          }
        } else if (result.enteredPain) {
          newComponents[aiIndex] = ai.copyWith(
            currentState: AIState.pain,
            lastStateChange: DateTime.now(),
          );
          // Sync AnimationComponent to pain animation immediately.
          final animIndex = newComponents.indexWhere(
            (c) => c is AnimationComponent,
          );
          if (animIndex >= 0) {
            final anim = newComponents[animIndex] as AnimationComponent;
            newComponents[animIndex] = anim.copyWith(
              currentState: 'pain',
              currentFrame: 0,
              timer: 0,
            );
          }
        }
      }

      return e.copyWith(components: newComponents);
    }).toList();
  }

  /// Resets to a clean empty world.
  /// Called before spawning the next level.
  /// Note: We do NOT manually call `.dispose()` on mapTexture/atlasTexture
  /// here because in Flutter Web (CanvasKit) the rasterizer may still have
  /// them queued for the current frame, causing
  /// 'The native object of SkImage was disposed' assertions.
  /// We rely on the GC to clean them up once WorldState drops the references.
  void _onLevelCleanup(LevelCleanup event, Emitter<WorldState> emit) {
    // Reset wave / difficulty counters so the next level starts fresh.
    _waveNumber = 0;
    _killCount = 0;
    _spawnTimer = 0.0;
    _enemyCounter = 0;
    // Immediately emit empty state to clear the world.
    emit(WorldState.empty());
    LogService.info('WORLD', 'LEVEL_CLEANUP_DONE', {});
  }

  /// OPT: Called on the 40 Hz frames skipped by the 20 Hz AI gate.
  /// Applies [AIComponent.cachedMoveVelocity] directly to position without
  /// re-running LOS/FSM/pathfinding, giving smooth 60 Hz movement at a
  /// fraction of the full AI update cost.
  /// Covers both chase and investigate states (both use cached velocity).
  List<AIUpdateResult> _applyVelocityOnly(
    double dt,
    List<GameEntity> liveEntities,
  ) {
    final results = <AIUpdateResult>[];

    for (final entity in liveEntities) {
      final ai = entity.getComponent<AIComponent>();
      final transform = entity.getComponent<TransformComponent>();
      if (ai == null ||
          transform == null ||
          // Only moving states benefit from velocity interpolation
          (ai.currentState != AIState.chase &&
           ai.currentState != AIState.investigate) ||
          ai.cachedMoveVelocity == null) {
        continue;
      }

      final vel = ai.cachedMoveVelocity!;
      if (vel.length2 < 0.001) continue; // effectively zero

      // Run full wall+entity collision so enemies cannot phase through
      // walls between AI ticks (the 40 Hz interpolation frames).
      final newPos = PhysicsSystem.tryMove(
        entity.id,
        transform.position,
        vel,
        dt,
        state.map,
        state.entities,
        radius: 0.3,
      );
      results.add(
        AIUpdateResult(
          entityId: entity.id,
          newTransform: transform.copyWith(position: newPos),
          newAI: ai,
        ),
      );
    }

    return results;
  }

  /// Alerts idle/patrolling enemies within [radius] of [shotOrigin] by
  /// transitioning them to [AIState.investigate]. Called on every player shot.
  /// Returns the updated entities list (does NOT emit directly).
  List<GameEntity> _alertEnemiesFromShot(
    Vector2 shotOrigin,
    double radius,
    List<GameEntity> entities,
  ) {
    var changed = false;
    final result = entities.map((entity) {
      if (!entity.isActive) return entity;
      final ai = entity.getComponent<AIComponent>();
      final transform = entity.getComponent<TransformComponent>();
      if (ai == null || transform == null) return entity;

      // Only alert idle/patrol enemies — chasing/attacking already know
      if (ai.currentState != AIState.idle &&
          ai.currentState != AIState.patrol) {
        return entity;
      }

      final dist = transform.position.distanceTo(shotOrigin);
      if (dist > radius) return entity;

      LogService.info('World', 'AI_ALERTED_SHOT', {
        'id': entity.id,
        'dist': dist.toStringAsFixed(1),
      });

      final newAI = ai.copyWith(
        currentState: AIState.investigate,
        lastStateChange: DateTime.now(),
        investigatePosition: shotOrigin,
      );
      final newComponents = List<GameComponent>.from(entity.components);
      final idx = newComponents.indexWhere((c) => c is AIComponent);
      newComponents[idx] = newAI;
      changed = true;
      return entity.copyWith(components: newComponents);
    }).toList();

    return changed ? result : entities;
  }}
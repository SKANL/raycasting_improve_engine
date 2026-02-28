import 'dart:math' as math;

import 'package:raycasting_game/core/logging/log_service.dart';
import 'package:raycasting_game/features/core/ecs/components/animation_component.dart';
import 'package:raycasting_game/features/core/ecs/components/transform_component.dart';
import 'package:raycasting_game/features/core/world/models/game_entity.dart';
import 'package:raycasting_game/features/core/world/models/game_map.dart';
import 'package:raycasting_game/features/game/ai/components/ai_component.dart';
import 'package:raycasting_game/features/game/models/projectile.dart';
import 'package:raycasting_game/features/game/systems/physics_system.dart';
import 'package:raycasting_game/features/game/weapon/models/ammo_type.dart';
import 'package:uuid/uuid.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

/// Result of AI update containing entity ID, updates, and spawned objects
class AIUpdateResult {
  const AIUpdateResult({
    required this.entityId,
    required this.newTransform,
    required this.newAI,
    this.newAnim,
    this.damageDealt = 0,
    this.spawnedProjectiles = const [],
  });

  final String entityId;
  final TransformComponent newTransform;
  final AIComponent newAI;
  final AnimationComponent? newAnim;
  final int damageDealt;
  final List<Projectile> spawnedProjectiles;
}

/// System that updates AI entities each frame (Doom FSM)
class AISystem {
  static const _uuid = Uuid();

  /// Update all AI entities and return list of updates to apply
  List<AIUpdateResult> update(
    double dt,
    List<GameEntity> entities,
    v64.Vector2 playerPosition,
    GameMap? map, {
    DateTime? now,
  }) {
    // OPT: Call DateTime.now() ONCE for all entities instead of O(n) times.
    final nowTime = now ?? DateTime.now();
    final updates = <AIUpdateResult>[];

    for (final entity in entities) {
      final ai = entity.getComponent<AIComponent>();
      final transform = entity.getComponent<TransformComponent>();

      if (ai == null || transform == null || !entity.isActive) continue;

      final result = _updateAI(
        dt,
        entity,
        ai,
        transform,
        playerPosition,
        map,
        entities,
        nowTime,
      );
      if (result != null) {
        updates.add(result);
      }
    }

    return updates;
  }

  AIUpdateResult? _updateAI(
    double dt,
    GameEntity entity,
    AIComponent ai,
    TransformComponent transform,
    v64.Vector2 playerPosition,
    GameMap? map,
    List<GameEntity> allEntities,
    DateTime now,  // OPT: injected — not re-created per entity
  ) {
    // --- DEATH OPTIMIZATION ---
    // Dead entities should NOT compute Line-of-sight nor Math Distances.
    // They are just visual corpses fading/animating.
    if (ai.currentState == AIState.die) {
      bool animChangedLocally = false;
      var newAnimLocally = entity.getComponent<AnimationComponent>();
      if (newAnimLocally != null && newAnimLocally.currentState != 'die') {
        newAnimLocally = newAnimLocally.copyWith(
          currentState: 'die',
          currentFrame: 0,
          timer: 0,
        );
        animChangedLocally = true;
      }

      if (animChangedLocally) {
        return AIUpdateResult(
          entityId: entity.id,
          newTransform: transform,
          newAI: ai,
          newAnim: newAnimLocally,
        );
      }
      return null;
    }

    // OPT: Use squared distance for detection-range check — avoids sqrt.
    final distSq = (playerPosition - transform.position).length2;
    // Full distance is still needed for other range comparisons (attack, contact).
    final distToPlayer = math.sqrt(distSq);
    final hasLOS = PhysicsSystem.hasLineOfSight(
      transform.position,
      playerPosition,
      map,
    );

    var aiChanged = false;
    var transformChanged = false;
    var animChanged = false;
    var damageDealt = 0;
    final spawnedProjectiles = <Projectile>[];

    var newAI = ai;
    var newTransform = transform;

    final anim = entity.getComponent<AnimationComponent>();
    var newAnim = anim;

    // OPT: Use the injected `now` — not re-created per entity.
    // Time since last state transition
    final timeInState = ai.lastStateChange != null
        ? now.difference(ai.lastStateChange!).inMilliseconds / 1000.0
        : 0.0;

    // Time since last attack (for cooldowns)
    final timeSinceAttack = ai.lastAttackTime != null
        ? now.difference(ai.lastAttackTime!).inMilliseconds / 1000.0
        : 999.0;

    switch (ai.currentState) {
      // 0. INVESTIGATE: Heard a sound — moving to position without confirmed LOS.
      // Upgrade to chase the moment we see the player.
      case AIState.investigate:
        if (hasLOS && distSq <= ai.detectionRange * ai.detectionRange) {
          // Player spotted while investigating — enter combat!
          newAI = ai.copyWith(
            currentState: AIState.chase,
            lastStateChange: now,
            lastSeenPosition: playerPosition,
            investigatePosition: null, // cleared
          );
          aiChanged = true;
          LogService.info('AI', 'INVESTIGATE_SPOTTED', {'entity': entity.id});
        } else if (ai.investigatePosition != null) {
          final distToInvest =
              (transform.position - ai.investigatePosition!).length;
          if (distToInvest < 0.8) {
            // Arrived at noise source — found nothing, return to idle.
            newAI = ai.copyWith(
              currentState: AIState.idle,
              lastStateChange: now,
              investigatePosition: null,
            );
            aiChanged = true;
          } else {
            final (movedTransform, velocity) = _moveToward(
              dt, newAI, entity.id, transform, ai.investigatePosition!,
              map, allEntities, playerPosition,
            );
            newTransform = movedTransform;
            newAI = newAI.copyWith(cachedMoveVelocity: velocity);
            aiChanged = true;
            transformChanged = true;
          }
        } else {
          // No position set (guard against bad state)
          newAI = ai.copyWith(
              currentState: AIState.idle, lastStateChange: now);
          aiChanged = true;
        }
        break;

      // 1. IDLE: Wait for player to be seen
      case AIState.idle:
      case AIState.patrol:
        // OPT: distSq avoids sqrt for the hot-path detection check.
        if (hasLOS && distSq <= ai.detectionRange * ai.detectionRange) {
          // Spotted!
          newAI = ai.copyWith(
            currentState: AIState.chase,
            lastStateChange: now,
            lastSeenPosition: playerPosition,
          );
          aiChanged = true;
          LogService.info('AI', 'SPOTTED', {'entity': entity.id});
        }
        break;

      // 2. CHASE: Hunt down the player
      case AIState.chase:
        if (hasLOS) {
          newAI = newAI.copyWith(lastSeenPosition: playerPosition);
          aiChanged = true;

          // Transition to Attack if in range and cooldown ready for a "check"
          // (We don't want to instant-attack, giving player reaction time)
          if (distToPlayer <= ai.attackRange) {
            // Only attack if we haven't just attacked
            if (timeSinceAttack >= ai.attackCooldown) {
              newAI = newAI.copyWith(
                currentState: AIState.attack,
                lastStateChange: now,
              );
              aiChanged = true;
              break;
            }
          }
        }

        final target = newAI.lastSeenPosition ?? playerPosition;

        // Stop chasing if reached last known spot and can't see player
        if ((transform.position - target).length < 0.5 && !hasLOS) {
          newAI = newAI.copyWith(
            currentState: AIState.idle,
            lastStateChange: now,
            cachedMoveVelocity: null, // OPT: clear stale velocity on stop
          );
          aiChanged = true;
        } else {
          final (movedTransform, velocity) = _moveToward(
            dt,
            newAI,
            entity.id,
            transform,
            target,
            map,
            allEntities,
            playerPosition,
          );
          newTransform = movedTransform;
          // OPT: Cache velocity so WorldBloc can apply it at 60Hz between 20Hz AI ticks.
          newAI = newAI.copyWith(cachedMoveVelocity: velocity);
          aiChanged = true;
          transformChanged = true;
        }
        break;

      // 3. ATTACK
      case AIState.attack:
        // Always face player
        final dir = playerPosition - transform.position;
        newTransform = transform.copyWith(
          rotation: math.atan2(dir.y, dir.x),
        );
        transformChanged = true;

        // Ranged enemies strafe perpendicular to maintain an unpredictable
        // lateral position — makes them harder to hit. They change direction
        // every 1.5 seconds using their entity ID for deterministic phase.
        if (ai.attackType != AIAttackType.melee && distToPlayer > 1.5) {
          final toPlayer = (playerPosition - transform.position).normalized();
          final strafePhase = (timeInState / 1.5).floor();
          // XOR with hash so different enemies strafe in opposite directions
          final strafeSign =
              (entity.id.hashCode ^ strafePhase) % 2 == 0 ? 1.0 : -1.0;
          final strafeDir = v64.Vector2(
            -toPlayer.y * strafeSign,
            toPlayer.x * strafeSign,
          );
          final strafeTarget = transform.position + strafeDir * 4.0;
          final (strafedTransform, _) = _moveToward(
            dt, newAI, entity.id, newTransform, strafeTarget,
            map, allEntities, playerPosition,
          );
          // Keep the player-facing rotation, not the strafed movement rotation
          newTransform = strafedTransform.copyWith(
            rotation: math.atan2(dir.y, dir.x),
          );
        }

        if (!hasLOS || distToPlayer > ai.attackRange * 1.5) {
          // target lost or fled
          newAI = ai.copyWith(
            currentState: AIState.chase,
            lastStateChange: now,
          );
          aiChanged = true;
        } else {
          // Perform Attack
          // Animation timing: usually attack triggers at specific frame, but we'll use timer
          if (timeInState >= ai.reactionTime &&
              timeSinceAttack >= ai.attackCooldown) {
            // EXECUTE ATTACK
            switch (ai.attackType) {
              case AIAttackType.melee:
                // Check cooldown again for safety (though parent check should cover it)
                if (timeSinceAttack >= ai.attackCooldown) {
                  if (distToPlayer <= 1.5) {
                    damageDealt = ai.meleeDamage;
                    LogService.info('AI', 'MELEE_HIT', {'dmg': damageDealt});
                  }
                }
                break;

              case AIAttackType.projectile:
                final pDir = (playerPosition - transform.position).normalized();
                spawnedProjectiles.add(
                  Projectile(
                    id: _uuid.v4(),
                    ownerId: entity.id,
                    position:
                        transform.position +
                        pDir * 0.5, // Spawn slightly in front
                    velocity: pDir * ai.projectileSpeed,
                    damage: ai.projectileDamage,
                    ammoType: AmmoType
                        .normal, // Enemy projectiles usually don't bounce (Doom)
                    isEnemy: true,
                    renderStyle: ProjectileRenderStyle.plasma,
                  ),
                );
                LogService.info('AI', 'FIRED_PROJ', {'id': entity.id});
                break;

              case AIAttackType.hitscan:
                // Accuracy degrades with distance — fair and avoidable at range.
                // Close range (<=3u): ~95% hit. At full detection range: ~30%.
                final normalizedDist =
                    (distToPlayer / ai.detectionRange).clamp(0.0, 1.0);
                final hitChance = 0.95 - normalizedDist * 0.65;
                if (math.Random().nextDouble() <= hitChance) {
                  damageDealt = ai.projectileDamage;
                  LogService.info('AI', 'HITSCAN_FIRE', {
                    'dmg': damageDealt,
                    'acc': hitChance.toStringAsFixed(2),
                  });
                } else {
                  LogService.info('AI', 'HITSCAN_MISS', {
                    'dist': distToPlayer.toStringAsFixed(1),
                  });
                }
                break;
            }

            // Attack complete -> Cooldown state or back to chase
            // Doom monsters usually go back to Chase state immediately after firing
            newAI = newAI.copyWith(
              currentState: AIState.chase,
              lastStateChange: now,
              lastAttackTime: now,
            );
            aiChanged = true;
          }
        }
        break;

      // 4. PAIN
      case AIState.pain:
        if (timeInState > 0.4) {
          newAI = ai.copyWith(
            currentState: AIState.chase,
            lastStateChange: now,
          );
          aiChanged = true;
        }
        break;

      // 5. DIE (Do nothing, just drift into the void... waiting for animation to finish)
      case AIState.die:
        break;
    }

    // --- ANIMATION SYNC ---
    if (anim != null) {
      String targetAnim = 'idle';
      switch (newAI.currentState) {
        case AIState.idle:
        case AIState.patrol:
          targetAnim = 'idle';
          break;
        case AIState.investigate: // Moves like walking — reuse walk frames
        case AIState.chase:
          targetAnim = 'walk';
          break;
        case AIState.attack:
          targetAnim = 'attack';
          break;
        case AIState.pain:
          targetAnim = 'pain';
          break;
        case AIState.die:
          targetAnim = 'die';
          break;
      }

      if (anim.currentState != targetAnim) {
        newAnim = anim.copyWith(
          currentState: targetAnim,
          currentFrame: 0,
          timer: 0,
        );
        animChanged = true;
      }
    }

    if (transformChanged ||
        aiChanged ||
        animChanged ||
        damageDealt > 0 ||
        spawnedProjectiles.isNotEmpty) {
      return AIUpdateResult(
        entityId: entity.id,
        newTransform: newTransform,
        newAI: newAI,
        newAnim: newAnim,
        damageDealt: damageDealt,
        spawnedProjectiles: spawnedProjectiles,
      );
    }

    return null;
  }

  /// Returns `(newTransform, velocity)` — velocity is cached by WorldBloc for
  /// smooth 60Hz interpolation between 20Hz AI updates.
  (TransformComponent, v64.Vector2) _moveToward(
    double dt,
    AIComponent ai,
    String entityId,
    TransformComponent transform,
    v64.Vector2 target,
    GameMap? map,
    List<GameEntity> otherEntities,
    v64.Vector2 playerPosition,
  ) {
    var direction = target - transform.position;
    final distance = direction.length;

    if (distance <= 0.1) return (transform, v64.Vector2.zero());

    direction = direction.normalized();

    // [FIX] Stop-before-contact: if already within minimum contact distance,
    // only update rotation — do not attempt movement that would generate overlap.
    // minContactDist = 0.3 (enemy radius) + 0.3 (player radius) + 0.05 (margin) = 0.65
    const minContactDist = 0.65;
    if (distance <= minContactDist) {
      final newRotation = math.atan2(direction.y, direction.x);
      return (transform.copyWith(rotation: newRotation), v64.Vector2.zero());
    }

    final velocity = direction * ai.moveSpeed;

    // Include player as a solid entity for the enemy's collision check
    final collisionEntities = [...otherEntities];
    collisionEntities.add(
      GameEntity(
        id: 'player',
        components: [TransformComponent(position: playerPosition)],
      ),
    );

    final newPos = PhysicsSystem.tryMove(
      entityId,
      transform.position,
      velocity,
      dt,
      map,
      collisionEntities,
      radius: 0.3,
    );

    final newRotation = math.atan2(direction.y, direction.x);
    return (transform.copyWith(position: newPos, rotation: newRotation), velocity);
  }
}

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
    GameMap? map,
  ) {
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
  ) {
    if (ai.currentState == AIState.die) {
      // TODO: Handle death animation completion/deactivation here if needed
      return null;
    }

    final distToPlayer = (playerPosition - transform.position).length;
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

    // --- STATE MACHINE ---
    final now = DateTime.now();

    // Time since last state transition
    final timeInState = ai.lastStateChange != null
        ? now.difference(ai.lastStateChange!).inMilliseconds / 1000.0
        : 0.0;

    // Time since last attack (for cooldowns)
    final timeSinceAttack = ai.lastAttackTime != null
        ? now.difference(ai.lastAttackTime!).inMilliseconds / 1000.0
        : 999.0;

    if (entity.id == 'enemy_1') {
      LogService.info('AI', 'CheckLOS', {
        'id': entity.id,
        'dist': distToPlayer.toStringAsFixed(2),
        'hasLOS': hasLOS,
        'state': ai.currentState.toString(),
        'cooldown': timeSinceAttack.toStringAsFixed(1),
        'rng': ai.attackRange,
      });
    }

    switch (ai.currentState) {
      // 1. IDLE: Wait for player to be seen
      case AIState.idle:
      case AIState.patrol:
        if (hasLOS && distToPlayer <= ai.detectionRange) {
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
          );
          aiChanged = true;
        } else {
          final moveResult = _moveToward(
            dt,
            newAI,
            entity.id,
            transform,
            target,
            map,
            allEntities,
            playerPosition,
          );
          newTransform = moveResult;
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
                  ),
                );
                LogService.info('AI', 'FIRED_PROJ', {'id': entity.id});
                break;

              case AIAttackType.hitscan:
                // Simple hitscan check
                // In Doom, enemies assume they hit if looking at you basically (with RNG spread)
                // We'll trust the component damage
                damageDealt = ai.projectileDamage;
                // Create visual trail? (TODO)
                LogService.info('AI', 'HITSCAN_FIRE', {'dmg': damageDealt});
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

      default:
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
      if (entity.id == 'enemy_1') {
        LogService.info('AI', 'RESULT', {
          'state': newAI.currentState.toString(),
          'anim': newAnim?.currentState ?? 'null',
          'pos': newTransform.position.y.toStringAsFixed(2),
        });
      }

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

  TransformComponent _moveToward(
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

    if (distance > 0.1) {
      direction = direction.normalized();
      final velocity = direction * ai.moveSpeed;

      // Optimized collision list reuse
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
      return transform.copyWith(position: newPos, rotation: newRotation);
    }
    return transform;
  }
}

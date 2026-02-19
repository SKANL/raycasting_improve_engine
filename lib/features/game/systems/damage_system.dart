import 'dart:math' as math;

import 'package:raycasting_game/features/core/ecs/components/health_component.dart';
import 'package:raycasting_game/features/core/world/models/game_entity.dart';
import 'package:raycasting_game/features/game/ai/components/ai_component.dart';

/// Result of applying damage to a single entity.
class EntityDamageResult {
  const EntityDamageResult({
    required this.entityId,
    required this.newHealth,
    required this.died,
    required this.enteredPain,
  });

  final String entityId;
  final int newHealth;
  final bool died;

  /// True if the entity should transition to [AIState.pain] (AI only)
  final bool enteredPain;
}

/// Centralized damage application system.
///
/// Mirrors Doom's `P_DamageMobj`: applies health reduction, rolls
/// pain chance, and detects death. Does NOT modify entities directly —
/// returns results that [WorldBloc] applies to keep state immutable.
class DamageSystem {
  /// Apply [damageMap] (entityId → damage points) to the entity list.
  ///
  /// [rng] is provided for deterministic pain chance rolls in tests.
  static List<EntityDamageResult> apply(
    List<GameEntity> entities,
    Map<String, int> damageMap,
    math.Random rng,
  ) {
    final results = <EntityDamageResult>[];

    for (final entry in damageMap.entries) {
      final entityId = entry.key;
      final damage = entry.value;

      final entity = _findEntity(entities, entityId);
      if (entity == null) continue;

      final health = entity.getComponent<HealthComponent>();
      if (health == null) continue;

      // Skip invulnerable entities
      if (health.isInvulnerable) continue;

      final newHealth = math.max(0, health.current - damage);
      final died = newHealth <= 0;

      // Pain chance: only roll if still alive and entity has an AI
      bool enteredPain = false;
      if (!died) {
        final ai = entity.getComponent<AIComponent>();
        if (ai != null && ai.currentState != AIState.die) {
          enteredPain = rng.nextDouble() < ai.painChance;
        }
      }

      results.add(
        EntityDamageResult(
          entityId: entityId,
          newHealth: newHealth,
          died: died,
          enteredPain: enteredPain,
        ),
      );
    }

    return results;
  }

  /// Apply damage to the player (not an entity, managed in WorldState).
  ///
  /// Returns the new health value (clamped to 0).
  static int applyToPlayer(int currentHealth, int damage) {
    return math.max(0, currentHealth - damage);
  }

  static GameEntity? _findEntity(List<GameEntity> entities, String id) {
    for (final e in entities) {
      if (e.id == id) return e;
    }
    return null;
  }
}

import 'dart:math' as math;

import 'package:raycasting_game/core/logging/log_service.dart';
import 'package:raycasting_game/features/core/ecs/components/transform_component.dart';
import 'package:raycasting_game/features/core/world/models/game_entity.dart';
import 'package:raycasting_game/features/game/ai/components/ai_component.dart';
import 'package:raycasting_game/features/game/ai/models/ai_state.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

/// Result of AI update containing entity ID and new components
class AIUpdateResult {
  const AIUpdateResult({
    required this.entityId,
    required this.newTransform,
    required this.newAI,
  });

  final String entityId;
  final TransformComponent newTransform;
  final AIComponent newAI;
}

/// System that updates AI entities each frame
class AISystem {
  /// Update all AI entities and return list of updates to apply
  List<AIUpdateResult> update(
    double dt,
    List<GameEntity> entities,
    v64.Vector2 playerPosition,
  ) {
    final updates = <AIUpdateResult>[];

    for (final entity in entities) {
      final ai = entity.getComponent<AIComponent>();
      final transform = entity.getComponent<TransformComponent>();

      if (ai == null || transform == null || !entity.isActive) continue;

      final result = _updateAI(dt, entity, ai, transform, playerPosition);
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
  ) {
    final distanceToPlayer = (playerPosition - transform.position).length;
    var aiChanged = false;
    var transformChanged = false;
    var newAI = ai;
    var newTransform = transform;

    // State transitions
    switch (ai.currentState) {
      case AIState.patrol:
        if (distanceToPlayer <= ai.detectionRange) {
          newAI = AIComponent(
            currentState: AIState.chase,
            targetPosition: ai.targetPosition,
            detectionRange: ai.detectionRange,
            attackRange: ai.attackRange,
            moveSpeed: ai.moveSpeed,
            lastStateChange: DateTime.now(),
          );
          aiChanged = true;
          LogService.info('AI', 'STATE_CHANGE', {
            'entity': entity.id,
            'from': 'patrol',
            'to': 'chase',
          });
        } else {
          final result = _patrol(dt, ai, transform);
          if (result != null) {
            newTransform = result.transform;
            newAI = result.ai;
            transformChanged = true;
            aiChanged = result.aiChanged;
          }
        }
      case AIState.chase:
        if (distanceToPlayer <= ai.attackRange) {
          newAI = AIComponent(
            currentState: AIState.attack,
            targetPosition: ai.targetPosition,
            detectionRange: ai.detectionRange,
            attackRange: ai.attackRange,
            moveSpeed: ai.moveSpeed,
            lastStateChange: DateTime.now(),
          );
          aiChanged = true;
          LogService.info('AI', 'STATE_CHANGE', {
            'entity': entity.id,
            'from': 'chase',
            'to': 'attack',
          });
        } else if (distanceToPlayer > ai.detectionRange * 1.5) {
          // Lost player, return to patrol
          newAI = AIComponent(
            currentState: AIState.patrol,
            detectionRange: ai.detectionRange,
            attackRange: ai.attackRange,
            moveSpeed: ai.moveSpeed,
            lastStateChange: DateTime.now(),
          );
          aiChanged = true;
        } else {
          final result = _chase(dt, ai, transform, playerPosition);
          if (result != null) {
            newTransform = result.transform;
            transformChanged = true;
          }
        }
      case AIState.attack:
        if (distanceToPlayer > ai.attackRange * 1.2) {
          // Player moved away, resume chase
          newAI = AIComponent(
            currentState: AIState.chase,
            targetPosition: ai.targetPosition,
            detectionRange: ai.detectionRange,
            attackRange: ai.attackRange,
            moveSpeed: ai.moveSpeed,
            lastStateChange: DateTime.now(),
          );
          aiChanged = true;
        } else {
          final result = _attack(dt, ai, transform, playerPosition);
          if (result != null) {
            newTransform = result.transform;
            newAI = result.ai;
            transformChanged = result.transform != transform;
            aiChanged = result.aiChanged;
          }
        }
    }

    if (transformChanged || aiChanged) {
      return AIUpdateResult(
        entityId: entity.id,
        newTransform: newTransform,
        newAI: newAI,
      );
    }

    return null;
  }

  _MovementResult? _patrol(
    double dt,
    AIComponent ai,
    TransformComponent transform,
  ) {
    // Simple random walk
    var targetPos = ai.targetPosition;
    var aiChanged = false;

    if (targetPos == null || (transform.position - targetPos).length < 0.5) {
      // Pick new random target nearby
      final random = math.Random();
      final angle = random.nextDouble() * math.pi * 2;
      final distance = 3 + random.nextDouble() * 5;
      targetPos =
          transform.position +
          v64.Vector2(
            math.cos(angle) * distance,
            math.sin(angle) * distance,
          );
      aiChanged = true;
    }

    final moveResult = _moveToward(dt, ai, transform, targetPos);

    return _MovementResult(
      transform: moveResult,
      ai: aiChanged
          ? AIComponent(
              currentState: ai.currentState,
              targetPosition: targetPos,
              detectionRange: ai.detectionRange,
              attackRange: ai.attackRange,
              moveSpeed: ai.moveSpeed,
              lastStateChange: ai.lastStateChange,
            )
          : ai,
      aiChanged: aiChanged,
    );
  }

  _MovementResult? _chase(
    double dt,
    AIComponent ai,
    TransformComponent transform,
    v64.Vector2 playerPosition,
  ) {
    final newTransform = _moveToward(dt, ai, transform, playerPosition);
    return _MovementResult(transform: newTransform, ai: ai, aiChanged: false);
  }

  _MovementResult? _attack(
    double dt,
    AIComponent ai,
    TransformComponent transform,
    v64.Vector2 playerPosition,
  ) {
    // Face player but don't move
    final direction = playerPosition - transform.position;
    final newRotation = math.atan2(direction.y, direction.x);

    // Attack cooldown logic
    final now = DateTime.now();
    var aiChanged = false;
    var newAI = ai;

    if (ai.lastStateChange == null ||
        now.difference(ai.lastStateChange!).inSeconds >= 2) {
      LogService.info('AI', 'ATTACK', {'position': transform.position});
      newAI = AIComponent(
        currentState: ai.currentState,
        targetPosition: ai.targetPosition,
        detectionRange: ai.detectionRange,
        attackRange: ai.attackRange,
        moveSpeed: ai.moveSpeed,
        lastStateChange: now,
      );
      aiChanged = true;
    }

    return _MovementResult(
      transform: transform.copyWith(rotation: newRotation),
      ai: newAI,
      aiChanged: aiChanged,
    );
  }

  TransformComponent _moveToward(
    double dt,
    AIComponent ai,
    TransformComponent transform,
    v64.Vector2 target,
  ) {
    final direction = target - transform.position;
    final distance = direction.length;

    if (distance > 0.1) {
      final normalized = direction.normalized();
      final movement = normalized * ai.moveSpeed * dt;
      final newRotation = math.atan2(direction.y, direction.x);

      return transform.copyWith(
        position: transform.position + movement,
        rotation: newRotation,
      );
    }

    return transform;
  }
}

class _MovementResult {
  const _MovementResult({
    required this.transform,
    required this.ai,
    required this.aiChanged,
  });

  final TransformComponent transform;
  final AIComponent ai;
  final bool aiChanged;
}

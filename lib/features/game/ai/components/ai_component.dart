import 'package:raycasting_game/features/core/ecs/models/component.dart';
import 'package:raycasting_game/features/game/ai/models/ai_state.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

/// AI component for enemy entities
class AIComponent extends GameComponent {
  const AIComponent({
    this.currentState = AIState.patrol,
    this.targetPosition,
    this.detectionRange = 10,
    this.attackRange = 2,
    this.moveSpeed = 2,
    this.lastStateChange,
  });

  /// Current FSM state
  final AIState currentState;

  /// Target position for patrol waypoints or chase destination
  final v64.Vector2? targetPosition;

  /// Vision radius for player detection
  final double detectionRange;

  /// Range at which AI stops and attacks
  final double attackRange;

  /// Movement speed in units per second
  final double moveSpeed;

  /// Timestamp of last state transition (for cooldowns)
  final DateTime? lastStateChange;

  /// Create a copy with updated fields
  AIComponent copyWith({
    AIState? currentState,
    v64.Vector2? targetPosition,
    double? detectionRange,
    double? attackRange,
    double? moveSpeed,
    DateTime? lastStateChange,
  }) {
    return AIComponent(
      currentState: currentState ?? this.currentState,
      targetPosition: targetPosition ?? this.targetPosition,
      detectionRange: detectionRange ?? this.detectionRange,
      attackRange: attackRange ?? this.attackRange,
      moveSpeed: moveSpeed ?? this.moveSpeed,
      lastStateChange: lastStateChange ?? this.lastStateChange,
    );
  }

  @override
  List<Object?> get props => [
    currentState,
    targetPosition,
    detectionRange,
    attackRange,
    moveSpeed,
    lastStateChange,
  ];
}

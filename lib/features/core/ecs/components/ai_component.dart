import 'package:raycasting_game/features/core/ecs/models/component.dart';

enum AIState { idle, patrolling, chasing, attacking }

class AIComponent extends GameComponent {
  const AIComponent({
    this.state = AIState.idle,
    this.detectionRange = 10.0,
    this.attackRange = 1.0,
    this.moveSpeed = 1.0,
  });

  final AIState state;
  final double detectionRange;
  final double attackRange;
  final double moveSpeed;

  AIComponent copyWith({
    AIState? state,
    double? detectionRange,
    double? attackRange,
    double? moveSpeed,
  }) {
    return AIComponent(
      state: state ?? this.state,
      detectionRange: detectionRange ?? this.detectionRange,
      attackRange: attackRange ?? this.attackRange,
      moveSpeed: moveSpeed ?? this.moveSpeed,
    );
  }

  @override
  List<Object?> get props => [state, detectionRange, attackRange, moveSpeed];
}

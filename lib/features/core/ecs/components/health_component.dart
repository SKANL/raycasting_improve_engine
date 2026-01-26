import 'package:raycasting_game/features/core/ecs/models/component.dart';

class HealthComponent extends GameComponent {
  const HealthComponent({
    required this.current,
    required this.max,
    this.isInvulnerable = false,
  });

  final int current;
  final int max;
  final bool isInvulnerable;

  bool get isDead => current <= 0;

  HealthComponent copyWith({
    int? current,
    int? max,
    bool? isInvulnerable,
  }) {
    return HealthComponent(
      current: current ?? this.current,
      max: max ?? this.max,
      isInvulnerable: isInvulnerable ?? this.isInvulnerable,
    );
  }

  @override
  List<Object?> get props => [current, max, isInvulnerable];
}

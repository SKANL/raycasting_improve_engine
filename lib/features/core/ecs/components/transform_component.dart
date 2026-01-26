import 'package:raycasting_game/features/core/ecs/models/component.dart';
import 'package:vector_math/vector_math_64.dart';

class TransformComponent extends GameComponent {
  const TransformComponent({
    required this.position,
    this.rotation = 0.0,
    this.scale = 1.0,
  });

  final Vector2 position;
  final double rotation;
  final double scale;

  TransformComponent copyWith({
    Vector2? position,
    double? rotation,
    double? scale,
  }) {
    return TransformComponent(
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
    );
  }

  @override
  List<Object?> get props => [position, rotation, scale];
}

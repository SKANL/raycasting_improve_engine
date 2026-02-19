import 'package:raycasting_game/features/core/ecs/models/component.dart';

class RenderComponent extends GameComponent {
  const RenderComponent({
    required this.spritePath,
    this.width = 32.0,
    this.height = 32.0,
    this.isVisible = true,
    this.opacity = 1.0,
  });

  /// Path to the sprite asset or atlas key.
  final String spritePath;

  /// World width.
  final double width;

  /// World height.
  final double height;

  final bool isVisible;

  /// Opacity for fade effects (0.0 to 1.0).
  final double opacity;

  RenderComponent copyWith({
    String? spritePath,
    double? width,
    double? height,
    bool? isVisible,
    double? opacity,
  }) {
    return RenderComponent(
      spritePath: spritePath ?? this.spritePath,
      width: width ?? this.width,
      height: height ?? this.height,
      isVisible: isVisible ?? this.isVisible,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  List<Object?> get props => [spritePath, width, height, isVisible, opacity];
}

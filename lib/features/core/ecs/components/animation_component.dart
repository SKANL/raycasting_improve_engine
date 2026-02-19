import 'dart:ui';
import 'package:raycasting_game/features/core/ecs/models/component.dart';

/// Defines an animation state (e.g., 'idle', 'walk', 'attack').
class AnimationState {
  const AnimationState({
    required this.name,
    required this.frames,
    this.frameDuration = 0.2,
    this.loop = true,
  });

  final String name;
  final List<Rect> frames;
  final double frameDuration;
  final bool loop;
}

/// Component that handles sprite animations.
class AnimationComponent extends GameComponent {
  AnimationComponent({
    required this.animations,
    required this.currentState,
    this.currentFrame = 0,
    this.timer = 0.0,
  });

  final Map<String, AnimationState> animations;
  final String currentState;
  final int currentFrame;
  final double timer;

  Rect get currentSprite =>
      animations[currentState]?.frames[currentFrame] ?? Rect.zero;

  AnimationComponent copyWith({
    Map<String, AnimationState>? animations,
    String? currentState,
    int? currentFrame,
    double? timer,
  }) {
    return AnimationComponent(
      animations: animations ?? this.animations,
      currentState: currentState ?? this.currentState,
      currentFrame: currentFrame ?? this.currentFrame,
      timer: timer ?? this.timer,
    );
  }
}

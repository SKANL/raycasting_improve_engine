import 'dart:math';
import 'dart:ui';

import 'package:raycasting_game/features/game/render/vfx/particle.dart';
import 'package:vector_math/vector_math_64.dart';

class ParticleSystem {
  final List<Particle> _particles = [];
  final Random _rng = Random();

  List<Particle> get particles => _particles;

  void update(double dt) {
    for (var i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.update(dt);
      if (p.isDead) {
        _particles.removeAt(i);
      }
    }
  }

  void emit({
    required Vector2 position,
    int count = 1,
    double speed = 1.0,
    double spread = pi / 4,
    double direction = 0.0,
    double life = 0.5,
    Rect? textureRect,
    Color? color,
    double scale = 0.5,
  }) {
    textureRect ??= const Rect.fromLTWH(0, 0, 32, 32); // Default sprite

    for (var i = 0; i < count; i++) {
      final angle = direction + (_rng.nextDouble() - 0.5) * spread;
      final vel =
          Vector2(cos(angle), sin(angle)) *
          (speed * (0.5 + _rng.nextDouble() * 0.5));

      _particles.add(
        Particle(
          position: position.clone(),
          velocity: vel,
          life: life * (0.8 + _rng.nextDouble() * 0.4),
          textureRect: textureRect,
          scale: scale * (0.8 + _rng.nextDouble() * 0.4),
          color: color ?? const Color(0xFFFFFFFF),
        ),
      );
    }
  }
}

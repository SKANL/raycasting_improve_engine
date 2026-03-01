import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Subtle ambient particles that float across the screen,
/// complementing the video background with a digital dust effect.
class AmbientParticles extends PositionComponent with HasGameReference {
  AmbientParticles({this.particleCount = 20});

  final int particleCount;
  final List<_Particle> _particles = [];
  final Random _rng = Random();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final screenW = game.size.x;
    final screenH = game.size.y;

    for (var i = 0; i < particleCount; i++) {
      _particles.add(
        _Particle(
          x: _rng.nextDouble() * screenW,
          y: _rng.nextDouble() * screenH,
          vx: (_rng.nextDouble() - 0.5) * 15, // -7.5 to 7.5 px/s
          vy: (_rng.nextDouble() - 0.5) * 10, // -5 to 5 px/s
          radius: _rng.nextDouble() * 2.5 + 0.5, // 0.5 to 3 px
          opacity: _rng.nextDouble() * 0.4 + 0.1, // 0.1 to 0.5
          pulseSpeed: _rng.nextDouble() * 2 + 0.5,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final screenW = game.size.x;
    final screenH = game.size.y;

    for (final p in _particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.age += dt;

      // Wrap around screen edges
      if (p.x < -10) p.x = screenW + 10;
      if (p.x > screenW + 10) p.x = -10;
      if (p.y < -10) p.y = screenH + 10;
      if (p.y > screenH + 10) p.y = -10;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    for (final p in _particles) {
      // Pulsing opacity
      final pulse = (sin(p.age * p.pulseSpeed) * 0.5 + 0.5);
      final alpha = (p.opacity * pulse * 255).toInt().clamp(0, 255);

      final paint = Paint()
        ..color =
            Color.fromARGB(alpha, 0, 229, 255) // #00E5FF
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
    }
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.opacity,
    required this.pulseSpeed,
  });

  double x;
  double y;
  final double vx;
  final double vy;
  final double radius;
  final double opacity;
  final double pulseSpeed;
  double age = 0;
}

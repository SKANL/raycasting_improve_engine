import 'dart:ui';
import 'package:vector_math/vector_math_64.dart';

class Particle {
  Particle({
    required this.position,
    required this.velocity,
    required this.life,
    required this.textureRect,
    this.scale = 1.0,
    this.gravity = 0.0,
  });

  Vector2 position;
  Vector2 velocity;
  double life;
  double maxLife = 1;
  Rect textureRect;
  double scale;
  double gravity;

  void update(double dt) {
    position += velocity * dt;
    // velocity.y += gravity * dt; // If we want 3D gravity, we need z?
    // For top-down 2D raycaster, "gravity" usually means falling to floor (Z axis).
    // But our engine is pseudo-3D. position is X/Y on map.
    // If we want particles to "fall", we need Z height simulation relative to "floor".
    // For now, let's stick to X/Y movement (e.g. smoke, blood).
    life -= dt;
  }

  bool get isDead => life <= 0;
}

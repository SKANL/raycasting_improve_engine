import 'dart:ui';
import 'package:flame/components.dart';

class DamageFlashComponent extends PositionComponent with HasGameRef {
  DamageFlashComponent() : super(priority: 100);

  double _opacity = 0.0;
  final Paint _paint = Paint()..color = const Color(0xFFFF0000);

  void flash() {
    _opacity = 0.5;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void update(double dt) {
    if (_opacity > 0) {
      _opacity -= dt * 1.0; // Fade out speed
      if (_opacity < 0) _opacity = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    if (_opacity > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, gameRef.size.x, gameRef.size.y),
        _paint..color = _paint.color.withOpacity(_opacity),
      );
    }
  }
}

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class GameOverOverlay extends PositionComponent with HasGameRef {
  GameOverOverlay() : super(priority: 200, anchor: Anchor.center);

  late TextComponent _text;

  @override
  Future<void> onLoad() async {
    _text = TextComponent(
      text: 'GAME OVER',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 48,
          color: Colors.red,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              blurRadius: 4,
              color: Colors.black,
              offset: Offset(2, 2),
            ),
          ],
        ),
      ),
      anchor: Anchor.center,
    );
    add(_text);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    position = size / 2;
  }
}

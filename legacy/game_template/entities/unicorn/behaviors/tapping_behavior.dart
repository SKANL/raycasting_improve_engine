import 'package:audioplayers/audioplayers.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:raycasting_game/game/game.dart';
import 'package:raycasting_game/gen/assets.gen.dart';

class TappingBehavior extends Behavior<Unicorn>
    with TapCallbacks, HasGameReference<RaycastingGame> {
  @override
  bool containsLocalPoint(Vector2 point) {
    return parent.containsLocalPoint(point);
  }

  @override
  Future<void> onTapDown(TapDownEvent event) async {
    if (parent.isAnimationPlaying()) {
      return;
    }
    game.counter++;
    parent.playAnimation();

    await game.effectPlayer.play(AssetSource(Assets.audio.effect));
  }
}

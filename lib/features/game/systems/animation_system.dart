import 'package:raycasting_game/features/core/ecs/components/animation_component.dart';
import 'package:raycasting_game/features/core/world/models/game_entity.dart';

/// System that advances animation timers for all entities with AnimationComponent.
class AnimationSystem {
  List<GameEntity> update(double dt, List<GameEntity> entities) {
    var changed = false;
    final updatedEntities = List<GameEntity>.from(entities);

    for (var i = 0; i < updatedEntities.length; i++) {
      final entity = updatedEntities[i];
      if (!entity.isActive) continue;

      final anim = entity.getComponent<AnimationComponent>();
      if (anim == null) continue;

      final state = anim.animations[anim.currentState];
      if (state == null || state.frames.isEmpty) continue;

      // Update timer
      var newTimer = anim.timer + dt;
      var newFrame = anim.currentFrame;

      if (newTimer >= state.frameDuration) {
        newTimer -= state.frameDuration;
        newFrame++;

        if (newFrame >= state.frames.length) {
          if (state.loop) {
            newFrame = 0;
          } else {
            newFrame = state.frames.length - 1; // Clamp at end
          }
        }
      }

      if (newFrame != anim.currentFrame || newTimer != anim.timer) {
        updatedEntities[i] = entity.copyWith(
          components: entity.components.map((c) {
            if (c is AnimationComponent) {
              if (entity.id == 'enemy_1' && newFrame != anim.currentFrame) {
                print(
                  '[ANIM] Entity ${entity.id} Frame: $newFrame State: ${anim.currentState}',
                );
              }
              return anim.copyWith(
                currentFrame: newFrame,
                timer: newTimer,
              );
            }
            return c;
          }).toList(),
        );
        changed = true;
      }
    }

    return changed ? updatedEntities : entities;
  }
}

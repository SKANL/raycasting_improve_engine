import 'package:raycasting_game/features/core/ecs/components/animation_component.dart';
import 'package:raycasting_game/features/core/ecs/components/render_component.dart';
import 'package:raycasting_game/features/core/world/models/game_entity.dart';

/// System that advances animation timers for all entities with AnimationComponent.
class AnimationSystem {
  List<GameEntity> update(double dt, List<GameEntity> entities) {
    // OPT: Lazy copy — only allocate a mutable list when at least one entity
    // actually changes. Most frames (idle scenes, no enemies near) change
    // nothing, so we avoid the O(n) List.from allocation entirely.
    List<GameEntity>? updatedEntities;

    for (var i = 0; i < entities.length; i++) {
      final entity = entities[i];
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

      // --- FADE OUT LOGIC ---
      // Check if this is a finished death animation
      // "die" state + non-looping + finished last frame
      var newOpacity = 1.0;
      var shouldRemove = false;

      final render = entity.getComponent<RenderComponent>();
      if (render != null) {
        newOpacity = render.opacity;

        // If we are in 'die' state and finished the animation (last frame)
        if (anim.currentState == 'die' && newFrame == state.frames.length - 1) {
          // Start fading out
          newOpacity -= dt * 0.5; // Fade over 2 seconds
          if (newOpacity <= 0) {
            newOpacity = 0;
            shouldRemove = true;
          }
        }
      }

      if (newFrame != anim.currentFrame ||
          newTimer != anim.timer ||
          (render != null && render.opacity != newOpacity)) {
        // OPT: Lazy alloc — only pay the O(n) copy cost on the first mutation.
        updatedEntities ??= List<GameEntity>.from(entities);
        updatedEntities[i] = entity.copyWith(
          isActive: !shouldRemove, // Deactivate if fully faded
          components: entity.components.map((c) {
            if (c is AnimationComponent) {
              return anim.copyWith(
                currentFrame: newFrame,
                timer: newTimer,
              );
            }
            if (c is RenderComponent) {
              return c.copyWith(opacity: newOpacity);
            }
            return c;
          }).toList(),
        );
      }
    }

    return updatedEntities ?? entities;
  }
}

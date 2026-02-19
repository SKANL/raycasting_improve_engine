import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:raycasting_game/features/game/systems/physics_system.dart';
import 'package:raycasting_game/features/core/world/models/game_entity.dart';
import 'package:raycasting_game/features/core/ecs/components/transform_component.dart';
import 'package:raycasting_game/features/core/world/models/game_map.dart';

void main() {
  group('PhysicsSystem Diagnostics', () {
    test('raycastEntities detects close entity', () {
      final playerPos = Vector2(1.5, 1.5);
      final enemyPos = Vector2(1.5, 2.0); // 0.5 units away
      final direction = Vector2(0, 1); // Looking +Y

      final enemy = GameEntity(
        id: 'enemy_1',
        components: [TransformComponent(position: enemyPos)],
      );

      final hitId = PhysicsSystem.raycastEntities(
        playerPos,
        direction,
        [enemy],
        GameMap.empty(width: 10, height: 10),
        excludeId: 'player',
      );

      print('Hit ID: $hitId');
      expect(hitId, equals('enemy_1'));
    });

    test('raycastEntities respects hitRadius', () {
      final playerPos = Vector2(1.5, 1.5);
      final enemyPos = Vector2(2.0, 1.5); // 0.5 units away (X axis)
      final direction = Vector2(0, 1); // Looking +Y (Miss)

      // Enemy is at (2.0, 1.5). Ray is x=1.5. Distance is 0.5.
      // HitRadius is 0.4. Should MISS.

      final enemy = GameEntity(
        id: 'enemy_1',
        components: [TransformComponent(position: enemyPos)],
      );

      final hitId = PhysicsSystem.raycastEntities(
        playerPos,
        direction,
        [enemy],
        GameMap.empty(width: 10, height: 10),
        excludeId: 'player',
      );

      print('Hit ID (Miss): $hitId');
      expect(hitId, isNull);
    });
  });
}

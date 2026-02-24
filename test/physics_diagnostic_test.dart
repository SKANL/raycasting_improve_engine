import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:raycasting_game/features/game/systems/physics_system.dart';
import 'package:raycasting_game/features/core/ecs/components/transform_component.dart';
import 'package:raycasting_game/features/core/world/models/game_entity.dart';
import 'package:raycasting_game/features/core/world/models/game_map.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // EXISTING TESTS — raycastEntities
  // ─────────────────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────────────────
  // [FIX] NEW TESTS — Collision Bug: Player Trapped by Enemy Contact
  // ─────────────────────────────────────────────────────────────────────────
  group('PhysicsSystem — Collision Bug Fix (entity overlap escape)', () {
    // Shared map without walls so we can isolate entity collision only.
    final emptyMap = GameMap.empty(width: 20, height: 20);
    const dt = 0.016; // 60fps frame

    test('[FIX-1] Player can escape overlap by moving AWAY from enemy', () {
      // Arrange: set up a pre-existing overlap (dist = 0.4 < minDist 0.6)
      final playerPos = Vector2(5.0, 5.0);
      final enemyPos = Vector2(5.4, 5.0); // 0.4u away — overlapping!

      final enemy = GameEntity(
        id: 'enemy_1',
        components: [TransformComponent(position: enemyPos)],
      );

      // Act: player tries to move LEFT (away from enemy)
      const speed = 3.0;
      final velocity = Vector2(-speed, 0.0); // −X direction
      final newPos = PhysicsSystem.tryMove(
        'player',
        playerPos,
        velocity,
        dt,
        emptyMap,
        [enemy],
        radius: 0.3,
      );

      // Assert: player moved LEFT (X decreased) — escape was ALLOWED
      print('[FIX-1] playerPos: $playerPos → $newPos');
      expect(
        newPos.x,
        lessThan(playerPos.x),
        reason:
            'Player must be able to move away from an enemy even when overlapping',
      );
    });

    test(
      '[FIX-2] Player movement TOWARD enemy is still blocked when overlapping',
      () {
        // Arrange: same overlap setup as FIX-1
        final playerPos = Vector2(5.0, 5.0);
        final enemyPos = Vector2(5.4, 5.0); // overlap at 0.4u

        final enemy = GameEntity(
          id: 'enemy_1',
          components: [TransformComponent(position: enemyPos)],
        );

        // Act: player tries to move RIGHT (deeper into enemy)
        const speed = 3.0;
        final velocity = Vector2(speed, 0.0); // +X direction
        final newPos = PhysicsSystem.tryMove(
          'player',
          playerPos,
          velocity,
          dt,
          emptyMap,
          [enemy],
          radius: 0.3,
        );

        // Assert: X position did NOT increase (movement into overlap is blocked)
        print('[FIX-2] playerPos: $playerPos → $newPos');
        expect(
          newPos.x,
          lessThanOrEqualTo(playerPos.x),
          reason:
              'Player must NOT be able to move deeper into an enemy overlap',
        );
      },
    );

    test('[FIX-3] Normal collision works when no pre-existing overlap exists', () {
      // Arrange: clean state — player well outside the enemy radius
      final playerPos = Vector2(5.0, 5.0);
      final enemyPos = Vector2(5.0, 7.0); // 2.0u away — no overlap

      final enemy = GameEntity(
        id: 'enemy_1',
        components: [TransformComponent(position: enemyPos)],
      );

      // Act: player walks toward the enemy, should be blocked at ~minDist (0.6u)
      const speed = 3.0;
      final velocity = Vector2(0.0, speed); // +Y toward enemy
      final newPos = PhysicsSystem.tryMove(
        'player',
        playerPos,
        velocity,
        dt,
        emptyMap,
        [enemy],
        radius: 0.3,
      );

      // The player should not have reached the enemy position
      final finalDist = newPos.distanceTo(enemyPos);
      print('[FIX-3] finalDist=$finalDist (expect >= 0.6)');
      expect(
        finalDist,
        greaterThanOrEqualTo(0.55), // slight tolerance for sub-stepping
        reason:
            'Normal collision blocking must still work when no overlap exists',
      );
    });
  });
}

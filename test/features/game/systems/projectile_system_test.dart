import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vector_math/vector_math_64.dart' as v64;
import 'package:raycasting_game/features/core/world/models/game_map.dart';
import 'package:raycasting_game/features/core/world/models/game_entity.dart';
import 'package:raycasting_game/features/core/ecs/components/transform_component.dart';
import 'package:raycasting_game/features/game/models/projectile.dart';
import 'package:raycasting_game/features/game/systems/projectile_system.dart';
import 'package:raycasting_game/features/game/weapon/models/ammo_type.dart';

class MockGameMap extends Mock implements GameMap {}

class MockCell extends Mock implements Cell {}

void main() {
  group('ProjectileSystem', () {
    late MockGameMap map;
    late MockCell emptyCell;
    late MockCell wallCell;

    setUp(() {
      map = MockGameMap();
      emptyCell = MockCell();
      wallCell = MockCell();

      when(() => emptyCell.isSolid).thenReturn(false);
      when(() => wallCell.isSolid).thenReturn(true);

      // Default: empty map
      when(() => map.getCell(any(), any())).thenReturn(emptyCell);
      // Wall at (5, 5)
      when(() => map.getCell(5, 5)).thenReturn(wallCell);
    });

    Projectile createProjectile({
      v64.Vector2? pos,
      v64.Vector2? vel,
      bool isEnemy = false,
      int bouncesLeft = 0,
      double maxRange = 100.0,
      String ownerId = 'player',
    }) {
      return Projectile(
        id: 'p1',
        ownerId: ownerId,
        isEnemy: isEnemy,
        damage: 10,
        position: pos ?? v64.Vector2(2.0, 2.0),
        velocity: vel ?? v64.Vector2(10.0, 0.0), // Moving right
        maxRange: maxRange,
        ammoType: bouncesLeft > 0 ? AmmoType.bouncing : AmmoType.normal,
        bouncesLeft: bouncesLeft,
      );
    }

    GameEntity createEntity({required String id, required v64.Vector2 pos}) {
      return GameEntity(
        id: id,
        isActive: true,
        components: [
          TransformComponent(position: pos),
        ],
      );
    }

    test('should move projectile correctly in free space', () {
      final proj = createProjectile();
      final dt = 0.1;

      final result = ProjectileSystem.update(
        [proj],
        [],
        v64.Vector2.zero(),
        map,
        dt,
      );

      expect(result.surviving, hasLength(1));
      final updated = result.surviving.first;
      // Started at (2, 2), vel (10, 0), dt 0.1 -> should be at (3, 2)
      expect(updated.position.x, closeTo(3.0, 0.001));
      expect(updated.position.y, closeTo(2.0, 0.001));
      expect(updated.distanceTraveled, closeTo(1.0, 0.001));
    });

    test('should destroy projectile when hitting wall (no bounce)', () {
      // Start near wall at (5, 5). Wall is at x=5.
      // Pos (4.9, 5.5), moving right (1, 0).
      final proj = createProjectile(
        pos: v64.Vector2(4.9, 5.5),
        vel: v64.Vector2(10.0, 0.0), // Large step to definitely hit
      );

      final result = ProjectileSystem.update(
        [proj],
        [],
        v64.Vector2.zero(),
        map,
        0.1,
      );

      expect(result.surviving, isEmpty);
    });

    test('should bounce projectile when hitting wall (bouncesLeft > 0)', () {
      // Start near wall at (5, 5). Wall is at x=5.
      // Pos (4.5, 5.5), moving right.
      final proj = createProjectile(
        pos: v64.Vector2(4.5, 5.5),
        vel: v64.Vector2(10.0, 0.0),
        bouncesLeft: 1,
      );

      final result = ProjectileSystem.update(
        [proj],
        [],
        v64.Vector2.zero(),
        map,
        0.1,
      );

      expect(result.surviving, hasLength(1));
      final updated = result.surviving.first;

      // Should have bounced
      expect(updated.bouncesLeft, equals(0));
      // Velocity x should be flipped (hitting vertical wall)
      // Bounce factor is 0.7
      expect(updated.velocity.x, closeTo(-7.0, 0.001));
      expect(updated.velocity.y, closeTo(0.0, 0.001));
    });

    test('should hit enemy entity', () {
      final proj = createProjectile(
        pos: v64.Vector2(2.0, 2.0),
        vel: v64.Vector2(10.0, 0.0),
      );
      // Entity in path at (2.5, 2.0)
      final enemy = createEntity(id: 'enemy1', pos: v64.Vector2(2.5, 2.0));

      final result = ProjectileSystem.update(
        [proj],
        [enemy],
        v64.Vector2.zero(),
        map,
        0.05, // 2.0 + 10*0.05 = 2.5
      );

      expect(result.surviving, isEmpty); // Projectile destroyed on hit
      expect(result.entityHits, containsPair('enemy1', 10));
    });

    test('should hit player (enemy projectile)', () {
      final proj = createProjectile(
        pos: v64.Vector2(10.0, 10.0),
        vel: v64.Vector2(1.0, 0.0),
        isEnemy: true,
      );
      // Player at (10.1, 10.0) -> in path
      final playerPos = v64.Vector2(10.1, 10.0);

      final result = ProjectileSystem.update(
        [proj],
        [],
        playerPos, // Player is here
        map,
        0.1,
      );

      expect(result.surviving, isEmpty);
      expect(result.playerHits, equals(10));
    });

    test('should NOT hit owner', () {
      final proj = createProjectile(
        pos: v64.Vector2(2.0, 2.0),
        ownerId: 'player',
      );
      // Entity with same ID as owner (e.g. if we spawn proj from center)
      final owner = createEntity(id: 'player', pos: v64.Vector2(2.1, 2.0));

      final result = ProjectileSystem.update(
        [proj],
        [owner],
        v64.Vector2.zero(), // Player pos irrelevant here as we check entity list collision
        map,
        0.1,
      );

      expect(result.surviving, hasLength(1)); // Should pass through
      expect(result.entityHits, isEmpty);
    });

    test('should be destroyed when exceeding max range', () {
      final proj = createProjectile(
        pos: v64.Vector2(2.0, 2.0),
        maxRange: 5.0,
      );
      // Move 10 units in one step -> total > 5.0
      final dt = 1.0;
      // vel is 10.0, dt 1.0 -> dist 10.0 > 5.0

      final result = ProjectileSystem.update(
        [proj],
        [],
        v64.Vector2.zero(),
        map,
        dt,
      );

      expect(result.surviving, isEmpty);
    });
  });
}

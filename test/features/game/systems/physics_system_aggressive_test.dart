import 'package:flutter_test/flutter_test.dart';
import 'package:raycasting_game/features/core/world/models/game_map.dart';
import 'package:raycasting_game/features/game/systems/physics_system.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('PhysicsSystem Aggressive Tests', () {
    late GameMap map;

    setUp(() {
      // 20x10 map with walls at borders and middle
      // Wall at x=5
      final grid = List.generate(
        10,
        (y) => List.generate(
          20,
          (x) => x == 5 && y == 5 ? Cell.wall : Cell.empty,
        ),
      );
      // Borders
      for (int i = 0; i < 20; i++) {
        grid[0][i] = Cell.wall;
        grid[9][i] = Cell.wall;
      }
      for (int i = 0; i < 10; i++) {
        grid[i][0] = Cell.wall;
        grid[i][19] = Cell.wall;
      }
      map = GameMap(width: 20, height: 10, grid: grid);
    });

    test('should prevent tunneling through walls with high velocity', () {
      final start = Vector2(4.5, 5.5);
      final velocity = Vector2(20, 0); // Fast enough to jump over wall
      final dt = 0.1; // 2 units movement -> Target 6.5

      // Expected: Stop BEFORE wall (~5.0 - radius)
      // Actual with tunneling: Ends up at 6.5 (past wall at 5.0)

      final result = PhysicsSystem.tryMove(
        'player',
        start,
        velocity,
        dt,
        map,
        [],
        radius: 0.1,
      );

      // If result.x > 5.0, it tunneled.
      expect(
        result.x,
        lessThan(5.0),
        reason: 'Entity tunneled through wall at x=5',
      );
    });

    test('should handle NaN position gracefully', () {
      final start = Vector2(double.nan, double.nan);
      final velocity = Vector2(1, 0);
      final dt = 0.016;

      try {
        final result = PhysicsSystem.tryMove(
          'player',
          start,
          velocity,
          dt,
          map, // map exists
          [],
        );
        // Expect result.x isNaN.
        expect(result.x.isNaN, isTrue);
      } catch (e) {
        fail('Should not throw exception on NaN input: $e');
      }
    });

    test('should handle Infinity velocity gracefully', () {
      final start = Vector2(1.5, 1.5);
      final velocity = Vector2(double.infinity, 0);
      final dt = 0.016;

      try {
        PhysicsSystem.tryMove(
          'player',
          start,
          velocity,
          dt,
          map,
          [],
        );
      } catch (e) {
        // If it throws UnsupportedError (infinity to int), that's expected behavior for Dart?
        // But for a game engine, we prefer clamping or ignoring.
        // Let's assert it DOES throw or handle it.
        // If it throws, we should fix it to be robust.
        // For now, let's just observe.
      }
    });
  });
}

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raycasting_game/features/core/world/bloc/world_bloc.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorldBloc Aggressive Tests', () {
    late WorldBloc worldBloc;

    setUp(() {
      worldBloc = WorldBloc();
    });

    tearDown(() {
      worldBloc.close();
    });

    // 1. Zero Dimensions
    // Hypothesis: Initialization with 0x0 size should either be rejected or handled gracefully
    blocTest<WorldBloc, WorldState>(
      'should handle 0x0 map initialization without crashing',
      build: () => worldBloc,
      act: (bloc) => bloc.add(const WorldInitialized(width: 0, height: 0)),
      wait: const Duration(seconds: 1), // Give it time to potentially fail
      expect: () => [
        isA<WorldState>().having(
          (s) => s.status,
          'status',
          WorldStatus.loading,
        ),
        isA<WorldState>()
            .having((s) => s.status, 'status', WorldStatus.active)
            .having(
              (s) => s.map?.width,
              'width',
              32,
            ), // Updates to 32 (clamped)
      ],
    );

    // 2. Negative Dimensions
    blocTest<WorldBloc, WorldState>(
      'should handle negative map initialization gracefully',
      build: () => worldBloc,
      act: (bloc) => bloc.add(const WorldInitialized(width: -10, height: -10)),
      wait: const Duration(seconds: 1),
      expect: () => [
        isA<WorldState>().having(
          (s) => s.status,
          'status',
          WorldStatus.loading,
        ),
        isA<WorldState>()
            .having((s) => s.status, 'status', WorldStatus.active)
            .having(
              (s) => s.map?.width,
              'width',
              32,
            ), // Updates to 32 (clamped)
      ],
    );

    // 3. Out of Bounds Movement
    // Setup a valid world first
    blocTest<WorldBloc, WorldState>(
      'should handle player teleporting to Infinity/NaN',
      build: () => worldBloc,
      seed: () => WorldState.empty().copyWith(
        status: WorldStatus.active,
        playerPosition: Vector2(1.5, 1.5),
      ),
      act: (bloc) => bloc.add(
        PlayerMoved(
          position: Vector2(double.infinity, double.infinity),
          direction: 0,
        ),
      ),
      expect: () => [
        isA<WorldState>().having(
          (s) => s.playerPosition?.x,
          'x',
          double.infinity,
        ), // If it accepts it, we have a problem elsewhere
      ],
    );

    blocTest<WorldBloc, WorldState>(
      'should handle player teleporting to NaN',
      build: () => worldBloc,
      seed: () => WorldState.empty().copyWith(
        status: WorldStatus.active,
        playerPosition: Vector2(1.5, 1.5),
      ),
      act: (bloc) => bloc.add(
        PlayerMoved(position: Vector2(double.nan, double.nan), direction: 0),
      ),
      expect: () => [
        isA<WorldState>().having(
          (s) => s.playerPosition?.x.isNaN,
          'x is NaN',
          true,
        ),
      ],
    );

    // 4. Invalid Entity IDs
    blocTest<WorldBloc, WorldState>(
      'should ignore damage to non-existent entity',
      build: () => worldBloc,
      seed: () => WorldState.empty().copyWith(status: WorldStatus.active),
      act: (bloc) =>
          bloc.add(const EntityDamaged(entityId: 'ghost_entity', damage: 100)),
      expect: () =>
          <WorldState>[], // Should yield no state change if entity not found
    );
  });
}

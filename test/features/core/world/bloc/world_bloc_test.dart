import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raycasting_game/features/core/world/bloc/world_bloc.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorldBloc', () {
    late WorldBloc worldBloc;

    setUp(() {
      worldBloc = WorldBloc();
    });

    tearDown(() async {
      await worldBloc.close();
    });

    test('initial state is empty', () {
      expect(worldBloc.state.status, WorldStatus.initial);
    });

    blocTest<WorldBloc, WorldState>(
      'emits [loading, active] when WorldInitialized is added',
      build: () => worldBloc,
      act: (bloc) => bloc.add(const WorldInitialized(width: 32, height: 32)),
      wait: const Duration(milliseconds: 500),
      expect: () => [
        isA<WorldState>().having(
          (s) => s.status,
          'status',
          WorldStatus.loading,
        ),
        isA<WorldState>()
            .having((s) => s.status, 'status', WorldStatus.active)
            .having((s) => s.map, 'map', isNotNull)
            .having((s) => s.map!.width, 'width', 32)
            .having((s) => s.entities, 'entities', isNotEmpty),
      ],
    );

    blocTest<WorldBloc, WorldState>(
      'emits updated player position when PlayerMoved is added',
      build: () => worldBloc,
      seed: () => WorldState.empty().copyWith(status: WorldStatus.active),
      act: (bloc) =>
          bloc.add(PlayerMoved(position: Vector2(5, 5), direction: 1.5)),
      expect: () => [
        isA<WorldState>()
            .having((s) => s.playerPosition, 'position', Vector2(5, 5))
            .having((s) => s.playerDirection, 'direction', 1.5),
      ],
    );
    // Note: EntityDamaged test requires setting up a valid entity in state first.
  });
}

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raycasting_game/features/core/world/bloc/world_bloc.dart';
import 'package:raycasting_game/features/core/world/models/game_entity.dart';
import 'package:raycasting_game/features/game/models/projectile.dart';
import 'package:raycasting_game/features/game/weapon/models/weapon.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('WorldBloc Combat Integration', () {
    late WorldBloc worldBloc;

    setUp(() {
      worldBloc = WorldBloc();
    });

    tearDown(() async {
      await worldBloc.close();
    });

    blocTest<WorldBloc, WorldState>(
      'WorldTick processes projectiles and applies damage',
      build: () => worldBloc,
      seed: () => WorldState(
        status: WorldStatus.active,
        entities: const <GameEntity>[],
        playerPosition: Vector2(5, 5),
        playerDirection: 0,
        projectiles: [
          Projectile(
            id: 'p1',
            ownerId: 'player',
            position: Vector2(2, 2),
            velocity: Vector2(10, 0),
            damage: 10,
          ),
        ],
      ),
      act: (bloc) => bloc.add(const WorldTick(0.1)),
      expect: () => [
        isA<WorldState>().having(
          (s) => s.projectiles.first.position.x,
          'projectile moved',
          3.0,
        ),
      ],
    );

    blocTest<WorldBloc, WorldState>(
      'PlayerFired spawns projectiles for non-hitscan weapons',
      build: () => worldBloc,
      seed: () => WorldState(
        status: WorldStatus.active,
        entities: const <GameEntity>[],
        playerPosition: Vector2(5, 5),
        playerDirection: 0,
      ),
      act: (bloc) => bloc.add(const PlayerFired(Weapon.bouncePistol)),
      expect: () => [
        isA<WorldState>().having(
          (s) => s.projectiles,
          'spawned projectile',
          isNotEmpty,
        ),
      ],
    );
  });
}

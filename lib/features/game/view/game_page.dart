import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:raycasting_game/features/core/input/bloc/input_bloc.dart';
import 'package:raycasting_game/features/core/perspective/bloc/perspective_bloc.dart';
import 'package:raycasting_game/features/core/world/bloc/world_bloc.dart';
import 'package:raycasting_game/features/game/bloc/game_bloc.dart';
import 'package:raycasting_game/features/game/bloc/game_event.dart';
import 'package:raycasting_game/features/game/raycasting_game.dart';

class GamePage extends StatelessWidget {
  const GamePage({super.key});

  @override
  Widget build(BuildContext context) {
    // We create both blocs here.
    // WorldBloc is the source of truth for simulation.
    // GameBloc handles UI state.
    // Note: WorldBloc could be global in 'app' layer later,
    // but for now scoped to GamePage is fine.
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => WorldBloc(),
        ),
        BlocProvider(
          create: (_) => InputBloc(),
        ),
        BlocProvider(
          create: (_) => PerspectiveBloc(),
        ),
        BlocProvider(
          create: (context) => GameBloc(
            worldBloc: context.read<WorldBloc>(),
          )..add(const GameStarted()),
        ),
      ],
      child: const GameView(),
    );
  }
}

class GameView extends StatelessWidget {
  const GameView({super.key});

  @override
  Widget build(BuildContext context) {
    // We pass only GameBloc to FlameGame, but RaycastingGame
    // will be updated to also know about WorldBloc inside its onLoad.
    // Alternatively, we can pass both.
    final gameBloc = context.read<GameBloc>();
    final worldBloc = context.read<WorldBloc>();
    final inputBloc = context.read<InputBloc>();
    final perspectiveBloc = context.read<PerspectiveBloc>();

    return Scaffold(
      body: Stack(
        children: [
          // The Game Engine
          GameWidget(
            game: RaycastingGame(
              gameBloc: gameBloc,
              worldBloc: worldBloc,
              inputBloc: inputBloc,
              perspectiveBloc: perspectiveBloc,
            ),
            loadingBuilder: (_) => const Center(
              child: CircularProgressIndicator(),
            ),
          ),

          // Debug Overlay / HUD
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black45,
              child: const Text(
                'Raycasting Engine v0.3 (World Architecture)',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

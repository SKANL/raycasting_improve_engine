import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:raycasting_game/core/audio/audio_service.dart';
import 'package:raycasting_game/features/core/input/bloc/input_bloc.dart';
import 'package:raycasting_game/features/core/level/bloc/bloc.dart';
import 'package:raycasting_game/features/core/level/view/death_screen.dart';
import 'package:raycasting_game/features/core/level/view/victory_screen.dart';
import 'package:raycasting_game/features/core/perspective/bloc/perspective_bloc.dart';
import 'package:raycasting_game/features/core/world/bloc/world_bloc.dart';
import 'package:raycasting_game/features/game/bloc/game_bloc.dart';
import 'package:raycasting_game/features/game/bloc/game_event.dart';
import 'package:raycasting_game/features/game/raycasting_game.dart';
import 'package:raycasting_game/features/game/view/widgets/game_hud.dart';
import 'package:raycasting_game/features/game/weapon/bloc/weapon_bloc.dart';
import 'package:raycasting_game/features/core/level/view/loading_screen.dart';

class GamePage extends StatelessWidget {
  const GamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => WorldBloc()),
        BlocProvider(create: (_) => InputBloc()),
        BlocProvider(create: (_) => PerspectiveBloc()),
        BlocProvider(create: (_) => WeaponBloc(audioService: AudioService())),
        BlocProvider(
          create: (context) => GameBloc(
            worldBloc: context.read<WorldBloc>(),
          ), // GameStarted is dispatched inside GameView once World is loaded
        ),
        BlocProvider(
          create: (_) => LevelBloc(),
        ),
      ],
      child: const GameOrchestrator(),
    );
  }
}

class GameOrchestrator extends StatelessWidget {
  const GameOrchestrator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorldBloc, WorldState>(
      buildWhen: (prev, curr) {
        // Only rebuild GameOrchestrator when switching between Loading and Playing
        final wasLoading =
            prev.status == WorldStatus.loading ||
            prev.status == WorldStatus.initial;
        final isLoading =
            curr.status == WorldStatus.loading ||
            curr.status == WorldStatus.initial;
        return wasLoading != isLoading;
      },
      builder: (context, worldState) {
        if (worldState.status == WorldStatus.loading ||
            worldState.status == WorldStatus.initial) {
          return const LoadingScreen();
        }
        return const GameView();
      },
    );
  }
}

class GameView extends StatefulWidget {
  const GameView({super.key});

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  late final RaycastingGame _game;

  @override
  void initState() {
    super.initState();
    _game = RaycastingGame(
      gameBloc: context.read<GameBloc>(),
      worldBloc: context.read<WorldBloc>(),
      inputBloc: context.read<InputBloc>(),
      perspectiveBloc: context.read<PerspectiveBloc>(),
      weaponBloc: context.read<WeaponBloc>(),
      levelBloc: context.read<LevelBloc>(),
    );
    // Let the GameBloc know the Engine is starting
    context.read<GameBloc>().add(const GameStarted());
    context.read<LevelBloc>().add(const LevelStarted());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<LevelBloc, LevelState>(
        // CRITICAL: solo reconstruir cuando el status cambia (ej. victory).
        // Sin buildWhen, SurvivalTick hace que Flutter reconstruya el GameWidget
        // 60 veces/s, lo que hace que pierda el foco del teclado.
        buildWhen: (prev, curr) => prev.status != curr.status,
        builder: (context, levelState) {
          return Stack(
            children: [
              // 1. The Game Engine (always in background)
              GameWidget(
                game: _game,
                loadingBuilder: (_) => const Center(
                  child: CircularProgressIndicator(),
                ),
              ),

              // 2. Game HUD Overlay
              const GameHud(),

              // 3. Victory Screen (when player survives 2 minutes)
              if (levelState.status == LevelStatus.victory)
                const VictoryScreen(),

              // 4. Death Screen (when player dies)
              BlocBuilder<WorldBloc, WorldState>(
                buildWhen: (prev, curr) =>
                    prev.isPlayerDead != curr.isPlayerDead,
                builder: (context, worldState) {
                  if (worldState.isPlayerDead) {
                    return const DeathScreen();
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

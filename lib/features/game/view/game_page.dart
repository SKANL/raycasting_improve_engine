import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:raycasting_game/features/core/input/bloc/input_bloc.dart';
import 'package:raycasting_game/features/core/perspective/bloc/perspective_bloc.dart';
import 'package:raycasting_game/features/core/world/bloc/world_bloc.dart';
import 'package:raycasting_game/features/game/bloc/game_bloc.dart';
import 'package:raycasting_game/features/game/bloc/game_event.dart';
import 'package:raycasting_game/features/game/raycasting_game.dart';
import 'package:raycasting_game/features/game/view/widgets/game_hud.dart';
import 'package:raycasting_game/features/game/weapon/bloc/weapon_bloc.dart';

class GamePage extends StatelessWidget {
  const GamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => WorldBloc()),
        BlocProvider(create: (_) => InputBloc()),
        BlocProvider(create: (_) => PerspectiveBloc()),
        BlocProvider(create: (_) => WeaponBloc()),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // The Game Engine
          GameWidget(
            game: _game,
            loadingBuilder: (_) => const Center(
              child: CircularProgressIndicator(),
            ),
          ),

          // Game HUD Overlay
          const GameHud(),
        ],
      ),
    );
  }
}

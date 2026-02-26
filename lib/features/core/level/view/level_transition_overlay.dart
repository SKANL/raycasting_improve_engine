import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:raycasting_game/features/core/level/bloc/bloc.dart';
import 'package:raycasting_game/features/core/world/bloc/world_bloc.dart';
import 'package:raycasting_game/features/game/bloc/bloc.dart';

/// Full-screen overlay that handles the transition between levels.
///
/// Sequence:
/// 1. Fade to black (0.5s)
/// 2. Show "NIVEL X" text
/// 3. Call LevelCleanup + HealthRestored + WorldInitialized
/// 4. Wait for world to become active
/// 5. Fade out → dispatch LevelTransitionComplete
class LevelTransitionOverlay extends StatefulWidget {
  const LevelTransitionOverlay({super.key});

  @override
  State<LevelTransitionOverlay> createState() => _LevelTransitionOverlayState();
}

class _LevelTransitionOverlayState extends State<LevelTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  bool _worldReady = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

    // Start fade-in immediately
    _ctrl.forward().then((_) => _beginTransition());
  }

  Future<void> _beginTransition() async {
    if (!mounted) return;
    final worldBloc = context.read<WorldBloc>();
    final gameBloc = context.read<GameBloc>();
    final levelBloc = context.read<LevelBloc>();

    // 1. Cleanup previous level (disposes GPU textures)
    worldBloc.add(const LevelCleanup());

    // 2. Restore +10 HP
    gameBloc.add(const HealthRestored(10));

    // Small pause for cleanup to propagate
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // 3. Initialize next level with the new seed
    final nextLevel = levelBloc.state.currentLevel + 1;
    final seed = levelBloc.state.sessionSeed + nextLevel;
    worldBloc.add(WorldInitialized(width: 32, height: 32, seed: seed));

    // 4. Wait for world to become active
    await for (final state in worldBloc.stream) {
      if (state.status == WorldStatus.active) break;
    }

    if (!mounted) return;
    setState(() => _worldReady = true);

    // 5. Fade out
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    await _ctrl.reverse();
    if (!mounted) return;

    // 6. Complete transition
    levelBloc.add(const LevelTransitionComplete());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final levelBloc = context.watch<LevelBloc>();
    final nextLevel = (levelBloc.state.currentLevel + 1).clamp(
      1,
      LevelState.maxLevel,
    );

    return FadeTransition(
      opacity: _opacity,
      child: Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _worldReady ? 'NIVEL $nextLevel' : 'CARGANDO...',
                style: GoogleFonts.outfit(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _worldReady ? 'Prepárate' : '',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  color: Colors.white54,
                  letterSpacing: 3,
                ),
              ),
              if (!_worldReady) ...[
                const SizedBox(height: 32),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    color: Colors.white30,
                    strokeWidth: 2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

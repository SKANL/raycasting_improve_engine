import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:raycasting_game/features/core/level/bloc/bloc.dart';
import 'package:raycasting_game/features/core/world/bloc/world_bloc.dart';
import 'package:raycasting_game/features/game/bloc/bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Full-screen victory screen displayed after completing all 6 levels.
class VictoryScreen extends StatefulWidget {
  const VictoryScreen({super.key});

  @override
  State<VictoryScreen> createState() => _VictoryScreenState();
}

class _VictoryScreenState extends State<VictoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onRetry(BuildContext ctx) {
    final levelBloc = ctx.read<LevelBloc>();
    final worldBloc = ctx.read<WorldBloc>();
    final gameBloc = ctx.read<GameBloc>();

    // Cleanup old textures
    worldBloc.add(const LevelCleanup());
    // Reset health
    gameBloc.add(const HealthRestored(100));
    // Restart level progression
    levelBloc.add(const GameRestarted());
    // Generate level 1
    final seed = levelBloc.state.sessionSeed + 1;
    worldBloc.add(WorldInitialized(width: 32, height: 32, seed: seed));
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              const Color(0xFF1A1000),
              Colors.black,
            ],
          ),
        ),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Trophy Icon
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFFFD700),
                    size: 96,
                  ),
                  const SizedBox(height: 24),

                  // Main Title
                  Text(
                    '¡ESCAPASTE!',
                    style: GoogleFonts.outfit(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFFD700),
                      letterSpacing: 8,
                      shadows: [
                        const Shadow(
                          color: Color(0xFFFFCC00),
                          blurRadius: 32,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(color: Color(0x60FFD700), thickness: 1),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.star,
                          color: Color(0x80FFD700),
                          size: 16,
                        ),
                      ),
                      const Expanded(
                        child: Divider(color: Color(0x60FFD700), thickness: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Has completado los 6 niveles del dungeon.',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      color: Colors.white60,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Retry Button
                  _RetryButton(onPressed: () => _onRetry(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RetryButton extends StatefulWidget {
  const _RetryButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.95 : (_hovered ? 1.05 : 1.0),
          duration: const Duration(milliseconds: 120),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _hovered
                    ? const Color(0xFFFFD700)
                    : const Color(0x60FFD700),
                width: 2,
              ),
              color: _hovered
                  ? const Color(0x20FFD700)
                  : const Color(0x0AFFD700),
            ),
            child: Text(
              'REINTENTAR',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _hovered
                    ? const Color(0xFFFFD700)
                    : const Color(0xA0FFD700),
                letterSpacing: 4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

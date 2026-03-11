import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:raycasting_game/features/core/level/view/menu_transition_screen.dart';

/// Full-screen victory screen displayed after surviving 2 minutes.
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
    // Return completely to menu wiping stack
    Navigator.of(ctx).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const MenuTransitionScreen(),
      ),
    );
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
                    size: 64, // Reducido de 96 a 64
                  ),
                  const SizedBox(height: 16), // Reducido de 24
                  // Main Title
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '¡SOBREVIVISTE!',
                      style: GoogleFonts.outfit(
                        fontSize:
                            40, // Reducido de 48 a 40 y respaldado por FittedBox
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFFFD700),
                        letterSpacing: 4, // Reducido de 6
                        shadows: [
                          const Shadow(
                            color: Color(0xFFFFCC00),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),

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
                  const SizedBox(height: 12),

                  Text(
                    'Sobreviviste 3 minutos en la dungeon.', // Actualizado a 3 minutos
                    style: GoogleFonts.outfit(
                      fontSize: 16, // Reducido de 18 a 16
                      color: Colors.white60,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32), // Reducido de 48 a 32
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
              'VOLVER AL MENÚ',
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

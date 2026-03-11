import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:raycasting_game/features/core/level/view/menu_transition_screen.dart';

/// Full-screen death screen displayed when the player dies.
class DeathScreen extends StatefulWidget {
  const DeathScreen({super.key});

  @override
  State<DeathScreen> createState() => _DeathScreenState();
}

class _DeathScreenState extends State<DeathScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
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
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [
                Color(0xFF2A0808),
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
                    // Skull Icon
                    const Icon(
                      Icons.bloodtype,
                      color: Color(0xFFB01010),
                      size: 64, // Reducido de 96
                    ),
                    const SizedBox(height: 16), // Reducido de 24
                    // Main Title
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'HAS MUERTO',
                        style: GoogleFonts.outfit(
                          fontSize: 40, // Reducido de 56 para match con Victory
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFCC1111),
                          letterSpacing: 8,
                          shadows: [
                            const Shadow(
                              color: Color(0x80FF0000),
                              blurRadius: 40,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12), // Reducido de 16
                    // Divider
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(
                            color: Color(0x40CC1111),
                            thickness: 1,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(
                            Icons.local_hospital,
                            color: Color(0x60CC1111),
                            size: 16,
                          ),
                        ),
                        const Expanded(
                          child: Divider(
                            color: Color(0x40CC1111),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12), // Reducido de 16

                    Text(
                      'El hospital ha reclamado otra víctima...',
                      style: GoogleFonts.outfit(
                        fontSize: 16, // Reducido de 18
                        color: Colors.white54,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32), // Reducido de 40
                    // Retry Button
                    _RetryButton(onPressed: () => _onRetry(context)),
                  ],
                ),
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
                    ? const Color(0xFFCC1111)
                    : const Color(0x40CC1111),
                width: 2,
              ),
              color: _hovered
                  ? const Color(0x20CC1111)
                  : const Color(0x05CC1111),
            ),
            child: Text(
              'VOLVER AL MENÚ',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _hovered
                    ? const Color(0xFFFF5555)
                    : const Color(0xA0CC1111),
                letterSpacing: 4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

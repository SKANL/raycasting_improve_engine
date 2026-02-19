import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:raycasting_game/features/core/world/bloc/world_bloc.dart';
import 'package:raycasting_game/features/game/view/widgets/minimap.dart';
import 'package:raycasting_game/features/game/weapon/bloc/weapon_bloc.dart';

/// HUD overlay displaying game information
class GameHud extends StatefulWidget {
  const GameHud({super.key});

  @override
  State<GameHud> createState() => _GameHudState();
}

class _GameHudState extends State<GameHud> with SingleTickerProviderStateMixin {
  late AnimationController _damageController;
  late Animation<double> _damageAnimation;

  @override
  void initState() {
    super.initState();
    _damageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _damageAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _damageController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _damageController.dispose();
    super.dispose();
  }

  void _onWorldStateChanged(BuildContext context, WorldState state) {
    if (state.effects.any((e) => e is PlayerDamagedEffect)) {
      _damageController.forward().then((_) => _damageController.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WorldBloc, WorldState>(
      listener: _onWorldStateChanged,
      child: Stack(
        children: [
          // Damage Vignette
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _damageAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        Colors.transparent,
                        Colors.red.withValues(
                          alpha: 0.5 * _damageAnimation.value,
                        ),
                      ],
                      stops: const [0.6, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

          // Top-left: Health and stats
          Positioned(
            top: 16,
            left: 16,
            child: _HealthDisplay(),
          ),

          // Top-right: Ammo counter
          Positioned(
            top: 16,
            right: 16,
            child: _AmmoDisplay(),
          ),

          // Center: Crosshair
          const Center(
            child: _Crosshair(),
          ),

          // Bottom-right: Minimap
          Positioned(
            bottom: 16,
            right: 16,
            child: BlocBuilder<WorldBloc, WorldState>(
              builder: (context, state) {
                return MiniMap(state: state, size: 150);
              },
            ),
          ),

          // Game Over Overlay
          BlocBuilder<WorldBloc, WorldState>(
            buildWhen: (previous, current) =>
                previous.isPlayerDead != current.isPlayerDead,
            builder: (context, state) {
              if (state.isPlayerDead) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red, width: 4),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'YOU DIED',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Press R to Restart', // Input handling for restart needs to be implemented
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

/// Health bar display
class _HealthDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorldBloc, WorldState>(
      buildWhen: (previous, current) =>
          previous.playerHealth != current.playerHealth ||
          previous.playerMaxHealth != current.playerMaxHealth,
      builder: (context, state) {
        final health = state.playerHealth;
        final maxHealth = state.playerMaxHealth;
        final percent = (health / maxHealth).clamp(0.0, 1.0);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'HEALTH',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 200,
                height: 24,
                child: Stack(
                  children: [
                    // Background
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    // Health bar
                    FractionallySizedBox(
                      widthFactor: percent,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.shade700,
                              Colors.red.shade500,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Health text
                    Center(
                      child: Text(
                        '$health / $maxHealth',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.8),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Ammo counter display
class _AmmoDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WeaponBloc, WeaponState>(
      builder: (context, state) {
        final ammo = state.currentAmmo;
        final maxAmmo = state.currentWeapon.maxAmmo;
        final isLow = ammo <= maxAmmo * 0.3;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isLow
                  ? Colors.orange.withValues(alpha: 0.5)
                  : Colors.cyan.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.currentWeapon.name.toUpperCase(),
                style: TextStyle(
                  color: Colors.cyan.shade300,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$ammo',
                    style: TextStyle(
                      color: isLow ? Colors.orange : Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: isLow
                              ? Colors.orange.withValues(alpha: 0.8)
                              : Colors.cyan.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/ $maxAmmo',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (isLow)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'LOW AMMO',
                    style: TextStyle(
                      color: Colors.orange.shade400,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Crosshair overlay
class _Crosshair extends StatelessWidget {
  const _Crosshair();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(
        painter: _CrosshairPainter(),
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    const gap = 8.0;
    const length = 12.0;

    // Top line
    canvas.drawLine(
      Offset(center.dx, center.dy - gap),
      Offset(center.dx, center.dy - gap - length),
      paint,
    );

    // Bottom line
    canvas.drawLine(
      Offset(center.dx, center.dy + gap),
      Offset(center.dx, center.dy + gap + length),
      paint,
    );

    // Left line
    canvas.drawLine(
      Offset(center.dx - gap, center.dy),
      Offset(center.dx - gap - length, center.dy),
      paint,
    );

    // Right line
    canvas.drawLine(
      Offset(center.dx + gap, center.dy),
      Offset(center.dx + gap + length, center.dy),
      paint,
    );

    // Center dot
    canvas.drawCircle(
      center,
      2,
      Paint()
        ..color = Colors.red.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

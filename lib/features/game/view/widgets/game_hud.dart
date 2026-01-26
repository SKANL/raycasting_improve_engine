import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:raycasting_game/features/game/weapon/bloc/weapon_bloc.dart';

/// HUD overlay displaying game information
class GameHud extends StatelessWidget {
  const GameHud({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
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

        // Bottom-right: Minimap (placeholder)
        Positioned(
          bottom: 16,
          right: 16,
          child: _MinimapPlaceholder(),
        ),
      ],
    );
  }
}

/// Health bar display
class _HealthDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.5), width: 2),
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
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.withOpacity(0.4)),
                  ),
                ),
                // Health bar (TODO: connect to player health state)
                FractionallySizedBox(
                  widthFactor: 0.75, // 75% health for demo
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
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
                // Health text
                Center(
                  child: Text(
                    '75 / 100', // TODO: connect to actual health
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.8),
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
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isLow
                  ? Colors.orange.withOpacity(0.5)
                  : Colors.cyan.withOpacity(0.5),
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
                              ? Colors.orange.withOpacity(0.8)
                              : Colors.cyan.withOpacity(0.5),
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
      ..color = Colors.white.withOpacity(0.8)
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
        ..color = Colors.red.withOpacity(0.6)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Minimap placeholder
class _MinimapPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.5), width: 2),
      ),
      child: Center(
        child: Text(
          'MINIMAP\n(TODO)',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.green.shade400,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:raycasting_game/features/core/world/bloc/world_bloc.dart';
import 'package:raycasting_game/features/core/ecs/components/transform_component.dart';
import 'package:raycasting_game/features/game/ai/components/ai_component.dart';

import 'dart:math' as math;

class MiniMap extends StatelessWidget {
  const MiniMap({
    super.key,
    required this.state,
    this.size = 150.0,
  });

  final WorldState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: CustomPaint(
          painter: _MiniMapPainter(state),
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter(this.state);

  final WorldState state;

  @override
  void paint(Canvas canvas, Size size) {
    final map = state.map;
    if (map == null) return;

    final center = Offset(size.width / 2, size.height / 2);
    // Scale: How many map units fit in the minimap radius?
    const viewRadius = 8.0;
    // Calculate scale so that viewRadius * 2 fits in width
    final scale = size.width / (viewRadius * 2);

    final playerPos = state.effectivePosition;
    final playerDir = state.playerDirection;

    // Save canvas to rotate map around player
    canvas.save();

    // 1. Move origin to center of widget
    canvas.translate(center.dx, center.dy);

    // 2. Rotate entire world so Player is facing UP (which is -pi/2 in standard angle)
    // Player direction 0 = East.
    // We want East to be Up? No.
    // If PlayerDir = 0 (East), and we want it Up (-Pi/2), we rotate by -Pi/2 - 0.
    // If PlayerDir = Pi/2 (South), and we want it Up (-Pi/2), we rotate by -Pi.
    // So rotation = -PlayerDir - Pi/2.
    canvas.rotate(-playerDir - math.pi / 2);

    // 3. Scale world
    canvas.scale(scale);

    // 4. Move world so player position is at origin
    canvas.translate(-playerPos.x, -playerPos.y);

    final paint = Paint()..style = PaintingStyle.fill;

    // Determine bounds in world space
    // We can just iterate all cells for now if map is small (32x32 = 1024 checks, acceptable for 60fps)
    // Or clamp to view radius
    final startX = (playerPos.x - viewRadius).floor().clamp(0, map.width);
    final endX = (playerPos.x + viewRadius).ceil().clamp(0, map.width);
    final startY = (playerPos.y - viewRadius).floor().clamp(0, map.height);
    final endY = (playerPos.y + viewRadius).ceil().clamp(0, map.height);

    // Draw Floor/Background (optional)

    // Draw Walls and Exit
    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        final cell = map.grid[y][x];
        if (cell.isSolid) {
          paint.color = Colors.green.withValues(alpha: 0.6);
          canvas.drawRect(
            Rect.fromLTWH(x.toDouble(), y.toDouble(), 1.0, 1.0),
            paint,
          );
        }
      }
    }

    // Draw Entities (Enemies)
    final enemyPaint = Paint()..color = Colors.red;
    for (final entity in state.entities) {
      // Don't draw player (we draw ourselves at center later)
      // Player entity might not be in entities list or might be special
      if (entity.id == 'player') continue;

      // Filter out dead enemies
      final ai = entity.getComponent<AIComponent>();
      if (ai != null && ai.currentState == AIState.die) continue;

      final transform = entity.getComponent<TransformComponent>();
      if (transform != null) {
        // Draw dot
        canvas.drawCircle(
          Offset(transform.position.x, transform.position.y),
          0.3, // Size in world units
          enemyPaint,
        );
      }
    }

    canvas.restore();

    // Draw Player (Center) - Fixed in center of widget
    final playerPaint = Paint()..color = Colors.white;
    // Draw Triangle
    final path = Path();
    path.moveTo(center.dx, center.dy - 6); // Tip
    path.lineTo(center.dx - 4, center.dy + 4);
    path.lineTo(center.dx + 4, center.dy + 4);
    path.close();
    canvas.drawPath(path, playerPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) {
    // Always repaint since WorldState changes frequently (animation, entities)
    // Checks could be optimized but simplified for now
    return true;
  }
}

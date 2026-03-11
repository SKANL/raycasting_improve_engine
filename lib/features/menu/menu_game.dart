import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'components/ambient_particles.dart';
import 'components/menu_item_component.dart';
import 'menu_state.dart';

/// Flame Game that renders the menu items and ambient particles
/// as a transparent overlay on top of the video background.
class MenuGame extends FlameGame with KeyboardEvents {
  MenuGame({this.onMenuAction});

  /// Called when a menu item is confirmed (tap or Enter).
  final void Function(int index)? onMenuAction;

  MenuState _state = const MenuState();
  final List<MenuItemComponent> _menuItems = [];

  @override
  Color backgroundColor() => Colors.transparent;

  bool _isInitialized = false;

  @override
  void update(double dt) {
    super.update(dt);
    // CRITICAL: Robust initialization check
    // If not initialized and size is valid, init immediately.
    // This catches cases where onLoad or onGameResize fired before layout was ready.
    if (!_isInitialized && size.x > 0 && size.y > 0) {
      _initMenu();
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    debugPrint(
      '🎮 MenuGame onLoad: size=${size.x.toStringAsFixed(1)}x${size.y.toStringAsFixed(1)}',
    );
    // Try to init if size is already ready (rare on cold start)
    if (size.x > 0 && size.y > 0) {
      _initMenu();
    }
  }

  Future<void> _initMenu() async {
    if (_isInitialized) return;
    _isInitialized = true;

    debugPrint('🚀 Initializing Menu Layout with size: ${size.x}x${size.y}');

    // Add ambient particles
    await add(AmbientParticles(particleCount: 30));

    // --- Adaptive layout calculations ---
    final screenW = size.x;
    final screenH = size.y;

    // --- Add Game Title (ASEPTIC) ---
    final titleStyle = TextStyle(
      fontFamily:
          'Courier Prime', // Monospaced clinical feel, falls back if not found
      fontSize: (screenW * 0.08).clamp(40.0, 120.0),
      fontWeight: FontWeight.w900,
      letterSpacing: 18.0,
      color: const Color(0xFFFFFFFF),
      shadows: [
        Shadow(
          color: const Color(0xFFFFFFFF).withValues(alpha: 0.8),
          blurRadius: 15,
        ),
        Shadow(
          color: const Color(0xFFB0BEC5).withValues(alpha: 0.6),
          blurRadius: 30,
        ),
      ],
    );

    final titleComponent = TextComponent(
      text: 'ASEPTIC',
      textRenderer: TextPaint(style: titleStyle),
      position: Vector2(screenW / 2, screenH * 0.3),
      anchor: Anchor.center,
    );
    await add(titleComponent);

    // Menu starts higher to avoid the bottom button getting cut off
    final menuZoneTop = screenH * 0.55;
    final itemCount = MenuState.labels.length;

    // Spacing is fixed proportional relative to screen height to prevent huge gaps
    final spacing = (screenH * 0.08).clamp(60.0, 90.0);
    final startY = menuZoneTop;
    final centerX = screenW / 2;

    debugPrint(
      '📍 Menu layout: startY=${startY.toStringAsFixed(1)}, spacing=${spacing.toStringAsFixed(1)}',
    );

    for (var i = 0; i < itemCount; i++) {
      final item = MenuItemComponent(
        label: MenuState.labels[i],
        index: i,
        isSelected: i == _state.selectedIndex,
        position: Vector2(centerX, startY + i * spacing),
        screenSize: size,
        onTap: () => _confirmSelection(i),
        onSelected: () => _selectItem(i),
      );
      _menuItems.add(item);
      await add(item);
    }

    debugPrint('🎮 MenuGame ready: ${_menuItems.length} items');
  }

  void _selectItem(int index) {
    _state = _state.copyWith(selectedIndex: index);
    _updateSelections();
  }

  void _confirmSelection(int index) {
    _state = _state.copyWith(selectedIndex: index);
    _updateSelections();
    onMenuAction?.call(index);
    debugPrint('Menu action: ${MenuState.labels[index]}');
  }

  void _updateSelections() {
    for (var i = 0; i < _menuItems.length; i++) {
      _menuItems[i].updateSelection(i == _state.selectedIndex);
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _state = _state.selectNext();
      _updateSelections();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _state = _state.selectPrevious();
      _updateSelections();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _confirmSelection(_state.selectedIndex);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}

import 'package:equatable/equatable.dart';
import 'package:raycasting_game/features/core/ecs/models/component.dart';

/// An Entity is just an ID and a collection of Components.
class GameEntity extends Equatable {
  const GameEntity({
    required this.id,
    this.components = const [],
    this.isActive = true,
  });

  final String id;
  final List<GameComponent> components;
  final bool isActive;

  /// Helper to get a component of type T.
  T? getComponent<T extends GameComponent>() {
    for (final c in components) {
      if (c is T) return c;
    }
    return null;
  }

  /// Helper to verify if has component.
  bool hasComponent<T extends GameComponent>() {
    return getComponent<T>() != null;
  }

  GameEntity copyWith({
    String? id,
    List<GameComponent>? components,
    bool? isActive,
  }) {
    return GameEntity(
      id: id ?? this.id,
      components: components ?? this.components,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [id, components, isActive];
}

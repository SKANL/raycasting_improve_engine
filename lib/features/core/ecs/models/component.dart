import 'package:equatable/equatable.dart';

/// Base class for all ECS components.
/// Components are pure data containers.
abstract class GameComponent extends Equatable {
  const GameComponent();

  @override
  List<Object?> get props => [];
}

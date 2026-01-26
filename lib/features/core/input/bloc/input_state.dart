part of 'input_bloc.dart';

/// Represents the current state of player input.
class InputState extends Equatable {
  const InputState({
    this.activeActions = const {},
    this.axisX = 0.0,
    this.axisY = 0.0,
  });

  /// Set of currently active actions (e.g., keys held down).
  final Set<GameAction> activeActions;

  /// Virtual analog axis X (-1.0 to 1.0), usually for turning or strafing.
  final double axisX;

  /// Virtual analog axis Y (-1.0 to 1.0), usually for moving forward/back.
  final double axisY;

  /// Returns true if [action] is currently active.
  bool isPressed(GameAction action) => activeActions.contains(action);

  InputState copyWith({
    Set<GameAction>? activeActions,
    double? axisX,
    double? axisY,
  }) {
    return InputState(
      activeActions: activeActions ?? this.activeActions,
      axisX: axisX ?? this.axisX,
      axisY: axisY ?? this.axisY,
    );
  }

  @override
  List<Object?> get props => [activeActions, axisX, axisY];
}

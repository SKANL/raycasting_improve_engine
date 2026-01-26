part of 'input_bloc.dart';

/// Events related to raw input and action processing.
sealed class InputEvent extends Equatable {
  const InputEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when a semantic action starts (e.g., key down).
final class ActionStarted extends InputEvent {
  const ActionStarted(this.action);
  final GameAction action;

  @override
  List<Object?> get props => [action];
}

/// Triggered when a semantic action ends (e.g., key up).
final class ActionEnded extends InputEvent {
  const ActionEnded(this.action);
  final GameAction action;

  @override
  List<Object?> get props => [action];
}

/// Triggered to update analog values (e.g., joystick move).
final class AnalogInputChanged extends InputEvent {
  const AnalogInputChanged({this.axisX = 0.0, this.axisY = 0.0});

  /// Horizontal axis value (-1.0 to 1.0).
  final double axisX;

  /// Vertical axis value (-1.0 to 1.0).
  final double axisY;

  @override
  List<Object?> get props => [axisX, axisY];
}

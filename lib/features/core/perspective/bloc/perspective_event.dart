part of 'perspective_bloc.dart';

sealed class PerspectiveEvent extends Equatable {
  const PerspectiveEvent();

  @override
  List<Object?> get props => [];
}

/// Toggles to the next available perspective.
final class PerspectiveToggled extends PerspectiveEvent {
  const PerspectiveToggled();
}

/// Explicitly changes to a specific perspective.
final class PerspectiveChanged extends PerspectiveEvent {
  const PerspectiveChanged(this.perspective);
  final Perspective perspective;

  @override
  List<Object?> get props => [perspective];
}

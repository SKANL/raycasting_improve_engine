part of 'perspective_bloc.dart';

class PerspectiveState extends Equatable {
  const PerspectiveState({
    required this.current,
    this.previous,
    this.isTransitioning = false,
    this.transitionProgress = 1.0,
  });

  factory PerspectiveState.initial() => const PerspectiveState(
    current: Perspective.threeD,
  );

  /// The currently active perspective.
  final Perspective current;

  /// The previous perspective (valid during transitions).
  final Perspective? previous;

  /// Whether a transition between perspectives is occurring.
  final bool isTransitioning;

  /// Progress of the transition (0.0 to 1.0).
  final double transitionProgress;

  PerspectiveState copyWith({
    Perspective? current,
    Perspective? previous,
    bool? isTransitioning,
    double? transitionProgress,
  }) {
    return PerspectiveState(
      current: current ?? this.current,
      previous: previous ?? this.previous,
      isTransitioning: isTransitioning ?? this.isTransitioning,
      transitionProgress: transitionProgress ?? this.transitionProgress,
    );
  }

  /// Helper to get the config for the current view.
  CameraConfig get config => _getConfig(current);

  CameraConfig _getConfig(Perspective p) {
    switch (p) {
      case Perspective.threeD:
        return CameraConfig.threeD;
      case Perspective.twoD:
        return CameraConfig.twoD;
      case Perspective.isometric:
        return CameraConfig.isometric;
    }
  }

  @override
  List<Object?> get props => [
    current,
    previous,
    isTransitioning,
    transitionProgress,
  ];
}

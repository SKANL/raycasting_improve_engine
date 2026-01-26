import 'package:equatable/equatable.dart';

/// Available viewing perspectives for the game.
enum Perspective {
  /// First-person classic raycasting view.
  /// Used for combat and immersion.
  threeD,

  /// Top-down tactical view.
  /// Used for planning and puzzle solving.
  twoD,

  /// 2.5D Isometric view.
  /// Used for platforming and verticality.
  isometric,
}

/// Configuration values for the camera in a specific perspective.
class CameraConfig extends Equatable {
  const CameraConfig({
    required this.fov,
    required this.pitch,
    required this.distance,
    required this.rotationOffset,
    required this.zoom,
  });

  /// Field of View in degrees.
  final double fov;

  /// Vertical looking angle (pitch) in degrees/units.
  final double pitch;

  /// Distance from the player target (0 for FPS).
  final double distance;

  /// Rotation offset applied to the view (e.g. 45 degrees for Iso).
  final double rotationOffset;

  /// Zoom level / scale factor.
  final double zoom;

  /// Default config for 3D Raycasting.
  static const threeD = CameraConfig(
    fov: 66,
    pitch: 0,
    distance: 0,
    rotationOffset: 0,
    zoom: 1,
  );

  /// Default config for 2D Top-Down.
  static const twoD = CameraConfig(
    fov: 0, // Orthographic
    pitch: 90,
    distance: 20,
    rotationOffset: 0,
    zoom: 1,
  );

  /// Default config for Isometric.
  static const isometric = CameraConfig(
    fov: 30,
    pitch: 45,
    distance: 15,
    rotationOffset: 45,
    zoom: 0.8,
  );

  @override
  List<Object?> get props => [fov, pitch, distance, rotationOffset, zoom];
}

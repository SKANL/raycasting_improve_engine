import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart';

/// Represents a light source in the game world.
///
/// Used by the shader for dynamic lighting effects.
/// Supports point lights with optional flicker animation.
class LightSource extends Equatable {
  const LightSource({
    required this.id,
    required this.position,
    this.color = const Color(0xFFFFAA44),
    this.radius = 5.0,
    this.intensity = 1.0,
    this.flickerSpeed = 0.0,
    this.type = LightType.point,
  });

  /// Unique identifier for this light.
  final String id;

  /// Position in world coordinates.
  final Offset position;

  /// Light color (default: warm torch color).
  final Color color;

  /// Radius of light influence in world units.
  final double radius;

  /// Base intensity (0.0 to 1.0).
  final double intensity;

  /// Flicker animation speed (0 = no flicker).
  /// Higher values = faster flicker.
  final double flickerSpeed;

  /// Type of light source.
  final LightType type;

  /// Creates a copy with optional overrides.
  LightSource copyWith({
    String? id,
    Offset? position,
    Color? color,
    double? radius,
    double? intensity,
    double? flickerSpeed,
    LightType? type,
  }) {
    return LightSource(
      id: id ?? this.id,
      position: position ?? this.position,
      color: color ?? this.color,
      radius: radius ?? this.radius,
      intensity: intensity ?? this.intensity,
      flickerSpeed: flickerSpeed ?? this.flickerSpeed,
      type: type ?? this.type,
    );
  }

  @override
  List<Object?> get props => [
    id,
    position,
    color,
    radius,
    intensity,
    flickerSpeed,
    type,
  ];
}

/// Types of light sources supported by the engine.
enum LightType {
  /// Point light that radiates in all directions.
  point,

  /// Directional light (sun/moon) with parallel rays.
  directional,

  /// Spotlight with cone shape (future expansion).
  spot,
}

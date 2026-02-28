import 'package:equatable/equatable.dart';
import 'package:raycasting_game/features/core/ecs/models/component.dart';
import 'package:raycasting_game/features/game/weapon/models/ammo_type.dart';

/// A pickup item in the world (ammo box, health, etc.).
/// When the player walks over an entity with this component, the pickup
/// is consumed and an [AmmoPickedUpEffect] is emitted.
class PickupComponent extends GameComponent with EquatableMixin {
  const PickupComponent({
    required this.ammoType,
    required this.quantity,
  });

  /// Which ammo type this pickup replenishes.
  final AmmoType ammoType;

  /// How much ammo is added when collected.
  final int quantity;

  @override
  List<Object?> get props => [ammoType, quantity];
}

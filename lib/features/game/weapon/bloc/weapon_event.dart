part of 'weapon_bloc.dart';

abstract class WeaponEvent extends Equatable {
  const WeaponEvent();

  @override
  List<Object?> get props => [];
}

/// Trigger weapon fire
class WeaponFired extends WeaponEvent {
  const WeaponFired();
}

/// Reload current weapon
class WeaponReloaded extends WeaponEvent {
  const WeaponReloaded();
}

/// Switch to different weapon
class WeaponSwitched extends WeaponEvent {
  const WeaponSwitched(this.weapon);

  final Weapon weapon;

  @override
  List<Object?> get props => [weapon];
}

/// Add ammo from a world pickup to the current (or target) weapon.
class AmmoAdded extends WeaponEvent {
  const AmmoAdded({required this.ammoType, required this.amount});

  final AmmoType ammoType;
  final int amount;

  @override
  List<Object?> get props => [ammoType, amount];
}

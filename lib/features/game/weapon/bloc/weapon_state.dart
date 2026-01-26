part of 'weapon_bloc.dart';

class WeaponState extends Equatable {
  const WeaponState({
    this.currentWeapon = Weapon.pistol,
    this.currentAmmo = 12,
    this.lastFireTime,
  });

  final Weapon currentWeapon;
  final int currentAmmo;
  final DateTime? lastFireTime;

  /// Can fire based on cooldown and ammo
  bool get canFire {
    if (currentAmmo <= 0) return false;
    if (lastFireTime == null) return true;

    final elapsed = DateTime.now().difference(lastFireTime!);
    return elapsed.inMilliseconds >= (currentWeapon.cooldown * 1000);
  }

  WeaponState copyWith({
    Weapon? currentWeapon,
    int? currentAmmo,
    DateTime? lastFireTime,
  }) {
    return WeaponState(
      currentWeapon: currentWeapon ?? this.currentWeapon,
      currentAmmo: currentAmmo ?? this.currentAmmo,
      lastFireTime: lastFireTime ?? this.lastFireTime,
    );
  }

  @override
  List<Object?> get props => [currentWeapon, currentAmmo, lastFireTime];
}

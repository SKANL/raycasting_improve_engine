import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:raycasting_game/core/logging/log_service.dart';
import 'package:raycasting_game/features/game/weapon/models/ammo_type.dart';
import 'package:raycasting_game/features/game/weapon/models/weapon.dart';

part 'weapon_event.dart';
part 'weapon_state.dart';

/// Manages weapon state and firing logic
class WeaponBloc extends Bloc<WeaponEvent, WeaponState> {
  WeaponBloc() : super(const WeaponState()) {
    on<WeaponFired>(_onWeaponFired);
    on<WeaponReloaded>(_onWeaponReloaded);
    on<WeaponSwitched>(_onWeaponSwitched);
    on<AmmoAdded>(_onAmmoAdded);
  }

  void _onWeaponFired(WeaponFired event, Emitter<WeaponState> emit) {
    if (!state.canFire) {
      LogService.warning('WEAPON', 'FIRE_BLOCKED', {
        'reason': state.currentAmmo <= 0 ? 'no_ammo' : 'cooldown',
      });
      return;
    }

    LogService.info('WEAPON', 'FIRED', {
      'weapon': state.currentWeapon.id,
      'ammo_remaining': state.currentAmmo - 1,
    });

    emit(
      state.copyWith(
        currentAmmo: state.currentAmmo - 1,
        lastFireTime: DateTime.now(),
      ),
    );
  }

  void _onWeaponReloaded(WeaponReloaded event, Emitter<WeaponState> emit) {
    LogService.info('WEAPON', 'RELOADED', {
      'weapon': state.currentWeapon.id,
    });

    emit(
      state.copyWith(
        currentAmmo: state.currentWeapon.maxAmmo,
      ),
    );
  }

  void _onWeaponSwitched(WeaponSwitched event, Emitter<WeaponState> emit) {
    LogService.info('WEAPON', 'SWITCHED', {
      'from': state.currentWeapon.id,
      'to': event.weapon.id,
    });

    emit(
      WeaponState(
        currentWeapon: event.weapon,
        currentAmmo: event.weapon.maxAmmo,
      ),
    );
  }

  void _onAmmoAdded(AmmoAdded event, Emitter<WeaponState> emit) {
    // Only apply to the current weapon if its ammo type matches the pickup.
    if (state.currentWeapon.ammoType != event.ammoType) return;

    // Cap at 3 full clips to avoid infinite stacking.
    final maxReserve = state.currentWeapon.maxAmmo * 3;
    final newAmmo = (state.currentAmmo + event.amount).clamp(0, maxReserve);

    LogService.info('WEAPON', 'AMMO_PICKED_UP', {
      'weapon': state.currentWeapon.id,
      'added': event.amount,
      'total': newAmmo,
    });

    emit(state.copyWith(currentAmmo: newAmmo));
  }
}

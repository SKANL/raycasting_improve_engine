import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:raycasting_game/features/game/weapon/bloc/weapon_bloc.dart';
import 'package:raycasting_game/features/game/weapon/models/weapon.dart';

void main() {
  group('WeaponBloc', () {
    late WeaponBloc weaponBloc;

    setUp(() {
      weaponBloc = WeaponBloc();
    });

    tearDown(() {
      weaponBloc.close();
    });

    test('initial state is correct', () {
      expect(weaponBloc.state.currentWeapon, equals(Weapon.pistol));
      expect(weaponBloc.state.currentAmmo, equals(12));
      expect(weaponBloc.state.canFire, isTrue);
    });

    blocTest<WeaponBloc, WeaponState>(
      'WeaponFired reduces ammo and updates lastFireTime',
      build: () => weaponBloc,
      act: (bloc) => bloc.add(const WeaponFired()),
      expect: () => [
        predicate<WeaponState>(
          (state) => state.currentAmmo == 11 && state.lastFireTime != null,
        ),
      ],
    );

    blocTest<WeaponBloc, WeaponState>(
      'WeaponFired does nothing if out of ammo',
      build: () => weaponBloc,
      seed: () => const WeaponState(currentAmmo: 0),
      act: (bloc) => bloc.add(const WeaponFired()),
      expect: () => const <WeaponState>[],
    );

    test('WeaponFired respects cooldown', () async {
      // Pistol has 0.4s cooldown
      weaponBloc.add(const WeaponFired());
      await pumpEventQueue();

      expect(weaponBloc.state.currentAmmo, 11);
      expect(weaponBloc.state.canFire, isFalse);

      // Try to fire immediately again
      weaponBloc.add(const WeaponFired());
      await pumpEventQueue();
      expect(weaponBloc.state.currentAmmo, 11); // Still 11

      // Wait 550ms (cooldown is 0.5s)
      await Future<void>.delayed(const Duration(milliseconds: 550));
      expect(weaponBloc.state.canFire, isTrue);

      weaponBloc.add(const WeaponFired());
      await pumpEventQueue();
      expect(weaponBloc.state.currentAmmo, 10);
    });

    blocTest<WeaponBloc, WeaponState>(
      'WeaponReloaded restores ammo to max',
      build: () => weaponBloc,
      seed: () => const WeaponState(currentAmmo: 2),
      act: (bloc) => bloc.add(const WeaponReloaded()),
      expect: () => [
        predicate<WeaponState>((state) => state.currentAmmo == 12),
      ],
    );

    blocTest<WeaponBloc, WeaponState>(
      'WeaponSwitched changes weapon and resets ammo',
      build: () => weaponBloc,
      act: (bloc) => bloc.add(const WeaponSwitched(Weapon.shotgun)),
      expect: () => [
        predicate<WeaponState>(
          (state) =>
              state.currentWeapon == Weapon.shotgun &&
              state.currentAmmo == 8, // Shotgun max ammo
        ),
      ],
    );
  });
}

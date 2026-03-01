import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:raycasting_game/core/audio/audio_service.dart';
import 'package:raycasting_game/features/game/weapon/bloc/weapon_bloc.dart';
import 'package:raycasting_game/features/game/weapon/models/weapon.dart';

// Mock AudioService to avoid playing actual sounds during tests
class MockAudioService extends Mock implements AudioService {}

void main() {
  group('WeaponBloc', () {
    late WeaponBloc weaponBloc;
    late MockAudioService mockAudioService;

    setUp(() {
      mockAudioService = MockAudioService();

      // Mock the playSFX method to prevent actual audio playback
      when(() => mockAudioService.playSFX(any(), volume: any(named: 'volume')))
          .thenAnswer((_) async {});

      weaponBloc = WeaponBloc(audioService: mockAudioService);
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
      verify: (bloc) {
        // Verify that playSFX was called with the pistol fire sound
        verify(() => mockAudioService.playSFX(
          Weapon.pistol.fireSound,
          volume: 0.8,
        )).called(1);
      },
    );

    blocTest<WeaponBloc, WeaponState>(
      'WeaponFired does nothing if out of ammo',
      build: () => weaponBloc,
      seed: () => const WeaponState(currentAmmo: 0),
      act: (bloc) => bloc.add(const WeaponFired()),
      expect: () => const <WeaponState>[],
      verify: (bloc) {
        // Verify that empty clip sound was played
        verify(() => mockAudioService.playSFX(
          'audio/weapons/empty_clip.wav',
          volume: 0.6,
        )).called(1);
      },
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
      verify: (bloc) {
        // Verify that reload sound was played
        verify(() => mockAudioService.playSFX(
          Weapon.pistol.reloadSound,
          volume: 0.7,
        )).called(1);
      },
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
      verify: (bloc) {
        // Verify that weapon switch sound was played
        verify(() => mockAudioService.playSFX(
          'audio/weapons/weapon_switch.wav',
          volume: 0.6,
        )).called(1);
      },
    );
  });
}

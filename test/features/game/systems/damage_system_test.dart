import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:raycasting_game/features/core/ecs/components/health_component.dart';
import 'package:raycasting_game/features/core/world/models/game_entity.dart';
import 'package:raycasting_game/features/game/ai/components/ai_component.dart';
import 'package:raycasting_game/features/game/systems/damage_system.dart';

class MockRandom extends Mock implements math.Random {}

void main() {
  group('DamageSystem', () {
    late MockRandom rng;

    setUp(() {
      rng = MockRandom();
      // Default RNG behavior: return 0.0 (always trigger pain if chance > 0)
      when(() => rng.nextDouble()).thenReturn(0.0);
    });

    GameEntity createEntity({
      required String id,
      int health = 100,
      bool isInvulnerable = false,
      double painChance = 0.0,
      AIState aiState = AIState.idle,
    }) {
      return GameEntity(
        id: id,
        isActive:
            true, // Entities must be active to be processed generally, though DamageSystem checks ID directly
        components: [
          HealthComponent(
            current: health,
            max: 100,
            isInvulnerable: isInvulnerable,
          ),
          AIComponent(
            currentState: aiState,
            painChance: painChance,
            attackType: AIAttackType.melee,
            moveSpeed: 10,
            attackRange: 1,
            meleeDamage: 10,
            attackCooldown: 1,
          ),
        ],
      );
    }

    test('should apply damage to entity correctly', () {
      final entity = createEntity(id: 'e1', health: 100);
      final damageMap = {'e1': 20};

      final results = DamageSystem.apply([entity], damageMap, rng);

      expect(results, hasLength(1));
      expect(results.first.entityId, equals('e1'));
      expect(results.first.newHealth, equals(80));
      expect(results.first.died, isFalse);
    });

    test('should kill entity when health drops to zero', () {
      final entity = createEntity(id: 'e1', health: 10);
      final damageMap = {'e1': 10};

      final results = DamageSystem.apply([entity], damageMap, rng);

      expect(results.first.newHealth, equals(0));
      expect(results.first.died, isTrue);
    });

    test('should kill entity when health drops below zero', () {
      final entity = createEntity(id: 'e1', health: 10);
      final damageMap = {'e1': 20};

      final results = DamageSystem.apply([entity], damageMap, rng);

      expect(results.first.newHealth, equals(0));
      expect(results.first.died, isTrue);
    });

    test('should ignore invulnerable entities', () {
      final entity = createEntity(id: 'e1', health: 100, isInvulnerable: true);
      final damageMap = {'e1': 50};

      final results = DamageSystem.apply([entity], damageMap, rng);

      expect(results, isEmpty);
    });

    test('should trigger pain state based on chance', () {
      // painChance 0.5, RNG returns 0.4 -> should trigger
      final entity = createEntity(id: 'e1', health: 100, painChance: 0.5);
      when(() => rng.nextDouble()).thenReturn(0.4);

      final damageMap = {'e1': 10};
      final results = DamageSystem.apply([entity], damageMap, rng);

      expect(results.first.enteredPain, isTrue);
    });

    test('should NOT trigger pain state if chance fails', () {
      // painChance 0.5, RNG returns 0.6 -> should NOT trigger
      final entity = createEntity(id: 'e1', health: 100, painChance: 0.5);
      when(() => rng.nextDouble()).thenReturn(0.6);

      final damageMap = {'e1': 10};
      final results = DamageSystem.apply([entity], damageMap, rng);

      expect(results.first.enteredPain, isFalse);
    });

    test('should NOT trigger pain state if entity dies', () {
      final entity = createEntity(id: 'e1', health: 10, painChance: 1.0);
      final damageMap = {'e1': 20}; // Lethal damage

      final results = DamageSystem.apply([entity], damageMap, rng);

      expect(results.first.died, isTrue);
      expect(
        results.first.enteredPain,
        isFalse,
      ); // Dead entities don't feel pain
    });

    test('should NOT trigger pain if already dying', () {
      final entity = createEntity(id: 'e1', health: 100, aiState: AIState.die);
      final damageMap = {'e1': 10};

      final results = DamageSystem.apply([entity], damageMap, rng);

      expect(results.first.enteredPain, isFalse);
    });

    test('applyToPlayer should reduce health clamped to zero', () {
      expect(DamageSystem.applyToPlayer(100, 20), equals(80));
      expect(DamageSystem.applyToPlayer(10, 20), equals(0));
    });
  });
}

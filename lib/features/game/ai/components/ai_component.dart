import 'package:raycasting_game/features/core/ecs/models/component.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

// ─── Enums ────────────────────────────────────────────────────────────────────

/// Extended AI states for Doom-like behavior
enum AIState {
  idle, // Waiting for player (look() check each tick)
  chase, // Has LOS or hunting last known position
  attack, // In range: firing or melee
  pain, // Stunned briefly after taking damage
  die, // Death animation playing
  patrol, // Wander/waypoint patrol (legacy)
}

/// How the enemy deals damage when in [AIState.attack]
enum AIAttackType {
  /// Close range: snap damage when within [AIComponent.attackRange]
  melee,

  /// Spawns a physical projectile that travels toward the player
  projectile,

  /// Instant hitscan ray (like the player's pistol)
  hitscan,
}

// ─── Component ───────────────────────────────────────────────────────────────

/// AI component for enemy entities.
/// Holds both FSM state and combat configuration.
class AIComponent extends GameComponent {
  const AIComponent({
    this.currentState = AIState.idle,
    this.attackType = AIAttackType.melee,
    this.targetPosition,
    this.detectionRange = 10,
    this.attackRange = 1.5,
    this.moveSpeed = 2,
    this.meleeDamage = 15,
    this.projectileDamage = 20,
    this.projectileSpeed = 8.0,
    this.attackCooldown = 1.0,
    this.lastAttackTime,
    this.lastStateChange,
    this.lastSeenPosition,
    this.reactionTime = 0.5,
    this.painChance = 0.3,
  });

  /// Current FSM state
  final AIState currentState;

  /// How the enemy attacks when in [AIState.attack]
  final AIAttackType attackType;

  /// Target position for patrol waypoints or chase destination
  final v64.Vector2? targetPosition;

  /// Vision radius for player detection (world units)
  final double detectionRange;

  /// Distance at which enemy stops chasing and begins attacking
  final double attackRange;

  /// Movement speed in world-units per second
  final double moveSpeed;

  /// Damage dealt per melee strike
  final int meleeDamage;

  /// Damage dealt by each projectile/hitscan attack
  final int projectileDamage;

  /// Speed of spawned projectiles in world-units per second
  final double projectileSpeed;

  /// Minimum seconds between attacks
  final double attackCooldown;

  /// Timestamp of last successful attack (for cooldown)
  final DateTime? lastAttackTime;

  /// Timestamp of last state transition (for timing)
  final DateTime? lastStateChange;

  /// Last known position of the player (for hunting when LOS lost)
  final v64.Vector2? lastSeenPosition;

  /// Seconds to wait before reacting when first spotting player
  final double reactionTime;

  /// Probability (0.0–1.0) to enter [AIState.pain] when hit
  final double painChance;

  // ─── Presets ─────────────────────────────────────────────────────────────

  /// Fast melee enemy. High pain chance.
  static const grunt = AIComponent(
    attackType: AIAttackType.melee,
    detectionRange: 10,
    attackRange: 1.5,
    moveSpeed: 2.5,
    meleeDamage: 8, // Reduced from 15
    attackCooldown: 1.0,
    painChance: 0.6,
  );

  /// Ranged projectile enemy. Medium speed.
  static const shooter = AIComponent(
    attackType: AIAttackType.projectile,
    detectionRange: 15,
    attackRange: 12.0,
    moveSpeed: 1.8,
    projectileDamage: 12, // Reduced from 20
    projectileSpeed: 8.0,
    attackCooldown: 1.5,
    painChance: 0.3,
  );

  /// Powerful hitscan enemy. Tanky, slow.
  static const guardian = AIComponent(
    attackType: AIAttackType.hitscan,
    detectionRange: 18,
    attackRange: 16.0,
    moveSpeed: 1.2,
    projectileDamage: 25, // Reduced from 35
    attackCooldown: 2.0,
    painChance: 0.15,
  );

  // ─── copyWith ─────────────────────────────────────────────────────────────

  AIComponent copyWith({
    AIState? currentState,
    AIAttackType? attackType,
    v64.Vector2? targetPosition,
    double? detectionRange,
    double? attackRange,
    double? moveSpeed,
    int? meleeDamage,
    int? projectileDamage,
    double? projectileSpeed,
    double? attackCooldown,
    DateTime? lastAttackTime,
    DateTime? lastStateChange,
    v64.Vector2? lastSeenPosition,
    double? reactionTime,
    double? painChance,
  }) {
    return AIComponent(
      currentState: currentState ?? this.currentState,
      attackType: attackType ?? this.attackType,
      targetPosition: targetPosition ?? this.targetPosition,
      detectionRange: detectionRange ?? this.detectionRange,
      attackRange: attackRange ?? this.attackRange,
      moveSpeed: moveSpeed ?? this.moveSpeed,
      meleeDamage: meleeDamage ?? this.meleeDamage,
      projectileDamage: projectileDamage ?? this.projectileDamage,
      projectileSpeed: projectileSpeed ?? this.projectileSpeed,
      attackCooldown: attackCooldown ?? this.attackCooldown,
      lastAttackTime: lastAttackTime ?? this.lastAttackTime,
      lastStateChange: lastStateChange ?? this.lastStateChange,
      lastSeenPosition: lastSeenPosition ?? this.lastSeenPosition,
      reactionTime: reactionTime ?? this.reactionTime,
      painChance: painChance ?? this.painChance,
    );
  }

  @override
  List<Object?> get props => [
    currentState,
    attackType,
    targetPosition,
    detectionRange,
    attackRange,
    moveSpeed,
    meleeDamage,
    projectileDamage,
    projectileSpeed,
    attackCooldown,
    lastAttackTime,
    lastStateChange,
    lastSeenPosition,
    reactionTime,
    painChance,
  ];
}

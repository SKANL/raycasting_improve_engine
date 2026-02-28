import 'package:raycasting_game/features/core/ecs/models/component.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

// ─── Enums ────────────────────────────────────────────────────────────────────

/// Categorises the enemy archetype — used for sprint variety in wave spawning.
enum EnemyType {
  grunt,    // Fast melee bruiser
  shooter,  // Mid-range ranged attacker
  guardian, // Slow long-range hitscan sniper
}

/// Extended AI states for Doom-like behavior
enum AIState {
  idle,        // Waiting for player (LOS check each tick)
  investigate, // Heard a sound — moving to check it out (no LOS yet)
  chase,       // Has LOS or hunting last-known position
  attack,      // In range: firing or melee
  pain,        // Stunned briefly after taking damage
  die,         // Death animation playing
  patrol,      // Wander/waypoint patrol (legacy)
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
    this.enemyType = EnemyType.grunt,
    this.attackType = AIAttackType.melee,
    this.targetPosition,
    this.investigatePosition,
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
    this.cachedMoveVelocity,
  });

  /// Current FSM state
  final AIState currentState;

  /// Enemy archetype — determines spawn visuals and difficulty class
  final EnemyType enemyType;

  /// How the enemy attacks when in [AIState.attack]
  final AIAttackType attackType;

  /// Target position for patrol waypoints or chase destination
  final v64.Vector2? targetPosition;

  /// Position to walk towards in [AIState.investigate] (source of heard sound).
  /// Cleared once the enemy arrives or finds the player.
  final v64.Vector2? investigatePosition;

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

  /// OPT: Velocity vector from the last 20Hz AI decision.
  /// Applied every frame (60Hz) between AI updates for smooth motion.
  /// Only valid when [currentState] == [AIState.chase].
  final v64.Vector2? cachedMoveVelocity;

  // ─── Presets ─────────────────────────────────────────────────────────────

  /// Fast melee brute.
  /// High pain chance so the player can stagger them up close.
  /// Low detection range (rushes only when sees you — fair!).
  static const grunt = AIComponent(
    enemyType: EnemyType.grunt,
    attackType: AIAttackType.melee,
    detectionRange: 10,
    attackRange: 1.3,
    moveSpeed: 2.8,    // Hard to outrun, but not impossible
    meleeDamage: 10,   // ~10 hits to die — fair vs. 100 HP
    attackCooldown: 0.9,
    painChance: 0.55,  // Staggers often — player can stop the rush if accurate
    reactionTime: 0.4,
  );

  /// Mid-range projectile shooter.
  /// Stays at medium range, slow projectiles are dodgeable.
  static const shooter = AIComponent(
    enemyType: EnemyType.shooter,
    attackType: AIAttackType.projectile,
    detectionRange: 14,
    attackRange: 10.0,
    moveSpeed: 1.6,
    projectileDamage: 14,  // Balanced: ~7 hits to die
    projectileSpeed: 6.5,  // Slow enough to dodge with strafing
    attackCooldown: 1.8,   // Long cooldown → predictable rhythm
    painChance: 0.35,
    reactionTime: 0.6,
  );

  /// Long-range hitscan sniper. Slow, rare, scary.
  /// Accuracy degrades with distance (implemented in AISystem).
  static const guardian = AIComponent(
    enemyType: EnemyType.guardian,
    attackType: AIAttackType.hitscan,
    detectionRange: 20,
    attackRange: 18.0,
    moveSpeed: 1.0,         // Slow — player can close the gap
    projectileDamage: 22,   // Dangerous but not lethal in one hit (100 HP player)
    attackCooldown: 2.5,    // Long cooldown → player has time to find cover
    painChance: 0.12,       // Hard to stagger — toughest enemy
    reactionTime: 0.8,      // Long reaction time — telegraphs the attack
  );

  // ─── copyWith ─────────────────────────────────────────────────────────────

  AIComponent copyWith({
    AIState? currentState,
    EnemyType? enemyType,
    AIAttackType? attackType,
    v64.Vector2? targetPosition,
    Object? investigatePosition = _keep,
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
    Object? cachedMoveVelocity = _keep,
  }) {
    return AIComponent(
      currentState: currentState ?? this.currentState,
      enemyType: enemyType ?? this.enemyType,
      attackType: attackType ?? this.attackType,
      targetPosition: targetPosition ?? this.targetPosition,
      investigatePosition: identical(investigatePosition, _keep)
          ? this.investigatePosition
          : investigatePosition as v64.Vector2?,
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
      cachedMoveVelocity: identical(cachedMoveVelocity, _keep)
          ? this.cachedMoveVelocity
          : cachedMoveVelocity as v64.Vector2?,
    );
  }

  // Private sentinel so copyWith can distinguish "keep" from explicit null.
  static const Object _keep = Object();

  @override
  List<Object?> get props => [
    currentState,
    enemyType,
    attackType,
    targetPosition,
    // investigatePosition excluded — transient navigation data
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
    // cachedMoveVelocity excluded — transient optimisation data
  ];
}

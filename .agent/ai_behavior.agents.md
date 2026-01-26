# Agent Context: AI & Pathfinding

## Navigation

- **Algorithm**: A\* (A-Star) Pathfinding on the `GameMap` grid.
- **Optimization**: Path recalculation should be throttled (time-sliced) or event-driven (only if target moves > N cells), not every frame.
- **Dynamic Obstacles**: Enemies must treat each other as soft obstacles (steering behaviors: separation) to avoid stacking.

## Sensory System

- **Vision**: Raycasting for Line-of-Sight (LOS).
  - Can the enemy see the player? Cast a ray from Enemy(x,y) to Player(x,y). If it hits a Wall first -> No.
- **Hearing**: Propagate sound events through the grid (flood fill distance). Gunshots alert enemies in N radius.

## State Machine (Behavior Logic)

1. **Patrol**: Move between random points or defined waypoints.
2. **Investigate**: Move to last heard sound location.
3. **Chase**: LOS confirmed. Move directly to player using A\*.
4. **Attack**: In range. Stop and fire/melee.

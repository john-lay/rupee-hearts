# Prototype Plan

## Design Decisions

- **Turn system**: FFT-style CT (Charge Time) bar — all units share one queue; unit acts when CT reaches 100, CT resets to 0 after acting
- **Camera**: Rotatable/pannable isometric — middle-mouse pan, Q/E rotate, scroll zoom
- **Terrain height**: Multi-level elevation affects combat (height advantage +15% dmg, below -10%); moving up costs +1 move point per step, max climbable step = 1
- **Enemy AI**: Greedy — close on nearest player unit, attack if in range, else wait
- **Prototype scope**: 1 hand-crafted 6×6 map, 2 player units vs 2 enemies

## Scene Tree

```
Main (Spatial)
├── GridMap              ← existing terrain rendering
├── MapData              ← logical grid: occupancy, walkability, cell heights
├── BattleManager        ← state machine (owns the game loop)
├── TurnManager          ← CT system, who acts next
├── Units (Spatial)      ← container for all unit instances
│   ├── Knight (Unit)
│   ├── Archer (Unit)
│   ├── Goblin (Unit)
│   └── Goblin2 (Unit)
├── CameraRig (Spatial)  ← pivot for rotation/pan
│   └── Camera
└── UI (CanvasLayer)
    ├── ActionMenu
    ├── UnitStatsPanel
    └── TurnOrderBar
```

## Scripts & Responsibilities

| Script | Responsibility |
|--------|---------------|
| `battle_manager.gd` | Top-level state machine; coordinates all other systems |
| `turn_manager.gd` | CT tick loop; determines whose turn it is |
| `map_data.gd` | Grid queries: is cell walkable, who occupies it, cell height |
| `unit.gd` | Stats (HP, ATK, DEF, SPD, move/attack range), CT value, grid position |
| `movement.gd` | BFS flood fill for reachable cells; A* pathfinding for movement |
| `ai_controller.gd` | Greedy enemy logic: close on nearest player unit, attack if in range |
| `camera_controller.gd` | Middle-mouse pan, Q/E rotate around map center, scroll zoom |

## Battle State Machine

```
INIT
  └─► TICK_CT          ← advance all unit CTs by their speed
        └─► (unit reaches CT 100)
              ├── player unit → SELECT_UNIT
              └── enemy unit  → ENEMY_THINK → RESOLVE → TICK_CT

SELECT_UNIT            ← highlight active unit, wait for confirm
  └─► SELECT_ACTION    ← show menu: Move / Attack / Wait
        ├── Move  → SELECT_MOVE_TARGET  → MOVE_UNIT → SELECT_ACTION (no move again)
        ├── Attack → SELECT_ATTACK_TARGET → RESOLVE_COMBAT
        └── Wait  → END_TURN

END_TURN               ← reset unit CT to 0, back to TICK_CT
```

## CT System Detail

- Every unit has `ct: int` (starts randomized 0–99 to stagger first round) and `speed: int`
- Each tick: `ct += speed` for all units simultaneously
- First unit to reach `ct >= 100` acts; ties broken by speed then unit index
- After acting: `ct = 0`
- TurnOrderBar previews next ~5 actors by simulating ticks forward (no side effects)

## Prototype Map Layout (6×6)

```
. . . . . .
. E . . E .    E = enemy start
. . [H] . .    [H] = elevated (height 2)
. . [H] . .
. P . . P .    P = player start
. . . . . .
```

## Build Order

1. `map_data.gd` + wire to existing GridMap (grid queries, height)
2. `unit.gd` + `unit.tscn` (stats, positioning on grid)
3. `turn_manager.gd` (CT tick, turn order)
4. `battle_manager.gd` state machine skeleton
5. `movement.gd` (BFS + highlights)
6. `camera_controller.gd`
7. Combat resolution (damage formula, death)
8. `ai_controller.gd`
9. UI (ActionMenu, StatsPanel, TurnOrderBar)

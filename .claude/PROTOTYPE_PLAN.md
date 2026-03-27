# Prototype Plan

## Design Decisions

- **Turn system**: FFT-style CT (Charge Time) bar — all units share one queue; unit acts when CT reaches 100, CT resets to 0 after acting
- **Camera**: Rotatable/pannable isometric — middle-mouse pan, Q/E rotate, scroll zoom
- **Terrain height**: Multi-level elevation affects combat (height advantage +15% dmg, below -10%); moving up costs +1 move point per step, max climbable step = 1
- **Accuracy**: Hit chance = clamp(accuracy + accuracy_mod − evasion − evasion_mod + dir_bonus, 5, 100). Direction bonus: front +0, side +15, rear +30. See [ACCURACY_SYSTEM.md](ACCURACY_SYSTEM.md).
- **Weather**: `weather_system.gd` (Control) added to UI CanvasLayer at index 0 (behind all UI). Draws a dark tint + animated rain streaks via `_draw()` / `draw_line()`. Toggled by a checkbox in the debug bar. Extend to other weather types by adding more draw modes.
- **Enemy AI**: Greedy — close on nearest player unit, attack if in range, else wait
- **Prototype scope**: 1 hand-crafted 6×6 map, 2 player units vs 2 enemies

## Scene Tree

```
Main (Spatial)
├── GridMap              ← existing terrain rendering
├── MapData              ← logical grid: occupancy, walkability, cell heights
├── BattleManager        ← state machine (owns the game loop)
├── TurnManager          ← CT system, who acts next
├── OccluderManager      ← fades tiles that block unit visibility
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
| `unit.gd` | Stats (HP, ATK, DEF, SPD, ACC, EVA, move/attack range), CT value, grid position, facing direction, tile-by-tile walk animation (`walk_path()` / `move_finished` signal). Buff/debuff slots: `accuracy_mod`, `evasion_mod`. |
| `movement.gd` | BFS flood fill for reachable cells; A* pathfinding for movement |
| `ai_controller.gd` | Greedy enemy logic: close on nearest player unit, attack if in range; async — uses `_after_ai_move` callback after walk animation completes |
| `camera_controller.gd` | Middle-mouse pan, Q/E rotate around map center, scroll zoom |
| `occluder_manager.gd` | Each frame, checks 1–3 grid neighbours in the camera's direction for each unit. If a neighbour tile is taller than the unit's tile, swaps it out of the GridMap and replaces the top layer with a dithered MeshInstance (25% discard checkerboard, GLES2-safe). Restored immediately when no longer occluding. |

## Battle State Machine

```
INIT
  └─► TICK_CT              ← advance all unit CTs by their speed
        └─► (unit reaches CT 100)
              ├── player unit → SELECT_ACTION
              └── enemy unit  → ENEMY_THINK → RESOLVE_COMBAT → TICK_CT

SELECT_ACTION              ← show menu: Move / Attack / Wait / Cancel
        ├── Move   → SELECT_MOVE_TARGET  → MOVE_UNIT → SELECT_ACTION
        ├── Attack → SELECT_ATTACK_TARGET → RESOLVE_COMBAT → SELECT_ACTION
        ├── Wait   → SELECT_FACING → END_TURN
        └── Cancel → restore snapshot → SELECT_ACTION

SELECT_FACING              ← NW/NE/SW/SE chooser overlay; triggers only after Wait

END_TURN                   ← reset unit CT to 0, back to TICK_CT

CHARIOT_SELECT             ← branching timeline panel; rewind to any prior snapshot
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

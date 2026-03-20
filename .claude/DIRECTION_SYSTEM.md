# Direction System

## How FFT Does It

### Facing
- **4 cardinal directions only** (N, S, E, W on the logical grid — rendered as the four isometric diagonals SW/NW/NE/SE on screen)
- Direction determines **evasion available to the defender**, not a damage multiplier
- Front attack: full evasion stack applies (class + shield + accessory + weapon)
- Side attack: class evasion nullified
- Back attack: only accessory evasion applies — near-guaranteed hit
- Magic ignores facing entirely
- Diagonal attacker position: ties **favour the defender** (front/side tie → treated as front; side/back tie → treated as side)

### When facing is set
- At the **end of a unit's turn**, after Move + Act (or Wait), the player explicitly chooses a direction
- The attacker **auto-turns toward their target** immediately before executing an action; that becomes their new facing

### Knockback
- Target is pushed **away from the attacker** (in the direction the attack came from)
- Target's facing does **not** change on knockback

---

## Our Implementation Plan

### Simplification
We have no evasion system. Instead of evasion stripping we'll use **damage multipliers** — simpler and more readable for a prototype:

| Relative position | Multiplier |
|---|---|
| Front | ×1.0 (base) |
| Side | ×1.25 |
| Back | ×1.5 |

Magic: always ×1.0 regardless of facing.

### Direction values
Use integer constants matching our 4 camera positions:
```gdscript
const DIR_S = 0  # facing toward camera SW (default)
const DIR_W = 1  # facing camera NW
const DIR_N = 2  # facing away NE
const DIR_E = 3  # facing camera SE
```

Grid offsets for each facing (which cell is "in front"):
```
DIR_S → (0, +1)   (toward bottom of logical grid)
DIR_W → (-1, 0)
DIR_N → (0, -1)
DIR_E → (+1, 0)
```

### Relative position logic
Given attacker at (ax, az) and defender at (dx, dz) facing `dir`:
1. Compute offset: `dx_off = ax - dx`, `dz_off = az - dz`
2. Project onto defender's forward vector
3. Use the axis with greater magnitude; ties favour the defender

```gdscript
func get_attack_direction(attacker_x, attacker_z, defender) -> String:
    var dx = attacker_x - defender.grid_x
    var dz = attacker_z - defender.grid_z
    # forward vector for defender's facing
    var fwd = DIR_FORWARD[defender.facing]
    var dot = dx * fwd.x + dz * fwd.y       # positive = attack comes from front
    var perp = abs(dx * fwd.y - dz * fwd.x) # cross product magnitude = side component
    var forward_component = dot              # negative = back
    if perp > abs(forward_component):
        return "side"
    elif forward_component >= 0:
        return "front"   # ties favour defender
    else:
        return "back"
```

### Turn flow additions
1. **After Move** (confirm_move): show a facing-chooser overlay (4 direction arrows over the unit)
2. **After Act** (confirm_attack / wait): same facing-chooser prompt
3. **Attack auto-turn**: before `_resolve_combat`, rotate attacker to face defender

### Sprite changes
Current sprite already renders SW/NW. Need to add NE and SE:
- NE = NW columns, `flip_h = true`
- SE = SW columns, `flip_h = true`

Map `unit.facing` (0–3) to `(column_array, flip)` in `_get_dir_frames()`:
```gdscript
match facing:
    DIR_S: return [_SW, false]
    DIR_W: return [_NW, false]
    DIR_N: return [_SW, true]   # SE mirrored
    DIR_E: return [_NW, true]   # NE mirrored
```
Wait — need to confirm which column maps to which world direction. This depends on the spritesheet annotation (sprites.md) and the current camera yaw logic. Will verify during implementation.

### Facing chooser UI
A simple overlay showing 4 arrow buttons arranged around the unit's screen position. Reuses `unproject_position()` pattern already established for name labels. The player clicks one arrow to confirm facing; ESC/right-click defaults to keeping current facing.

### Build order
1. Add `facing: int` var to `unit.gd` + update `_get_dir_frames()` to use it
2. Add `get_attack_direction()` + damage multiplier to `battle_manager.gd`
3. Auto-turn attacker in `_resolve_combat`
4. Add facing-chooser state (`SELECT_FACING`) to state machine
5. Wire facing-chooser after `confirm_move` and after `confirm_attack` / `player_wait`

### Out of scope (for now)
- Per-class evasion stats
- Knockback
- Ability interactions (Blade Grasp etc.)
- Forced facing after knockback

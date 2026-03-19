# Chariot Tarot System — Tactics Ogre: Let Us Cling Together

Research notes for potential implementation in rupee-hearts.

---

## What Is It?

**C.H.A.R.I.O.T** = Combat History and Refined Implementation of Tactics.

A battle rewind system introduced in the PSP remake (2010) of Tactics Ogre, designed by Yasumi Matsuno. Updated and de-penalised in Tactics Ogre: Reborn (2022).

Not a simple undo — a **branching timeline** system. Players can revisit past turns and take different actions, creating alternate branches within a single battle rather than restarting the map.

---

## Mechanics

### Rewind Depth
- Tracks the last **50 actions** (units combined, player and enemy)
- Starts at **10 turns** early game, scales with progression through the story
- Rewinding *only the current unit's ongoing turn* is free — does not count as a Chariot use

### Branching vs. Replay
- Rewind to any unit's past turn via the portrait sidebar
- If you choose a **different action** → a new timeline branch is created
- If you repeat the **exact same action** → no branch, deterministic replay (useful for verifying RNG outcomes)
- Multiple branches coexist within the battle; you can navigate between them

### Restrictions
- Cannot rewind guest/uncontrolled unit turns
- Certain special battles disable Chariot entirely
- PSP version: using Chariot locked you out of achievement "Titles" (this penalty was removed in Reborn)

---

## UI Design

| Element | Detail |
|---------|--------|
| Trigger | L button opens/closes the Chariot overlay |
| Sidebar | Left-side portrait list — all units in turn order |
| Preview | Highlighting a portrait replays that unit's turn on the main screen |
| Confirm | X on a portrait rewinds battle to that point |
| Branching | Sidebar reflects existing branches visually |

The framing matters: it presents rewind as *revisiting branches of history*, not cheating. This is reinforced by the tarot card theme (fate, alternate paths).

---

## Why It Works (Design Analysis)

- Removes "dead state" frustration without removing tactical challenge
- Branching (vs. linear undo) encourages genuine learning — players see how earlier choices cascade forward
- "Repeating the same action = no branch" nudges players toward *intentional* changes
- Progressive unlock (10 → 50 actions) preserves early-game difficulty before players understand systems
- No restart required: players experiment within the battle rather than replaying the whole map

---

## Implementation Plan (rupee-hearts)

### Design Decisions

**Combat is already deterministic** — damage in `_resolve_combat` uses no RNG, so deterministic RNG seeding is not needed. Replaying from a snapshot always produces the same outcome.

**Units must not be `queue_free`'d on death** — Chariot needs to restore dead units. Instead, dead units are hidden and flagged `alive = false`. They stay in the scene tree until the snapshot buffer is cleared.

**Snapshot on turn start (not end)** — Captured at the beginning of each player turn before any action. Rewinding to "Turn 3" restores the world as it was when that turn began.

**Max 10 snapshots for prototype** — Sufficient for a full battle. Can raise to 50 later.

**Linear history only for now** — No branching tree yet. A simple Array of snapshots. Branching is Phase 2.

**Enemy turns not snapshotted** — Player can only rewind to past player turns. Matches Tactics Ogre behaviour.

---

### Snapshot Structure

```gdscript
{
    "turn_number":        int,     # global counter, for sidebar display
    "acting_unit_name":   String,  # e.g. "Knight" — sidebar card label
    "acting_unit_team":   int,     # Team.PLAYER or Team.ENEMY
    "units": [
        {
            "node":      <unit ref>,  # direct node reference — never freed
            "grid_x":    int,
            "grid_z":    int,
            "hp":        int,
            "ct":        int,
            "has_moved": bool,
            "has_acted": bool,
            "alive":     bool,
        },
        ...
    ]
}
```

Occupancy is rebuilt from unit positions on restore — no need to snapshot `map_data` separately.

---

### Files to Change

#### `unit.gd`
- Add `var alive: bool = true`
- Add `func get_snapshot() -> Dictionary`
- Add `func restore_from_snapshot(snap: Dictionary, map_data) -> void`
- Add `func set_alive(val: bool) -> void` — shows/hides sprite, HP bar, name label
- Change `take_damage()` — remove `emit_signal("died")`; BattleManager checks `is_alive()` after damage
- Change `is_alive()` — return `hp > 0 and alive`

#### `battle_manager.gd`
- Add `State.CHARIOT_SELECT` — overlay open, turn frozen
- Add `var _chariot_history: Array = []` (capped at `_CHARIOT_MAX = 10`)
- Add `var _chariot_turn_number: int = 0`
- Add `func _snapshot_turn(unit) -> void` — called at start of each player turn
- Add `func _restore_snapshot(snap: Dictionary) -> void`
- Add `func _open_chariot() / _close_chariot()` and a "⟲ Chariot" button in the UI
- Change `_remove_unit()` — call `unit.set_alive(false)` instead of `unit.queue_free()`
- Change `_on_turn_ready()` — call `_snapshot_turn()` before `SELECT_ACTION` (player turns only)

#### `turn_manager.gd`
- Add `func restore_units(unit_list: Array) -> void` — replaces `_units` with the given alive units

#### Chariot overlay (inline, dynamic — same pattern as debug checkbox)
- Right-side `PanelContainer` with `VBoxContainer` of history cards
- Each card: team colour, unit name, "Turn N", small HP indicator
- Click card → `_restore_snapshot()` + close overlay
- Cancel button / Escape → close without rewinding
- Reuses `TurnOrderBar` card visual style

---

### Restore Logic

```gdscript
func _restore_snapshot(snap: Dictionary) -> void:
    # 1. Restore all unit states
    var alive_units := []
    for entry in snap.units:
        entry.node.restore_from_snapshot(entry, map_data)
        if entry.alive:
            alive_units.append(entry.node)

    # 2. Rebuild map occupancy
    map_data.clear_all_units()
    for unit in alive_units:
        map_data.set_unit_at(unit.grid_x, unit.grid_z, unit)

    # 3. Restore TurnManager
    turn_manager.restore_units(alive_units)

    # 4. Set active unit and transition
    active_unit = _find_unit_by_name(snap.acting_unit_name)
    active_unit.start_turn()
    _update_active_indicator()
    _turn_order_bar.refresh(active_unit)

    # 5. Trim history to this point
    _chariot_history.resize(_chariot_history.find(snap) + 1)

    _close_chariot()
    _change_state(State.SELECT_ACTION)
```

---

### Build Order

1. `unit.gd` — `alive` flag, `get_snapshot()`, `restore_from_snapshot()`, `set_alive()`
2. `battle_manager.gd` — hide on death, snapshot/restore, `CHARIOT_SELECT` state, button
3. `turn_manager.gd` — `restore_units()`
4. Chariot overlay UI — dynamically created cards, click handlers
5. Test: death hides correctly → snapshot captures state → restore resets everything → enemy turns skipped

---

### Out of Scope (Phase 2)

- Branching timeline tree (multiple alternate paths coexisting)
- Rewinding enemy turns
- Animated turn replay before confirming rewind
- Snapshot depth scaling with progression
- "Title penalty" for using Chariot

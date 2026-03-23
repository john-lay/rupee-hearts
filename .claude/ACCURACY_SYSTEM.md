# Accuracy System

## Overview

Attacks have a percentage chance to hit. The outcome is deterministic within the Chariot timeline — rewinding and replaying a turn always produces the same hit/miss result.

## Stats (unit.gd)

| Stat | Type | Description |
|------|------|-------------|
| `accuracy` | `int` | Base hit chance % for this unit's attacks |
| `evasion` | `int` | Subtracted from attacker's accuracy |
| `accuracy_mod` | `int` | Temporary buff/debuff applied to accuracy (0 until spells exist) |
| `evasion_mod` | `int` | Temporary buff/debuff applied to evasion (0 until spells exist) |

All four are included in `get_snapshot()` and `restore_from_snapshot()`.

## Hit Resolution (_resolve_combat)

```
hit_chance = clamp(attacker.accuracy + attacker.accuracy_mod
                   - defender.evasion - defender.evasion_mod, 5, 100)
roll = randi() % 100
if roll >= hit_chance → MISS
```

- Minimum hit chance is 5% (attacks can never be guaranteed to miss).
- On a miss: show a "MISS" floating label at the defender, skip damage, print miss log.
- On a hit: proceed with directional damage multiplier and height bonus as before.

## Chariot Determinism

The Chariot snapshots unit state at the start of each player turn. To guarantee the same hit/miss outcome on replay:

1. `_snapshot_turn()` calls `randi()` to produce a seed, stores it as `snap.rng_seed`, then immediately calls `seed(snap.rng_seed)` to begin the seeded sequence.
2. `_restore_snapshot()` calls `seed(snap.rng_seed)` after restoring unit state.
3. All `randi()` calls during a turn (hit rolls) consume the same seeded sequence regardless of how many times the turn is replayed.

The game's initial seed is still set by `randomize()` at startup, so early turn seeds remain unpredictable across sessions.

## Accuracy UI

During `SELECT_ATTACK_TARGET` state, a label at the bottom of the screen shows:

```
Hit: 78%
```

The value updates each frame by ray-casting the mouse position to find the hovered target cell, then computing `hit_chance` against that unit. Clears when no valid target is under the cursor or the state changes.

## Unit Configs

| Unit   | accuracy | evasion |
|--------|----------|---------|
| Knight | 80       | 5       |
| Archer | 90       | 10      |
| Goblin | 65       | 0       |

## Future: Buffs & Debuffs

`accuracy_mod` and `evasion_mod` are already snapshotted. Future spells/abilities set these directly on the unit. No duration system exists yet — durations will be tracked alongside the modifier when implemented.

Example intended effects:
- *Blind*: `accuracy_mod -= 30`
- *Focus*: `accuracy_mod += 20`
- *Haste* (evasion): `evasion_mod += 15`

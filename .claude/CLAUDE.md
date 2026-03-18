# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**rupee-hearts** is a tactical RPG in the style of Final Fantasy Tactics and Vandal Hearts, built with **Godot Engine 3.6.2** (not Godot 4). See [PROTOTYPE_PLAN.md](PROTOTYPE_PLAN.md) for the full architecture and design decisions.

To run: open `godot/project.godot` in Godot 3.6.2, press F5.

## Scene Hierarchy (`godot/main.tscn`)

```
Main (Spatial)
├── GridMap          — voxel tile world, mesh_library = grass_mesh_lib.tres
├── MapData          — map_data.gd: logical grid, walkability, occupancy
├── TurnManager      — turn_manager.gd: CT tick loop, turn order
├── BattleManager    — battle_manager.gd: state machine, input, combat
├── Movement         — movement.gd: BFS reachable cells, A* pathfinding, highlights
├── AIController     — ai_controller.gd: greedy enemy AI
├── Units (Spatial)  — spawned unit nodes live here
├── CameraRig        — camera_controller.gd: A/D rotate, W/S zoom
│   └── Camera
└── UI (CanvasLayer)
    ├── ActionMenu   — Move / Attack / Wait buttons
    └── TurnOrderBar — CT preview bar
```

## Key Scripts

| Script | Role |
|--------|------|
| `map_data.gd` | `MAP_LAYOUT[z][x]` defines heights. Provides `cell_to_world()`, `is_walkable()`, `get_height()`, occupancy grid. |
| `battle_manager.gd` | State machine: TICK_CT → SELECT_ACTION → SELECT_MOVE/ATTACK_TARGET → END_TURN → ENEMY_THINK. Spawns units, handles mouse picking, resolves combat. |
| `movement.gd` | BFS flood fill for reachable cells, A* for pathing. Tile highlights use an inline GLSL shader (fill + pulsing border). |
| `unit.gd` | Stats, HP bar (3D MeshInstance), name label (2D Label projected via `unproject_position`), CT. |
| `turn_manager.gd` | Ticks all units' CT by their speed each frame until one hits 100, then emits `turn_ready`. |
| `camera_controller.gd` | A/D = 90° discrete rotation (lerp-smoothed), 4 isometric positions. W/S = 4 orthographic zoom levels. Orthographic projection at 35.264° elevation. |

## Critical Godot 3 / GLES2 Constraints

These have caused bugs before — don't repeat them:

- **No `Label3D`** — use a 2D `Label` updated each frame via `camera.unproject_position()`.
- **No `GridMap.world_to_map()`** — compute manually: `int(floor(hit.x / cell_size.x))`.
- **Transparency unreliable in GLES2** — never use `flags_transparent` or alpha on SpatialMaterial for world geometry. Pulse colours instead, or use `discard` in shaders for "transparent" areas.
- **`global_transform.origin` must be set AFTER `add_child()`** — otherwise world position is wrong.
- **MeshInstances created in `_ready()` may not render** — create them in `call_deferred("_start_battle")` or later.
- **`Color` is a value type** — `mat.albedo_color.a = x` modifies a copy. Always assign the full Color: `mat.albedo_color = Color(r, g, b, a)`.
- **Godot editor rewrites `main.tscn`** — every time the editor is opened and closed, it regenerates the scene file. Always close the editor before editing `.tscn` files manually.

## Established Patterns

- **Highlight tiles**: `ShaderMaterial` with inline GLSL — static fill, pulsing border. Shader lives in `movement._outline_shader` and is shared with `battle_manager` for the active unit indicator.
- **World-space UI text** (name labels, damage numbers): `Label` nodes added to `UI` CanvasLayer, positioned each frame via `_camera.unproject_position(world_pos)`.
- **Dynamic MeshInstances**: always `get_parent().add_child(mi)` first, then set `mi.global_transform.origin` or `mi.translation`.
- **State enum references across scripts**: use hardcoded `const` integers (e.g. `const _SELECT_ACTION = 3`) — `load("res://scripts/battle_manager.gd").State.SELECT_ACTION` does not work reliably in Godot 3.
- **`call_deferred`**: use whenever BattleManager needs to trigger logic that touches sibling nodes during startup.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Design & Planning

See [PROTOTYPE_PLAN.md](PROTOTYPE_PLAN.md) (in this `.claude/` directory) for the agreed architecture, state machine, CT system design, and build order.

## Project Overview

**rupee-hearts** is a tactical RPG in the style of Final Fantasy Tactics and Vandal Hearts, built with **Godot Engine 3.6.2** (not Godot 4).

## Engine & Runtime

- **Godot version**: 3.6.2 (uses GDScript, `.tscn`/`.tres` formats, GLES2 renderer)
- **No build system** — open `godot/project.godot` directly in the Godot editor
- **Entry scene**: `res://main.tscn`
- **Scripting**: GDScript (`.gd` files); none exist yet

To run the project, open Godot 3.6.2 and import `godot/project.godot`. Use the editor's Play button or `F5` to run.

## Architecture

### Scene Structure
- `godot/main.tscn` — root `Spatial` node containing a `GridMap` for the tile-based world and a `Camera` with isometric perspective
- `godot/grass_mesh_lib.tres` — `MeshLibrary` resource used by the `GridMap` to define tile meshes

### Asset Pipeline
- 3D models are authored in **Blender** and exported as `.glb` to `assets/models/`, then copied into `godot/voxels/` for Godot import
- Textures are authored in **Photoshop** (`.psd`) and exported as `.png` to `assets/textures/`
- `godot/voxels/Material.material` is the shared material for voxel tile rendering

### GridMap Approach
The world uses Godot's `GridMap` node (voxel-style tile placement) rather than `TileMap`. Mesh libraries must be rebuilt in the Godot editor when new tile meshes are added.

## Key Files

| File | Purpose |
|------|---------|
| `godot/project.godot` | Project settings, main scene, renderer config |
| `godot/main.tscn` | Main scene: GridMap + Camera |
| `godot/grass_mesh_lib.tres` | MeshLibrary for GridMap tiles |
| `godot/voxels/Material.material` | Voxel tile material |
| `assets/models/grass.glb` | Source grass tile model |
| `assets/textures/piiixl-textures.png` | Pixel art texture atlas |

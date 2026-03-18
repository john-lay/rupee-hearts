# Isometric Camera Design

This document captures the rationale behind the camera architecture for rupee-hearts, informed by debugging sprite alignment issues and researching how Final Fantasy Tactics handles its isometric view.

## The Core Problem: Perspective vs Orthographic

**Perspective projection was the root cause of all sprite-on-tile alignment issues.**

With perspective, camera rays fan out from a single lens point. `BILLBOARD_ENABLED` on a `Sprite3D` makes each sprite face *its own ray*. Sprites at the left edge of the screen tilt differently than sprites at the centre or right — causing a viewport-position-dependent offset from the tile centre. No static or dynamic correction formula can fix this across all camera rotations (we tried several — see commit history).

With **orthographic projection**, all camera rays are parallel. Every billboard sprite faces the same direction. A sprite's screen position maps exactly to its world position. Alignment is precise and consistent everywhere on the map, regardless of viewport position or camera rotation angle.

**Always use `Camera.PROJECTION_ORTHOGONAL`.** Control zoom via `Camera.size`, not arm/distance length.

## Why FFT Uses Orthographic

Final Fantasy Tactics (and virtually all tactical RPGs with sprite characters on a 3D grid) use orthographic projection for exactly this reason. It also:

- Eliminates depth-based size variation (units look the same size regardless of depth)
- Preserves the grid aesthetic — tiles look like consistent diamonds
- Makes ray-casting for mouse picking simpler and more reliable

## Target Camera Parameters

| Property | Value | Reason |
|---|---|---|
| Projection | Orthographic | Sprite and tile alignment |
| Elevation angle | 35.264° from horizontal | True isometric: arctan(1/√2), all three axes equally foreshortened |
| Rotation snaps | 90° increments (4 positions) | Matches FFT; 8-position 45° snaps are unnecessary and complicate sprite direction logic |
| Zoom control | `Camera.size` property | Orthographic zoom mechanism |

### Elevation angle detail

35.264° is the "true isometric" angle — arcsin(1/√3) ≈ arctan(1/√2) ≈ 35.264°. At this angle, all three world axes (X, Y, Z) are equally foreshortened. This is noticeably steeper than the ~26.6° we had before (which came from `Vector3(0, z*0.5, z)` arm positioning).

To achieve this in Godot: set `Camera.rotation_degrees.x = -35.264` (looking downward at that angle from horizontal).

## Sprite Facing Directions

With 4 camera positions (yaw 0°, 90°, 180°, 270°), we need 4 sprite facings. The spritesheet has SW and NW walk frames; NE and SE are mirrors.

| Camera yaw | View direction | Sprite frames | flip_h |
|---|---|---|---|
| 0° | Looking from SW | SW frames | false |
| 90° | Looking from NW | NW frames | false |
| 180° | Looking from NE | SW frames (mirrored) | true |
| 270° | Looking from SE | NW frames (mirrored) | true |

## Approaches That Did Not Work

For historical context — do not re-attempt these:

1. **Static nudge** (`translation += Vector3(-0.15, 0, 0.3)`) — fixed one viewport position, broke others.
2. **Dynamic map-centre correction** — worked at default yaw=0, broke on camera rotation because the correction direction was baked to one orientation.
3. **2D Sprite in CanvasLayer** — perfect alignment but z-index always above all 3D content, including elevated terrain tiles. Reverted.
4. **QuadMesh + custom GLSL shader** — perspective distortion caused visible skewing on non-billboard geometry.
5. **`BILLBOARD_FIXED_Y`** — camera is elevated ~35°, so a vertically-fixed billboard viewed from an angle appears compressed/skewed. Reverted.

The correct solution is orthographic projection + `BILLBOARD_ENABLED`. Orthographic removes the root cause entirely.

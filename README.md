# rupee-hearts

A tactical RPG in the style of Final Fantasy Tactics and Vandal Hearts.

## Prototype

A working battle prototype on a hand-crafted 6×6 map with 2 player units vs 2 enemies.

**Controls**
- **Q / E** — rotate camera
- **Middle mouse drag** — pan camera
- **Scroll wheel** — zoom
- **Move / Attack / Wait** — action menu buttons (appear on player turn)
- **Left click** — select a highlighted cell to move or attack
- **Right click / Escape** — cancel targeting

**Systems implemented**
- FFT-style CT (Charge Time) turn order — units act when their CT bar fills based on their speed stat
- Grid-based movement with BFS flood fill and move-point costs
- Terrain height advantage/disadvantage affecting damage
- Greedy enemy AI — closes on nearest player unit and attacks when in range
- Visual tile highlights for movement (blue) and attack (red) range

## Development

Open `godot/project.godot` in **Godot 3.6.2** and press F5 to run.

See [.claude/PROTOTYPE_PLAN.md](.claude/PROTOTYPE_PLAN.md) for the full architecture and build plan.

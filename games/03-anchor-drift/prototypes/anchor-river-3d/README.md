# Anchor River Whitebox

Godot 4 whitebox prototype for the 3D anchor mechanic.

## Run

1. Open Godot 4.x.
2. Import this directory's `project.godot` (`games/03-anchor-drift/prototypes/anchor-river-3d/project.godot` from the repository root).
3. Press Run.

## Controls

- `Space` or left mouse: throw anchor / release anchor
- `R`: reset

## Prototype Focus

- A square looping canal pushes the boat forward with water current.
- The anchor is thrown forward, flies out, sinks to the riverbed, then hooks.
- Once hooked, the chain pulls against the boat, slowing it, turning it, or letting the camera look back.
- The canal keeps the boat inside the water lane so this can focus on the anchor feeling first.

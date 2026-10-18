# Anchor Runner Prototype Architecture

## Current Play Loop

- The boat moves forward automatically and gets faster over time.
- The world is a vertical river with visible shores. Leaving the river ends the run.
- Hold `A` or `D` to charge the left or right anchor.
- Release `A` or `D` to throw the anchor to that side of the boat.
- `Space` releases the active anchor.
- The thrown distance becomes the fixed rope length, so longer charge means a wider turn radius.
- Hitting a reef ends the run. `R` restarts.
- Distance is the only run score. Best distance is saved in `user://anchor_runner.save`.
- The start speed can be adjusted from the HUD slider.

## Files

- `scenes/Main.tscn`: boot scene for the prototype.
- `scripts/main.gd`: owns the game loop, boat movement, anchor mechanics, procedural spawning, collision checks, HUD, and placeholder drawing.
- `arts/duck_boat.png`: current boat sprite. The source art keeps its original orientation. `A` faces left, `D` flips to face right, and the facing is kept after releasing the anchor.
- `Main/Camera2D`: the camera node. Adjust `camera_zoom` on `Main` or the `Camera2D.zoom` value to change camera distance.
- `docs/anchor_runner_architecture.md`: this implementation note.

## Runtime Systems

- Boat controller:
  - Keeps the boat at world coordinates and uses `Camera2D` to follow it.
  - Without anchor, velocity eases back toward the river current instead of drifting forever along the last tangent.
  - With anchor, the boat uses an angular orbit model: `anchor_theta += angular_sign * speed / rope_length * delta`, then position is recalculated on the rope circle.
  - This avoids the zero-projection dead spot that happens when the current is perfectly radial to the rope.

- Anchor controller:
  - `charge_side` tracks left or right charging.
  - `A` uses side `-1` for the boat's left side. `D` uses side `1` for the boat's right side.
  - Anchors always throw horizontally in world space: `A` to `Vector2.LEFT`, `D` to `Vector2.RIGHT`.
  - `charge_time / charge_seconds` maps to `min_throw..max_throw`.
  - `charge_speed` controls how fast the charge bar fills. `1.0` is normal speed, `2.0` is twice as fast.
  - `anchor_side` controls clockwise/counterclockwise turning.

- World generator:
  - Spawns content ahead along the river's negative Y direction.
  - Keeps obstacles and pickups inside the river bounds.
  - Despawns content behind the boat.
  - Reefs and pickups are placeholder `Node2D` classes, drawn in code for fast iteration.

- Score:
  - Distance increases with speed.
  - Pickups currently add a small distance bonus.
  - Best distance persists locally.

## Art Replacement Points

- Replace `Obstacle._draw()` with coral/reef scene instances for the collage-style visual direction.
- Replace `BoatView._draw()` with the real boat sprite or animated scene.
- Replace `AnchorView._draw()` with anchor, rope, and throw indicator art.
- Keep each replacement centered around its node origin so the current collision radii still make sense.

## Next Useful Steps

- Split `scripts/main.gd` into separate `BoatController`, `AnchorController`, `WorldSpawner`, and `RunHud` scripts once the mechanics feel right.
- Add obstacle families with different collision radius, density, and visual silhouettes.
- Add item types only after deciding what can change besides distance, such as slow motion, reef shield, or score multiplier.
- Tune the exported variables on the `Main` node, including `default_start_speed`, `speed_gain_per_second`, `max_speed`, `min_throw`, `max_throw`, `charge_speed`, and the boat shadow settings.

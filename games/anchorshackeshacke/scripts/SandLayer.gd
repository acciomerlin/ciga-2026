extends Node2D

@export var ship_path: NodePath = NodePath("../PlayerShip")
@export var camera_path: NodePath = NodePath("../PlayerShip/Camera2D")

@export_group("Streaming Spawn")
@export var spawn_physics_sand := true:
	set(value):
		spawn_physics_sand = value
		_restart_spawning_if_ready()
@export_range(10, 2000, 1, "or_greater") var stones_per_chunk := 150:
	set(value):
		stones_per_chunk = int(value)
		_restart_spawning_if_ready()
@export_range(1, 300, 1) var spawn_per_frame := 36
@export_range(0.5, 8.0, 0.25) var stone_min_size_multiplier := 1.0:
	set(value):
		stone_min_size_multiplier = maxf(0.5, value)
		_restart_spawning_if_ready()
@export_range(0.5, 8.0, 0.25) var stone_max_size_multiplier := 3.0:
	set(value):
		stone_max_size_multiplier = maxf(stone_min_size_multiplier, value)
		_restart_spawning_if_ready()
@export var use_viewport_width_for_chunk := true:
	set(value):
		use_viewport_width_for_chunk = value
		_restart_spawning_if_ready()
@export var chunk_width := 1500.0:
	set(value):
		chunk_width = maxf(256.0, value)
		_restart_spawning_if_ready()
@export_range(1.0, 3.0, 0.05) var viewport_width_multiplier := 1.35:
	set(value):
		viewport_width_multiplier = value
		_restart_spawning_if_ready()
@export_range(0, 4, 1) var chunks_behind := 0:
	set(value):
		chunks_behind = int(value)
		_restart_spawning_if_ready()
@export_range(0, 6, 1) var chunks_ahead := 0:
	set(value):
		chunks_ahead = int(value)
		_restart_spawning_if_ready()
@export_range(0.0, 2.0, 0.05) var despawn_viewport_margin := 0.55:
	set(value):
		despawn_viewport_margin = maxf(0.0, value)
		_restart_spawning_if_ready()

@export_group("World")
@export var seabed_y := 210.0
@export var layer_depth := 112.0
@export var floor_thickness := 90.0
@export var lightweight_base_resistance := 0.72
@export var lightweight_depth_resistance := 0.34

@export_group("Debug")
@export var show_floor_debug := false:
	set(value):
		show_floor_debug = value
		if is_inside_tree():
			queue_redraw()

var _ship: Node2D
var _camera: Camera2D
var _rng := RandomNumberGenerator.new()
var _sand_texture := preload("res://assets/sand/sand_dune.png")
var _material := PhysicsMaterial.new()
var _chunk_nodes := {}
var _chunk_spawned_counts := {}
var _spawn_queue: Array[int] = []
var _floor_shape: RectangleShape2D
var _floor_body: StaticBody2D
var _is_ready := false


func _ready() -> void:
	_ship = get_node_or_null(ship_path) as Node2D
	_camera = get_node_or_null(camera_path) as Camera2D
	z_index = -20
	_rng.seed = 20260705
	_material.friction = 1.0
	_material.bounce = 0.04
	if spawn_physics_sand:
		_spawn_floor()
	_is_ready = true
	if spawn_physics_sand:
		_update_stream_window()


func _process(_delta: float) -> void:
	if not spawn_physics_sand:
		return
	_update_stream_window()
	if not _spawn_queue.is_empty():
		_spawn_sand_batch()


func _physics_process(_delta: float) -> void:
	if not spawn_physics_sand:
		return
	if _ship == null:
		return

	if _floor_body != null:
		_floor_body.global_position.x = _get_stream_center_x()
		if show_floor_debug:
			queue_redraw()


func _spawn_floor() -> void:
	_floor_body = StaticBody2D.new()
	_floor_body.name = "SandFloor"
	_floor_body.physics_material_override = _material
	add_child(_floor_body)

	_floor_shape = RectangleShape2D.new()
	_update_floor_shape()

	var collision := CollisionShape2D.new()
	collision.shape = _floor_shape
	collision.position = Vector2(0.0, seabed_y + layer_depth + floor_thickness * 0.5)
	_floor_body.add_child(collision)
	queue_redraw()


func _spawn_sand_batch() -> void:
	var budget := spawn_per_frame
	while budget > 0 and not _spawn_queue.is_empty():
		var chunk_index: int = _spawn_queue[0]
		if not _chunk_nodes.has(chunk_index):
			_spawn_queue.remove_at(0)
			continue

		var spawned: int = int(_chunk_spawned_counts.get(chunk_index, 0))
		var remaining := stones_per_chunk - spawned
		if remaining <= 0:
			_spawn_queue.remove_at(0)
			continue

		var batch_count := budget
		if remaining < batch_count:
			batch_count = remaining

		var chunk_node: Node2D = _chunk_nodes[chunk_index] as Node2D
		var stream_width := _get_stream_width()
		var chunk_start_x := float(chunk_index) * stream_width
		for i in range(batch_count):
			var body := _create_sand_body(chunk_index, spawned)
			chunk_node.add_child(body)
			var x := chunk_start_x + _rng.randf() * stream_width
			_reset_body(body, x)
			spawned += 1
			budget -= 1

		_chunk_spawned_counts[chunk_index] = spawned
		if spawned >= stones_per_chunk:
			_spawn_queue.remove_at(0)


func _update_stream_window() -> void:
	if not is_inside_tree():
		return
	if not spawn_physics_sand:
		return

	var range := _get_active_chunk_range()
	var first_chunk: int = range.x
	var last_chunk: int = range.y

	for chunk_index in range(first_chunk, last_chunk + 1):
		_ensure_chunk(chunk_index)

	var existing_chunks: Array = _chunk_nodes.keys()
	for chunk_index in existing_chunks:
		if chunk_index < first_chunk or chunk_index > last_chunk:
			_remove_chunk(int(chunk_index))

	_update_floor_shape()
	queue_redraw()


func _ensure_chunk(chunk_index: int) -> void:
	if _chunk_nodes.has(chunk_index):
		return

	var chunk_node := Node2D.new()
	chunk_node.name = "SandChunk%d" % chunk_index
	add_child(chunk_node)
	_chunk_nodes[chunk_index] = chunk_node
	_chunk_spawned_counts[chunk_index] = 0
	_spawn_queue.append(chunk_index)


func _remove_chunk(chunk_index: int) -> void:
	var chunk_node: Node2D = _chunk_nodes.get(chunk_index, null) as Node2D
	if chunk_node != null and is_instance_valid(chunk_node):
		chunk_node.queue_free()

	_chunk_nodes.erase(chunk_index)
	_chunk_spawned_counts.erase(chunk_index)
	while _spawn_queue.has(chunk_index):
		_spawn_queue.erase(chunk_index)


func _start_sand_rebuild() -> void:
	for chunk_index in _chunk_nodes.keys():
		_remove_chunk(int(chunk_index))
	_spawn_queue.clear()
	if _floor_body != null and is_instance_valid(_floor_body):
		_floor_body.queue_free()
		_floor_body = null
	if spawn_physics_sand:
		_spawn_floor()
		_update_stream_window()


func _restart_spawning_if_ready() -> void:
	if _is_ready and is_inside_tree():
		_start_sand_rebuild()


func _get_stream_center_x() -> float:
	if _camera != null:
		return _camera.global_position.x
	if _ship != null:
		return _ship.global_position.x
	return global_position.x


func _get_stream_width() -> float:
	if not use_viewport_width_for_chunk:
		return chunk_width

	var viewport_width := get_viewport_rect().size.x * viewport_width_multiplier
	return maxf(chunk_width, viewport_width)


func _get_floor_width() -> float:
	return _get_stream_width() * float(chunks_behind + chunks_ahead + 3)


func _get_visible_world_width() -> float:
	var viewport_width := get_viewport_rect().size.x
	if _camera != null:
		viewport_width *= _camera.zoom.x
	return viewport_width


func _get_active_chunk_range() -> Vector2i:
	var stream_width := _get_stream_width()
	var visible_half_width := _get_visible_world_width() * 0.5
	var margin := visible_half_width * despawn_viewport_margin
	var center_x := _get_stream_center_x()
	var first_chunk := int(floor((center_x - visible_half_width - margin) / stream_width)) - chunks_behind
	var last_chunk := int(floor((center_x + visible_half_width + margin) / stream_width)) + chunks_ahead
	return Vector2i(first_chunk, last_chunk)


func _update_floor_shape() -> void:
	if _floor_shape == null:
		return
	_floor_shape.size = Vector2(_get_floor_width(), floor_thickness)


func _create_sand_body(chunk_index: int, index: int) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.name = "SandStone%d_%03d" % [chunk_index, index]
	body.add_to_group("sand_stone")
	body.gravity_scale = 0.22
	body.linear_damp = 3.4
	body.angular_damp = 4.6
	var size_multiplier := _rng.randf_range(stone_min_size_multiplier, stone_max_size_multiplier)
	body.mass = _rng.randf_range(0.35, 1.4) * size_multiplier
	body.physics_material_override = _material
	body.can_sleep = true

	var stone_radius := _rng.randf_range(7.0, 20.0) * size_multiplier
	var points := _make_polygon(_rng.randi_range(6, 7), stone_radius, _rng.randf_range(0.62, 1.18))

	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = points
	visual.uv = _make_uv(points)
	visual.texture = _sand_texture
	visual.color = Color(1.0, _rng.randf_range(0.92, 1.0), _rng.randf_range(0.72, 0.9), _rng.randf_range(0.82, 1.0))
	body.add_child(visual)

	var collision := CollisionPolygon2D.new()
	collision.name = "Collision"
	collision.polygon = points
	body.add_child(collision)

	return body


func sample_anchor_resistance(world_point: Vector2, radius: float, disturb_strength := 0.0) -> Dictionary:
	var depth := world_point.y - seabed_y
	if depth < -radius:
		return {
			"value": 0.0,
			"contacts": 0,
			"depth": 0.0,
			"label": "water"
		}

	if not spawn_physics_sand:
		return _sample_lightweight_anchor_resistance(depth)

	var stream_width := _get_stream_width()
	var center_chunk := int(floor(world_point.x / stream_width))
	var radius_squared := radius * radius
	var contact_weight := 0.0
	var contacts := 0

	for chunk_index in range(center_chunk - 1, center_chunk + 2):
		var chunk_node: Node2D = _chunk_nodes.get(chunk_index, null) as Node2D
		if chunk_node == null:
			continue

		for child in chunk_node.get_children():
			var body: RigidBody2D = child as RigidBody2D
			if body == null:
				continue

			var offset := body.global_position - world_point
			var distance_squared := offset.length_squared()
			if distance_squared > radius_squared:
				continue

			var distance := sqrt(distance_squared)
			var closeness := 1.0 - distance / radius
			contact_weight += closeness
			contacts += 1

			if disturb_strength > 0.0:
				var push_direction := offset.normalized()
				if push_direction == Vector2.ZERO:
					push_direction = Vector2.RIGHT.rotated(_rng.randf_range(-PI, PI))
				body.sleeping = false
				body.apply_central_impulse(push_direction * disturb_strength * (0.35 + closeness))

	var depth_factor := clampf(depth / maxf(layer_depth, 1.0), 0.0, 1.0)
	var contact_factor := clampf(contact_weight / 3.0, 0.0, 1.0)
	var resistance := clampf(depth_factor * 0.46 + contact_factor * 0.74, 0.0, 1.0)

	return {
		"value": resistance,
		"contacts": contacts,
		"depth": depth_factor,
		"label": "sand_stone" if contacts > 0 else "sand"
	}


func _sample_lightweight_anchor_resistance(depth: float) -> Dictionary:
	var depth_factor: float = clampf(depth / maxf(layer_depth, 1.0), 0.0, 1.0)
	var resistance: float = clampf(lightweight_base_resistance + depth_factor * lightweight_depth_resistance, 0.0, 1.0)
	return {
		"value": resistance,
		"contacts": int(round(4.0 + depth_factor * 8.0)),
		"depth": depth_factor,
		"label": "lightweight_sand"
	}


func _reset_body(body: RigidBody2D, x: float) -> void:
	var depth_t := _rng.randf()
	body.global_position = Vector2(
		x,
		seabed_y + depth_t * layer_depth + sin(x * 0.015) * 14.0
	)
	body.rotation = _rng.randf_range(-PI, PI)
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	body.sleeping = true


func _make_polygon(point_count: int, radius: float, squash: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var start_angle := _rng.randf_range(0.0, TAU)
	for i in range(point_count):
		var t := float(i) / float(point_count)
		var angle := start_angle + t * TAU
		var wobble := _rng.randf_range(0.72, 1.18)
		points.append(Vector2(cos(angle) * radius * wobble, sin(angle) * radius * squash * wobble))
	return points


func _make_uv(points: PackedVector2Array) -> PackedVector2Array:
	var uv := PackedVector2Array()
	for point in points:
		uv.append(point + Vector2(16.0, 16.0))
	return uv


func _draw() -> void:
	if not show_floor_debug:
		return

	var center_x := 0.0
	if _floor_body != null:
		center_x = _floor_body.position.x

	var floor_top := seabed_y + layer_depth
	var floor_width := _get_floor_width()
	var floor_rect := Rect2(
		center_x - floor_width * 0.5,
		floor_top,
		floor_width,
		floor_thickness
	)
	var floor_right := floor_rect.position.x + floor_rect.size.x
	draw_rect(floor_rect, Color(0.0, 0.0, 0.0, 0.08), true)
	draw_line(
		Vector2(floor_rect.position.x, floor_top),
		Vector2(floor_right, floor_top),
		Color(0.0, 0.0, 0.0, 0.55),
		2.0
	)

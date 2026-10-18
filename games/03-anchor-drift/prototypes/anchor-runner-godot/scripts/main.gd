extends Node2D

const SAVE_PATH := "user://anchor_runner.save"

@export_group("Camera")
@export var camera_zoom := Vector2(1.0, 1.0)

@export_group("River")
@export var world_forward_buffer := 1900.0
@export var river_half_width := 460.0
@export var shore_width := 150.0
@export var world_side_margin := 70.0
@export var despawn_behind := 1050.0
@export var spawn_step := 260.0

@export_group("Anchor")
@export var min_throw := 150.0
@export var max_throw := 520.0
@export var charge_seconds := 1.25
@export var charge_speed := 1.0

@export_group("Speed")
@export var default_start_speed := 230.0
@export var speed_gain_per_second := 4.5
@export var max_speed := 620.0
@export var current_alignment := 3.0

@export_group("Score")
@export var km_scale := 6000.0
@export var pickup_distance_bonus := 250.0

@export_group("HUD")
@export var speed_slider_min := 140.0
@export var speed_slider_max := 360.0
@export var speed_slider_step := 10.0

@export_group("Sprites")
@export var boat_texture: Texture2D = preload("res://arts/duck_boat.png")
@export var boat_sprite_longest_side := 96.0
@export var boat_shadow_enabled := true
@export var boat_shadow_offset := Vector2(6.0, 10.0)
@export var boat_shadow_size := Vector2(62.0, 24.0)
@export var boat_shadow_color := Color(0.0, 0.0, 0.0, 0.28)

var boat_pos := Vector2.ZERO
var boat_velocity := Vector2.ZERO
var speed := 230.0
var distance_m := 0.0
var best_distance_m := 0.0
var run_active := true

var anchor_active := false
var anchor_pos := Vector2.ZERO
var rope_length := 260.0
var anchor_side := 0
var anchor_theta := 0.0
var anchor_angular_sign := 1.0
var charge_side := 0
var charge_time := 0.0

var spawn_cursor := -500.0
var rng := RandomNumberGenerator.new()
var obstacles: Array[Obstacle] = []
var pickups: Array[Pickup] = []

var camera: Camera2D
var boat: BoatView
var anchor_view: AnchorView
var world_items: Node2D
var distance_label: Label
var best_label: Label
var hint_label: Label
var speed_value_label: Label
var charge_bar: ProgressBar
var speed_slider: HSlider
var game_over_panel: PanelContainer


func _ready() -> void:
	rng.randomize()
	_load_best()
	_build_scene()
	_reset_run()


func _process(_delta: float) -> void:
	camera.zoom = camera_zoom
	boat.shadow_enabled = boat_shadow_enabled
	boat.shadow_offset = boat_shadow_offset
	boat.shadow_size = boat_shadow_size
	boat.shadow_color = boat_shadow_color
	queue_redraw()
	boat.queue_redraw()
	anchor_view.queue_redraw()
	_update_hud()


func _physics_process(delta: float) -> void:
	if not run_active:
		if Input.is_action_just_pressed("restart_run"):
			_reset_run()
		return

	camera.zoom = camera_zoom
	_update_anchor_input(delta)
	speed = minf(speed + speed_gain_per_second * delta, max_speed)
	_apply_boat_motion(delta)
	_spawn_world()
	_despawn_old_items()
	_check_collisions()
	camera.global_position = boat_pos


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	var top_left := camera.global_position - viewport_size * 0.65
	var bottom_right := camera.global_position + viewport_size * 0.65
	draw_rect(Rect2(top_left, bottom_right - top_left), Color(0.25, 0.42, 0.22), true)

	var river_rect := Rect2(Vector2(-river_half_width, top_left.y), Vector2(river_half_width * 2.0, bottom_right.y - top_left.y))
	draw_rect(river_rect, Color(0.04, 0.33, 0.46), true)
	draw_rect(Rect2(Vector2(-river_half_width - shore_width, top_left.y), Vector2(shore_width, bottom_right.y - top_left.y)), Color(0.68, 0.58, 0.32), true)
	draw_rect(Rect2(Vector2(river_half_width, top_left.y), Vector2(shore_width, bottom_right.y - top_left.y)), Color(0.68, 0.58, 0.32), true)
	draw_line(Vector2(-river_half_width, top_left.y), Vector2(-river_half_width, bottom_right.y), Color(0.93, 0.82, 0.45), 6.0)
	draw_line(Vector2(river_half_width, top_left.y), Vector2(river_half_width, bottom_right.y), Color(0.93, 0.82, 0.45), 6.0)

	var grid := 160.0
	var start_y := floorf(top_left.y / grid) * grid
	var water_line := Color(0.22, 0.63, 0.71, 0.18)
	for y in range(int(start_y), int(bottom_right.y + grid), int(grid)):
		draw_line(Vector2(-river_half_width + 28.0, y), Vector2(river_half_width - 28.0, y + 80.0), water_line, 2.0)
		draw_circle(Vector2(-river_half_width - 70.0, y + 35.0), 18.0, Color(0.19, 0.36, 0.16, 0.9))
		draw_circle(Vector2(river_half_width + 70.0, y + 105.0), 22.0, Color(0.19, 0.36, 0.16, 0.9))


func _build_scene() -> void:
	world_items = Node2D.new()
	world_items.name = "GeneratedWorld"
	add_child(world_items)

	boat = BoatView.new()
	boat.name = "Boat"
	boat.texture = boat_texture
	boat.sprite_longest_side = boat_sprite_longest_side
	boat.shadow_enabled = boat_shadow_enabled
	boat.shadow_offset = boat_shadow_offset
	boat.shadow_size = boat_shadow_size
	boat.shadow_color = boat_shadow_color
	add_child(boat)

	anchor_view = AnchorView.new()
	anchor_view.name = "Anchor"
	anchor_view.min_throw = min_throw
	anchor_view.max_throw = max_throw
	add_child(anchor_view)

	camera = get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		camera = Camera2D.new()
		camera.name = "Camera2D"
		add_child(camera)
	camera.zoom = camera_zoom
	camera.enabled = true

	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	canvas.add_child(margin)

	var hud := VBoxContainer.new()
	hud.add_theme_constant_override("separation", 8)
	margin.add_child(hud)

	distance_label = Label.new()
	distance_label.add_theme_font_size_override("font_size", 28)
	hud.add_child(distance_label)

	best_label = Label.new()
	best_label.add_theme_font_size_override("font_size", 18)
	hud.add_child(best_label)

	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 8)
	hud.add_child(speed_row)

	var speed_title := Label.new()
	speed_title.text = "Start speed"
	speed_title.custom_minimum_size = Vector2(86, 0)
	speed_row.add_child(speed_title)

	speed_slider = HSlider.new()
	speed_slider.custom_minimum_size = Vector2(210, 18)
	speed_slider.min_value = speed_slider_min
	speed_slider.max_value = speed_slider_max
	speed_slider.step = speed_slider_step
	speed_slider.value = default_start_speed
	speed_slider.value_changed.connect(_on_speed_slider_changed)
	speed_row.add_child(speed_slider)

	speed_value_label = Label.new()
	speed_value_label.custom_minimum_size = Vector2(58, 0)
	speed_row.add_child(speed_value_label)

	charge_bar = ProgressBar.new()
	charge_bar.custom_minimum_size = Vector2(260, 18)
	charge_bar.min_value = 0.0
	charge_bar.max_value = 1.0
	charge_bar.value = 0.0
	hud.add_child(charge_bar)

	hint_label = Label.new()
	hint_label.text = "Hold A/D to charge side anchors. Space releases anchor."
	hint_label.add_theme_font_size_override("font_size", 14)
	hud.add_child(hint_label)

	game_over_panel = PanelContainer.new()
	game_over_panel.visible = false
	game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	game_over_panel.position = Vector2(-190, -58)
	game_over_panel.custom_minimum_size = Vector2(380, 116)
	canvas.add_child(game_over_panel)

	var game_over_box := VBoxContainer.new()
	game_over_box.alignment = BoxContainer.ALIGNMENT_CENTER
	game_over_box.add_theme_constant_override("separation", 8)
	game_over_panel.add_child(game_over_box)

	var title := Label.new()
	title.text = "Run Ended"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	game_over_box.add_child(title)

	var restart := Label.new()
	restart.text = "Press R to restart"
	restart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart.add_theme_font_size_override("font_size", 18)
	game_over_box.add_child(restart)


func _reset_run() -> void:
	for obstacle in obstacles:
		obstacle.queue_free()
	for pickup in pickups:
		pickup.queue_free()
	obstacles.clear()
	pickups.clear()

	boat_pos = Vector2.ZERO
	speed = default_start_speed
	boat_velocity = Vector2(0.0, -speed)
	distance_m = 0.0
	spawn_cursor = 500.0
	anchor_active = false
	charge_side = 0
	charge_time = 0.0
	boat.reset_facing()
	boat.set_heading(boat_velocity)
	run_active = true
	game_over_panel.visible = false
	camera.global_position = boat_pos
	_spawn_world()


func _update_anchor_input(delta: float) -> void:
	if Input.is_action_just_pressed("release_anchor"):
		_release_anchor()

	if anchor_active:
		return

	if charge_side == 0:
		if Input.is_action_pressed("anchor_left"):
			charge_side = -1
			charge_time = 0.0
			boat.set_anchor_side(charge_side)
		elif Input.is_action_pressed("anchor_right"):
			charge_side = 1
			charge_time = 0.0
			boat.set_anchor_side(charge_side)
	else:
		charge_time = minf(charge_time + delta * maxf(charge_speed, 0.0), maxf(charge_seconds, 0.0))
		var action := "anchor_left" if charge_side == -1 else "anchor_right"
		if not Input.is_action_pressed(action):
			_throw_anchor(charge_side, _charge_ratio())


func _throw_anchor(side: int, charge_ratio: float) -> void:
	var side_dir := _anchor_side_direction(side)
	var throw_distance := lerpf(min_throw, max_throw, clampf(charge_ratio, 0.0, 1.0))
	anchor_pos = boat_pos + side_dir * throw_distance
	rope_length = throw_distance
	anchor_side = side
	var radial := boat_pos - anchor_pos
	anchor_theta = atan2(radial.y, radial.x)
	var tangent_plus := Vector2(-sin(anchor_theta), cos(anchor_theta))
	anchor_angular_sign = 1.0 if tangent_plus.dot(_current_velocity()) >= 0.0 else -1.0
	anchor_active = true
	boat.set_anchor_side(side)
	charge_side = 0
	charge_time = 0.0


func _anchor_side_direction(side: int) -> Vector2:
	return Vector2.LEFT if side < 0 else Vector2.RIGHT


func _river_forward() -> Vector2:
	return Vector2.UP


func _current_velocity() -> Vector2:
	return _river_forward() * speed


func _charge_ratio() -> float:
	if charge_seconds <= 0.0:
		return 1.0
	return clampf(charge_time / charge_seconds, 0.0, 1.0)


func _release_anchor() -> void:
	anchor_active = false
	charge_side = 0
	charge_time = 0.0


func _apply_boat_motion(delta: float) -> void:
	var current := _current_velocity()
	if anchor_active:
		var previous_pos := boat_pos
		var safe_rope_length := maxf(rope_length, 1.0)
		var angular_speed := speed / safe_rope_length
		anchor_theta += anchor_angular_sign * angular_speed * delta
		boat_pos = anchor_pos + Vector2(cos(anchor_theta), sin(anchor_theta)) * safe_rope_length
		boat_velocity = (boat_pos - previous_pos) / maxf(delta, 0.0001)
	else:
		boat_velocity = boat_velocity.lerp(current, clampf(delta * current_alignment, 0.0, 1.0))
		boat_pos += boat_velocity * delta

	distance_m += speed * delta
	boat.global_position = boat_pos
	boat.set_heading(boat_velocity)
	anchor_view.min_throw = min_throw
	anchor_view.max_throw = max_throw
	anchor_view.configure(anchor_active, anchor_pos, boat_pos, boat_velocity.normalized(), charge_side, _charge_ratio())


func _spawn_world() -> void:
	var target_y := boat_pos.y - world_forward_buffer

	while spawn_cursor > target_y:
		spawn_cursor -= spawn_step
		for i in range(rng.randi_range(1, 3)):
			var world_side_buffer := river_half_width - world_side_margin
			var lane_offset := rng.randf_range(-world_side_buffer, world_side_buffer)
			var pos := Vector2(lane_offset, spawn_cursor)
			if pos.distance_to(boat_pos) < 520.0:
				continue
			var obstacle := Obstacle.new()
			obstacle.radius = rng.randf_range(30.0, 76.0)
			obstacle.palette_index = rng.randi_range(0, 3)
			obstacle.rotation = rng.randf_range(0.0, TAU)
			obstacle.global_position = pos
			world_items.add_child(obstacle)
			obstacles.append(obstacle)

		if rng.randf() < 0.28:
			var pickup := Pickup.new()
			var pickup_side_buffer := (river_half_width - world_side_margin) * 0.75
			pickup.global_position = Vector2(rng.randf_range(-pickup_side_buffer, pickup_side_buffer), spawn_cursor)
			world_items.add_child(pickup)
			pickups.append(pickup)


func _despawn_old_items() -> void:
	for i in range(obstacles.size() - 1, -1, -1):
		if obstacles[i].global_position.y > boat_pos.y + despawn_behind:
			obstacles[i].queue_free()
			obstacles.remove_at(i)
	for i in range(pickups.size() - 1, -1, -1):
		if pickups[i].global_position.y > boat_pos.y + despawn_behind:
			pickups[i].queue_free()
			pickups.remove_at(i)


func _check_collisions() -> void:
	if absf(boat_pos.x) > river_half_width - 28.0:
		_end_run()
		return

	for obstacle in obstacles:
		if boat_pos.distance_to(obstacle.global_position) < obstacle.radius + 24.0:
			_end_run()
			return

	for i in range(pickups.size() - 1, -1, -1):
		if boat_pos.distance_to(pickups[i].global_position) < 42.0:
			distance_m += pickup_distance_bonus
			pickups[i].queue_free()
			pickups.remove_at(i)


func _end_run() -> void:
	run_active = false
	_release_anchor()
	if distance_m > best_distance_m:
		best_distance_m = distance_m
		_save_best()
	game_over_panel.visible = true


func _update_hud() -> void:
	distance_label.text = "Distance: %.2f km" % (distance_m / km_scale)
	best_label.text = "Best: %.2f km" % (best_distance_m / km_scale)
	speed_value_label.text = "%d" % int(default_start_speed)
	if anchor_active:
		charge_bar.value = 0.0
	elif charge_side != 0:
		charge_bar.value = _charge_ratio()
	else:
		charge_bar.value = 0.0


func _on_speed_slider_changed(value: float) -> void:
	default_start_speed = value
	if distance_m <= 1.0 and not anchor_active:
		speed = default_start_speed
		boat_velocity = boat_velocity.normalized() * speed


func _load_best() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		best_distance_m = file.get_float()


func _save_best() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_float(best_distance_m)


class BoatView:
	extends Node2D

	var texture: Texture2D
	var sprite_longest_side := 96.0
	var shadow_enabled := true
	var shadow_offset := Vector2(6.0, 10.0)
	var shadow_size := Vector2(62.0, 24.0)
	var shadow_color := Color(0.0, 0.0, 0.0, 0.28)
	var sprite: Sprite2D
	var anchor_side := 0
	var velocity := Vector2.UP

	func _ready() -> void:
		sprite = Sprite2D.new()
		sprite.texture = texture
		if sprite.texture:
			var texture_size := sprite.texture.get_size()
			var longest_side := maxf(texture_size.x, texture_size.y)
			if longest_side > 0.0:
				sprite.scale = Vector2.ONE * (sprite_longest_side / longest_side)
		add_child(sprite)

	func set_anchor_side(side: int) -> void:
		anchor_side = side
		if sprite and side != 0:
			sprite.flip_h = side > 0
		set_heading(velocity)

	func reset_facing() -> void:
		anchor_side = 0
		if sprite:
			sprite.flip_h = false
		set_heading(velocity)

	func set_heading(new_velocity: Vector2) -> void:
		if new_velocity.length_squared() > 0.01:
			velocity = new_velocity.normalized()
		rotation = 0.0

	func _draw() -> void:
		if shadow_enabled:
			draw_set_transform(shadow_offset, 0.0, shadow_size * 0.5)
			draw_circle(Vector2.ZERO, 1.0, shadow_color)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		if sprite and sprite.texture:
			return

		var hull := PackedVector2Array([
			Vector2(0, -42),
			Vector2(24, 4),
			Vector2(16, 36),
			Vector2(-16, 36),
			Vector2(-24, 4),
		])
		draw_colored_polygon(hull, Color(0.95, 0.72, 0.32))
		draw_polyline(_closed(hull), Color(0.15, 0.11, 0.09), 4.0)
		draw_circle(Vector2(0, 2), 12.0, Color(0.28, 0.17, 0.12))
		draw_line(Vector2(-16, 28), Vector2(16, 28), Color(0.12, 0.08, 0.05), 3.0)

	func _closed(source: PackedVector2Array) -> PackedVector2Array:
		var closed := PackedVector2Array(source)
		closed.append(source[0])
		return closed


class AnchorView:
	extends Node2D

	var min_throw := 150.0
	var max_throw := 520.0
	var active := false
	var anchor := Vector2.ZERO
	var boat := Vector2.ZERO
	var boat_forward := Vector2.UP
	var charging_side := 0
	var charge_ratio := 0.0

	func configure(is_active: bool, anchor_position: Vector2, boat_position: Vector2, forward: Vector2, side: int, ratio: float) -> void:
		active = is_active
		anchor = anchor_position
		boat = boat_position
		boat_forward = forward
		charging_side = side
		charge_ratio = ratio

	func _draw() -> void:
		if active:
			draw_line(to_local(boat), to_local(anchor), Color(0.9, 0.86, 0.72), 3.0)
			draw_circle(to_local(anchor), 12.0, Color(0.08, 0.08, 0.1))
			draw_arc(to_local(anchor), 24.0, 0.0, TAU, 24, Color(0.9, 0.86, 0.72), 4.0)
		elif charging_side != 0:
			var dir := Vector2.LEFT if charging_side < 0 else Vector2.RIGHT
			var reach := lerpf(min_throw, max_throw, clampf(charge_ratio, 0.0, 1.0))
			draw_line(to_local(boat), to_local(boat + dir * reach), Color(0.9, 0.86, 0.72, 0.5), 2.0)


class Obstacle:
	extends Node2D

	var radius := 52.0
	var palette_index := 0
	var points := PackedVector2Array()

	func _ready() -> void:
		var sides := 9
		for i in range(sides):
			var angle := TAU * float(i) / float(sides)
			var wobble := 0.7 + randf() * 0.45
			points.append(Vector2(cos(angle), sin(angle)) * radius * wobble)

	func _draw() -> void:
		var fills := [
			Color(0.95, 0.25, 0.45),
			Color(0.09, 0.73, 0.78),
			Color(0.98, 0.78, 0.18),
			Color(0.48, 0.25, 0.86),
		]
		var dark := Color(0.08, 0.08, 0.12)
		draw_colored_polygon(points, fills[palette_index % fills.size()])
		draw_polyline(_closed(points), dark, 4.0)
		for i in range(5):
			var angle := TAU * float(i) / 5.0 + 0.3
			var a := Vector2(cos(angle), sin(angle)) * radius * 0.25
			var b := Vector2(cos(angle), sin(angle)) * radius * 0.7
			draw_line(a, b, Color(1.0, 1.0, 1.0, 0.35), 3.0)

	func _closed(source: PackedVector2Array) -> PackedVector2Array:
		var closed := PackedVector2Array(source)
		closed.append(source[0])
		return closed


class Pickup:
	extends Node2D

	var phase := randf() * TAU

	func _process(delta: float) -> void:
		phase += delta * 3.0
		queue_redraw()

	func _draw() -> void:
		var bob := sin(phase) * 4.0
		draw_circle(Vector2(0, bob), 20.0, Color(0.98, 0.9, 0.25))
		draw_arc(Vector2(0, bob), 27.0, 0.0, TAU, 24, Color(0.1, 0.1, 0.12), 3.0)
		draw_line(Vector2(-10, bob), Vector2(10, bob), Color(0.1, 0.1, 0.12), 3.0)

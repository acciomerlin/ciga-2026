extends Node2D

const KIND_ICEBERG := 0
const KIND_FLOATING_BARRIER := 1


class Obstacle:
	var x: float
	var width: float
	var height: float
	var kind: int
	var checked: bool = false
	var hit: bool = false

	func _init(spawn_x: float, spawn_width: float, spawn_height: float, spawn_kind: int) -> void:
		x = spawn_x
		width = spawn_width
		height = spawn_height
		kind = spawn_kind


@export var ship_path: NodePath = NodePath("../PlayerShip")
@export var ui_path: NodePath = NodePath("../UI")

@export_group("Runner Speed")
@export var start_cruise_speed: float = 128.0
@export var max_cruise_speed: float = 360.0
@export var acceleration_per_second: float = 5.6
@export var iceberg_safe_speed: float = 32.0

@export_group("Obstacle Spawn")
@export var waterline_y: float = 38.0
@export var spawn_ahead_distance: float = 1420.0
@export var despawn_behind_distance: float = 880.0
@export var min_spawn_gap: float = 760.0
@export var max_spawn_gap: float = 1120.0
@export var barrier_clearance_required: float = 86.0
@export var iceberg_stop_window: float = 150.0

var _ship: Node2D
var _ui_layer: CanvasLayer
var _hud_label: Label
var _rng := RandomNumberGenerator.new()
var _target_cruise_speed: float = 128.0
var _next_spawn_x: float = 0.0
var _obstacles: Array[Obstacle] = []
var _score: int = 0
var _hit_count: int = 0
var _distance: float = 0.0
var _last_ship_x: float = 0.0
var _message: String = "Space 抛锚，R 收锚跳起"
var _message_time: float = 2.0


func _ready() -> void:
	_ship = get_node_or_null(ship_path) as Node2D
	_ui_layer = get_node_or_null(ui_path) as CanvasLayer
	_rng.seed = 2026070517
	z_index = 42
	_target_cruise_speed = start_cruise_speed
	if _ship != null:
		_last_ship_x = _ship.global_position.x
		_next_spawn_x = _last_ship_x + spawn_ahead_distance * 0.72
		if _ship.has_method("set_cruise_speed"):
			_ship.call("set_cruise_speed", _target_cruise_speed)
	_ensure_hud()


func _physics_process(delta: float) -> void:
	if _ship == null:
		return

	_target_cruise_speed = minf(max_cruise_speed, _target_cruise_speed + acceleration_per_second * delta)
	if _ship.has_method("set_cruise_speed"):
		_ship.call("set_cruise_speed", _target_cruise_speed)

	var ship_x: float = _ship.global_position.x
	_distance += maxf(0.0, ship_x - _last_ship_x)
	_last_ship_x = ship_x

	_spawn_obstacles_if_needed()
	_check_obstacle_hits()
	_prune_obstacles()
	_message_time = maxf(0.0, _message_time - delta)
	_update_hud()
	queue_redraw()


func _spawn_obstacles_if_needed() -> void:
	var front_x: float = _get_ship_front_x()
	while _next_spawn_x < front_x + spawn_ahead_distance:
		_spawn_obstacle(_next_spawn_x)
		_next_spawn_x += _rng.randf_range(min_spawn_gap, max_spawn_gap)


func _spawn_obstacle(spawn_x: float) -> void:
	var kind: int = KIND_ICEBERG
	if _rng.randf() > 0.58:
		kind = KIND_FLOATING_BARRIER

	var width: float = _rng.randf_range(84.0, 132.0)
	var height: float = _rng.randf_range(82.0, 145.0)
	if kind == KIND_FLOATING_BARRIER:
		width = _rng.randf_range(100.0, 164.0)
		height = _rng.randf_range(36.0, 58.0)
	_obstacles.append(Obstacle.new(spawn_x, width, height, kind))


func _check_obstacle_hits() -> void:
	var front_x: float = _get_ship_front_x()
	var speed: float = _get_ship_speed()
	var clearance: float = _get_ship_clearance()

	for obstacle in _obstacles:
		if obstacle.checked:
			continue
		if front_x < obstacle.x:
			if obstacle.kind == KIND_ICEBERG and front_x >= obstacle.x - iceberg_stop_window and speed <= iceberg_safe_speed:
				obstacle.checked = true
				_register_pass(obstacle)
			continue
		if front_x > obstacle.x + obstacle.width:
			obstacle.checked = true
			_register_pass(obstacle)
			continue

		if obstacle.kind == KIND_ICEBERG:
			obstacle.checked = true
			if speed <= iceberg_safe_speed:
				_register_pass(obstacle)
			else:
				_register_hit(obstacle, 1.0)
		else:
			obstacle.checked = true
			if clearance >= barrier_clearance_required:
				_register_pass(obstacle)
			else:
				_register_hit(obstacle, 0.72)


func _register_pass(obstacle: Obstacle) -> void:
	if obstacle.kind == KIND_ICEBERG:
		_score += 180
		_message = "冰山前停住了 +180"
	else:
		_score += 120
		_message = "反冲越过障碍 +120"
	_message_time = 1.1


func _register_hit(obstacle: Obstacle, strength: float) -> void:
	obstacle.hit = true
	_hit_count += 1
	_target_cruise_speed = maxf(start_cruise_speed, _target_cruise_speed * 0.76)
	if _ship != null and _ship.has_method("register_runner_hit"):
		_ship.call("register_runner_hit", strength)
	if obstacle.kind == KIND_ICEBERG:
		_message = "撞上冰山：要先 Space 抛锚停船"
	else:
		_message = "撞上海面障碍：锁住后 R 收锚跳"
	_message_time = 1.6


func _prune_obstacles() -> void:
	var ship_x: float = _ship.global_position.x
	var kept: Array[Obstacle] = []
	for obstacle in _obstacles:
		if obstacle.x + obstacle.width > ship_x - despawn_behind_distance:
			kept.append(obstacle)
	_obstacles = kept


func _get_ship_front_x() -> float:
	if _ship != null and _ship.has_method("get_runner_front_x"):
		var value: Variant = _ship.call("get_runner_front_x")
		if value is float:
			return float(value)
	return _ship.global_position.x + 565.0


func _get_ship_speed() -> float:
	if _ship != null and _ship.has_method("get_current_speed"):
		var value: Variant = _ship.call("get_current_speed")
		if value != null:
			return float(value)
	return 0.0


func _get_ship_clearance() -> float:
	if _ship != null and _ship.has_method("get_runner_clearance"):
		var value: Variant = _ship.call("get_runner_clearance")
		if value != null:
			return float(value)
	return 0.0


func _ensure_hud() -> void:
	if _ui_layer == null or _hud_label != null:
		return

	_hud_label = Label.new()
	_hud_label.name = "RunnerHUD"
	_hud_label.position = Vector2(18.0, 16.0)
	_hud_label.size = Vector2(580.0, 118.0)
	_hud_label.add_theme_font_size_override("font_size", 18)
	_hud_label.add_theme_color_override("font_color", Color(0.02, 0.02, 0.02, 1.0))
	_hud_label.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.9))
	_hud_label.add_theme_constant_override("shadow_offset_x", 2)
	_hud_label.add_theme_constant_override("shadow_offset_y", 2)
	_ui_layer.add_child(_hud_label)
	_update_hud()


func _update_hud() -> void:
	if _hud_label == null:
		return

	var speed: float = _get_ship_speed()
	var clearance: float = _get_ship_clearance()
	var hud_text := "分数 %d   距离 %dm   速度 %.0f\nSpace 抛锚刹车   R 收锚反冲跳\n%s" % [
		_score,
		int(_distance / 10.0),
		speed,
		_message if _message_time > 0.0 else "冰山要停，矮障碍要跳；后面会越来越快"
	]
	if clearance > 1.0:
		hud_text += "   跳跃 %.0f" % clearance
	_hud_label.text = hud_text


func _draw() -> void:
	_draw_waterline()
	for obstacle in _obstacles:
		if obstacle.kind == KIND_ICEBERG:
			_draw_iceberg(obstacle)
		else:
			_draw_floating_barrier(obstacle)


func _draw_waterline() -> void:
	var ship_x: float = 0.0
	if _ship != null:
		ship_x = _ship.global_position.x
	var left: float = ship_x - 900.0
	var right: float = ship_x + 1700.0
	draw_line(Vector2(left, waterline_y), Vector2(right, waterline_y), Color(0.94, 0.98, 1.0, 0.26), 3.0)


func _draw_iceberg(obstacle: Obstacle) -> void:
	var x: float = obstacle.x
	var base_y: float = waterline_y + 22.0
	var top_y: float = base_y - obstacle.height
	var mid_x: float = x + obstacle.width * 0.48
	var right_x: float = x + obstacle.width
	var fill: Color = Color(0.95, 0.98, 1.0, 0.95)
	var shade: Color = Color(0.62, 0.82, 0.96, 0.88)
	var ink: Color = Color(0.03, 0.04, 0.04, 0.92)
	if obstacle.hit:
		fill = Color(1.0, 0.9, 0.9, 0.95)
		shade = Color(0.9, 0.55, 0.55, 0.88)

	var points := PackedVector2Array([
		Vector2(x, base_y),
		Vector2(x + obstacle.width * 0.18, base_y - obstacle.height * 0.36),
		Vector2(mid_x, top_y),
		Vector2(x + obstacle.width * 0.72, base_y - obstacle.height * 0.42),
		Vector2(right_x, base_y),
	])
	draw_polygon(points, PackedColorArray([fill, fill, fill, fill, fill]))
	draw_polygon(PackedVector2Array([
		Vector2(mid_x, top_y + 8.0),
		Vector2(x + obstacle.width * 0.72, base_y - obstacle.height * 0.42),
		Vector2(right_x, base_y),
		Vector2(x + obstacle.width * 0.54, base_y - 8.0)
	]), PackedColorArray([shade, shade, shade, shade]))
	draw_polyline(points, ink, 3.0, true)
	draw_line(Vector2(mid_x, top_y + 8.0), Vector2(x + obstacle.width * 0.54, base_y - 8.0), ink, 2.0)
	draw_line(Vector2(x + 10.0, base_y + 10.0), Vector2(right_x - 6.0, base_y + 4.0), Color(0.03, 0.04, 0.04, 0.24), 2.0)


func _draw_floating_barrier(obstacle: Obstacle) -> void:
	var x: float = obstacle.x
	var y: float = waterline_y + 18.0
	var width: float = obstacle.width
	var height: float = obstacle.height
	var fill: Color = Color(0.96, 0.92, 0.76, 0.96)
	var ink: Color = Color(0.03, 0.035, 0.035, 0.94)
	if obstacle.hit:
		fill = Color(0.96, 0.62, 0.55, 0.96)

	draw_rect(Rect2(Vector2(x, y - height * 0.48), Vector2(width, height * 0.56)), fill, true)
	draw_rect(Rect2(Vector2(x, y - height * 0.48), Vector2(width, height * 0.56)), ink, false, 3.0)
	draw_line(Vector2(x + 8.0, y - height * 0.2), Vector2(x + width - 8.0, y - height * 0.24), ink, 2.0)
	draw_circle(Vector2(x + width * 0.24, y + 8.0), 8.0, Color(0.9, 0.96, 1.0, 0.72))
	draw_circle(Vector2(x + width * 0.7, y + 6.0), 6.0, Color(0.9, 0.96, 1.0, 0.68))

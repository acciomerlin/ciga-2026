extends Node2D

const STATE_NORMAL := 0
const STATE_CRISIS := 1
const STATE_SUCCESS := 2
const STATE_FAIL := 3
const STATE_GAME_OVER := 4

const TEX_NORMAL: Texture2D = preload("res://assets/ship/generated_states/cruise-state-normal-alpha.png")
const TEX_SICK: Texture2D = preload("res://assets/ship/generated_states/cruise-state-sick-alpha.png")
const TEX_SUCCESS: Texture2D = preload("res://assets/ship/generated_states/cruise-state-success-alpha.png")
const TEX_FAIL: Texture2D = preload("res://assets/ship/generated_states/cruise-state-fail-alpha.png")
const UI_FONT: Font = preload("res://assets/fonts/NotoSansSC.ttf")
const HIGH_SCORE_PATH := "user://anchor_sickness_high_score.txt"

@export var ship_path: NodePath = NodePath("../PlayerShip")
@export var ship_sprite_path: NodePath = NodePath("../PlayerShip/ShipSprite")
@export var anchor_path: NodePath = NodePath("../AnchorSystem")
@export var ui_path: NodePath = NodePath("../UI")

@export_group("Sailing")
@export var sailing_speed: float = 128.0
@export var state_sprite_position := Vector2(250.0, -58.0)
@export var state_sprite_scale := Vector2(0.9, 0.9)

@export_group("Round")
@export var first_crisis_delay: float = 3.0
@export var min_crisis_delay: float = 4.2
@export var max_crisis_delay: float = 7.0
@export var crisis_time_limit: float = 5.0
@export var min_random_time_limit: float = 3.25
@export var max_random_time_limit: float = 6.2
@export var result_hold_time: float = 1.6
@export_range(0.0, 1.0, 0.01) var success_speed_ratio: float = 0.16

@export_group("Timing")
@export var timing_min_speed: float = 0.28
@export var timing_max_speed: float = 0.72
@export_range(0.04, 0.5, 0.01) var timing_min_target_width: float = 0.13
@export_range(0.05, 0.8, 0.01) var timing_max_target_width: float = 0.38
@export var failed_retract_delay: float = 0.12

@export_group("Difficulty")
@export var rounds_to_max_difficulty: float = 4.0
@export var timing_speed_random_increase_min: float = 0.01
@export var timing_speed_random_increase_max: float = 0.3
@export var next_passenger_shrink_per_round: float = 0.2
@export var hard_min_crisis_delay: float = 0.9
@export var hard_max_crisis_delay: float = 1.8
@export var hard_min_time_limit: float = 2.25
@export var hard_max_time_limit: float = 3.45
@export_range(0.04, 0.5, 0.01) var hard_target_width: float = 0.06

@export_group("Vomit")
@export var max_vomit_level: float = 4.0
@export var vomit_per_failure: float = 1.0
@export var vomit_blob_count_per_failure := 9
@export var vomit_blob_local_origin := Vector2(205.0, -24.0)
@export var vomit_blob_local_spread := Vector2(130.0, 42.0)

var _ship: Node2D
var _ship_sprite: Sprite2D
var _anchor: Node
var _ui_layer: CanvasLayer
var _hud_root: Control
var _status_label: Label
var _score_label: Label
var _vomit_label: Label
var _time_label: Label
var _game_over_panel: Control
var _game_over_label: Label
var _time_fill: ColorRect
var _timing_target_fill: ColorRect
var _timing_cursor_marker: ColorRect
var _vomit_fill: ColorRect
var _rng := RandomNumberGenerator.new()

var _state := STATE_NORMAL
var _score := 0
var _high_score := 0
var _round_index := 0
var _next_crisis_timer := 3.0
var _current_next_crisis_duration := 3.0
var _crisis_timer := 0.0
var _current_time_limit := 5.0
var _current_success_speed_ratio := 0.16
var _current_reward := 100
var _current_difficulty := 0.0
var _current_difficulty_level := 1
var _result_timer := 0.0
var _timing_value := 0.0
var _timing_direction := 1.0
var _timing_speed := 1.0
var _timing_speed_bonus := 0.0
var _timing_target_center := 0.5
var _timing_target_width := 0.28
var _anchor_missed := false
var _failed_retract_timer := 0.0
var _space_was_down := false
var _anchor_fired := false
var _vomit_level := 0.0
var _vomit_blobs: Array[Dictionary] = []
var _status_text := "航行中，观察舱室"


func _ready() -> void:
	_ship = get_node_or_null(ship_path) as Node2D
	_ship_sprite = get_node_or_null(ship_sprite_path) as Sprite2D
	_anchor = get_node_or_null(anchor_path)
	_ui_layer = get_node_or_null(ui_path) as CanvasLayer
	_rng.randomize()
	_load_high_score()
	_next_crisis_timer = first_crisis_delay
	_current_next_crisis_duration = first_crisis_delay
	_apply_state_texture(TEX_NORMAL)
	_ensure_hud()
	_set_ship_speed_ratio(1.0)
	_set_ship_cruise_speed(sailing_speed)


func _physics_process(delta: float) -> void:
	_handle_timing_input(delta)

	match _state:
		STATE_NORMAL:
			_update_normal(delta)
		STATE_CRISIS:
			_update_crisis(delta)
		STATE_SUCCESS, STATE_FAIL:
			_update_result(delta)
		STATE_GAME_OVER:
			_update_game_over()

	_update_hud()
	queue_redraw()


func _handle_timing_input(delta: float) -> void:
	var space_down: bool = Input.is_key_pressed(KEY_SPACE)
	if _state == STATE_CRISIS and not _anchor_fired:
		_update_timing_cursor(delta)
		if space_down and not _space_was_down:
			_attempt_anchor_timing()

	_space_was_down = space_down


func _update_timing_cursor(delta: float) -> void:
	_timing_value += _timing_direction * _timing_speed * delta
	if _timing_value > 1.0:
		_timing_value = 2.0 - _timing_value
		_timing_direction = -1.0
	elif _timing_value < 0.0:
		_timing_value = -_timing_value
		_timing_direction = 1.0


func _update_normal(delta: float) -> void:
	_next_crisis_timer -= delta
	if _next_crisis_timer <= 0.0:
		_start_crisis()


func _update_crisis(delta: float) -> void:
	if not _anchor_fired:
		_crisis_timer = maxf(0.0, _crisis_timer - delta)
	if _failed_retract_timer > 0.0:
		_failed_retract_timer = maxf(0.0, _failed_retract_timer - delta)
		if _failed_retract_timer <= 0.0 and _anchor != null and _anchor.has_method("retract_anchor"):
			_anchor.call("retract_anchor", true)
			_finish_round(false)
			return

	if _anchor_fired and not _anchor_missed and _get_ship_speed_ratio() <= _current_success_speed_ratio:
		_finish_round(true)
		return
	if _crisis_timer <= 0.0:
		_finish_round(false)


func _update_result(delta: float) -> void:
	_result_timer = maxf(0.0, _result_timer - delta)
	if _result_timer > 0.0:
		return
	_return_to_normal()


func _update_game_over() -> void:
	if Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER):
		_restart_game()


func _start_crisis() -> void:
	_state = STATE_CRISIS
	_round_index += 1
	_randomize_round()
	_crisis_timer = _current_time_limit
	_anchor_missed = false
	_failed_retract_timer = 0.0
	_anchor_fired = false
	_status_text = "有人要吐了：看准时机，Space 抛锚"
	_apply_state_texture(TEX_SICK)
	_set_ship_speed_ratio(1.0)


func _randomize_round() -> void:
	_timing_speed_bonus += _rng.randf_range(timing_speed_random_increase_min, timing_speed_random_increase_max)
	var round_pressure: float = clampf(float(_round_index - 1) / maxf(rounds_to_max_difficulty, 1.0), 0.0, 1.0)
	var vomit_pressure: float = clampf(_vomit_level / maxf(max_vomit_level, 1.0), 0.0, 1.0) * 0.18
	var score_pressure: float = clampf(float(_score) / 900.0, 0.0, 1.0) * 0.14
	_current_difficulty = clampf(round_pressure + vomit_pressure + score_pressure, 0.0, 1.0)
	_current_difficulty_level = clampi(int(floor(_current_difficulty * 5.0)) + 1, 1, 6)

	var time_min: float = lerpf(min_random_time_limit, hard_min_time_limit, _current_difficulty)
	var time_max: float = lerpf(max_random_time_limit, hard_max_time_limit, _current_difficulty)
	time_max = maxf(time_min + 0.32, time_max)
	_current_time_limit = _rng.randf_range(time_min, time_max)
	_current_success_speed_ratio = _rng.randf_range(
		clampf(success_speed_ratio - _current_difficulty * 0.07, 0.055, 0.24),
		clampf(success_speed_ratio + 0.05 - _current_difficulty * 0.045, 0.075, 0.28)
	)
	var easy_width_max: float = timing_max_target_width
	var easy_width_min: float = maxf(timing_min_target_width, timing_max_target_width * 0.72)
	var hard_width_max: float = maxf(hard_target_width * 1.45, hard_target_width + 0.035)
	var hard_width_min: float = hard_target_width
	var target_width_max: float = lerpf(easy_width_max, hard_width_max, _current_difficulty)
	var target_width_min: float = lerpf(easy_width_min, hard_width_min, _current_difficulty)
	_timing_target_width = _rng.randf_range(target_width_min, target_width_max)
	_timing_target_center = _rng.randf_range(_timing_target_width * 0.5, 1.0 - _timing_target_width * 0.5)
	_timing_speed = _rng.randf_range(timing_min_speed, timing_max_speed) + _timing_speed_bonus
	_timing_value = 0.0 if _rng.randf() < 0.5 else 1.0
	_timing_direction = 1.0 if _timing_value < 0.5 else -1.0
	_current_reward = int(round(70.0 + (1.0 - _timing_target_width) * 120.0 + _timing_speed * 26.0 + (max_random_time_limit - _current_time_limit) * 18.0 + _current_difficulty * 75.0))


func _attempt_anchor_timing() -> void:
	if _anchor_fired:
		return

	var half_width: float = _timing_target_width * 0.5
	var distance: float = absf(_timing_value - _timing_target_center)
	var hit: bool = distance <= half_width
	var accuracy: float = 0.0
	if half_width > 0.001:
		accuracy = clampf(1.0 - distance / half_width, 0.0, 1.0)

	_anchor_fired = true
	_anchor_missed = not hit

	if _anchor != null and _anchor.has_method("launch_anchor"):
		if hit:
			var launch_power: float = lerpf(0.72, 1.0, accuracy)
			_status_text = "命中时机，锚已抛出，等船速降下来"
			_anchor.call("launch_anchor", launch_power)
		else:
			_status_text = "时机没踩准，锚打滑并被拽回"
			_anchor.call("launch_anchor", 0.22)
			_failed_retract_timer = failed_retract_delay


func _finish_round(success: bool) -> void:
	if success:
		_state = STATE_SUCCESS
		_score += _current_reward
		_status_text = "稳住了，乘客恢复正常 +%d" % _current_reward
		_apply_state_texture(TEX_SUCCESS)
	else:
		_state = STATE_FAIL
		_add_vomit_failure()
		if _vomit_level >= max_vomit_level:
			_game_over()
			return
		_status_text = "没来得及停船，呕吐物堆积 %.0f/%.0f" % [_vomit_level, max_vomit_level]
		_apply_state_texture(TEX_FAIL)
	_result_timer = result_hold_time


func _return_to_normal() -> void:
	_state = STATE_NORMAL
	_anchor_missed = false
	_failed_retract_timer = 0.0
	_anchor_fired = false
	_status_text = "航行中，观察舱室"
	_schedule_next_crisis()
	_apply_state_texture(TEX_NORMAL)
	if _anchor != null and _anchor.has_method("retract_anchor"):
		_anchor.call("retract_anchor", false)
	_set_ship_speed_ratio(1.0)


func _add_vomit_failure() -> void:
	_vomit_level = minf(max_vomit_level, _vomit_level + vomit_per_failure)
	for i in range(vomit_blob_count_per_failure):
		_vomit_blobs.append({
			"offset": vomit_blob_local_origin + Vector2(
				_rng.randf_range(-vomit_blob_local_spread.x, vomit_blob_local_spread.x),
				_rng.randf_range(-vomit_blob_local_spread.y, vomit_blob_local_spread.y)
			),
			"radius": _rng.randf_range(4.0, 12.0),
			"alpha": _rng.randf_range(0.62, 0.92)
		})


func _game_over() -> void:
	_state = STATE_GAME_OVER
	_result_timer = 0.0
	_anchor_fired = false
	_status_text = "呕吐物堆满了，游戏结束。按 Enter 重开"
	_apply_state_texture(TEX_FAIL)
	if _score > _high_score:
		_high_score = _score
		_save_high_score()
	if _anchor != null and _anchor.has_method("retract_anchor"):
		_anchor.call("retract_anchor", false)
	_set_ship_speed_ratio(0.0)
	_set_ship_cruise_speed(0.0)
	_update_game_over_panel()


func _restart_game() -> void:
	_state = STATE_NORMAL
	_score = 0
	_round_index = 0
	_vomit_level = 0.0
	_vomit_blobs.clear()
	_timing_speed_bonus = 0.0
	_anchor_missed = false
	_failed_retract_timer = 0.0
	_anchor_fired = false
	_status_text = "航行中，观察舱室"
	_next_crisis_timer = first_crisis_delay
	_current_next_crisis_duration = first_crisis_delay
	_apply_state_texture(TEX_NORMAL)
	if _anchor != null and _anchor.has_method("retract_anchor"):
		_anchor.call("retract_anchor", false)
	_set_ship_cruise_speed(sailing_speed)
	_set_ship_speed_ratio(1.0)


func _apply_state_texture(texture: Texture2D) -> void:
	if _ship_sprite == null:
		return
	_ship_sprite.texture = texture
	_ship_sprite.position = state_sprite_position
	_ship_sprite.scale = state_sprite_scale


func _set_ship_cruise_speed(value: float) -> void:
	if _ship != null and _ship.has_method("set_cruise_speed"):
		_ship.call("set_cruise_speed", value)


func _set_ship_speed_ratio(value: float) -> void:
	if _ship != null and _ship.has_method("set_speed_ratio"):
		_ship.call("set_speed_ratio", value)


func _get_ship_speed_ratio() -> float:
	if _ship != null and _ship.has_method("get_speed_ratio"):
		var value: Variant = _ship.call("get_speed_ratio")
		if value != null:
			return float(value)
	return 1.0


func _schedule_next_crisis() -> void:
	var delay_difficulty: float = clampf(float(_round_index) / maxf(rounds_to_max_difficulty, 1.0), 0.0, 1.0)
	var next_min_delay: float = lerpf(min_crisis_delay, hard_min_crisis_delay, delay_difficulty)
	var next_max_delay: float = lerpf(max_crisis_delay, hard_max_crisis_delay, delay_difficulty)
	var round_shrink: float = maxf(0.0, float(_round_index - 1)) * next_passenger_shrink_per_round
	next_min_delay = maxf(hard_min_crisis_delay, next_min_delay - round_shrink)
	next_max_delay = maxf(hard_max_crisis_delay, next_max_delay - round_shrink)
	next_max_delay = maxf(next_min_delay + 0.25, next_max_delay)
	_current_next_crisis_duration = _rng.randf_range(next_min_delay, next_max_delay)
	_next_crisis_timer = _current_next_crisis_duration


func _load_high_score() -> void:
	if not FileAccess.file_exists(HIGH_SCORE_PATH):
		_high_score = 0
		return
	var file: FileAccess = FileAccess.open(HIGH_SCORE_PATH, FileAccess.READ)
	if file == null:
		_high_score = 0
		return
	_high_score = int(file.get_as_text().strip_edges())


func _save_high_score() -> void:
	var file: FileAccess = FileAccess.open(HIGH_SCORE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(str(_high_score))


func _ensure_hud() -> void:
	if _ui_layer == null or _hud_root != null:
		return

	_hud_root = Control.new()
	_hud_root.name = "SicknessHUD"
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_hud_root)

	_score_label = Label.new()
	_score_label.position = Vector2(18.0, 14.0)
	_score_label.size = Vector2(500.0, 28.0)
	_apply_label_style(_score_label, 20)
	_hud_root.add_child(_score_label)

	_status_label = Label.new()
	_status_label.position = Vector2(18.0, 44.0)
	_status_label.size = Vector2(650.0, 32.0)
	_apply_label_style(_status_label, 18)
	_hud_root.add_child(_status_label)

	_time_label = Label.new()
	_time_label.position = Vector2(390.0, 80.0)
	_time_label.size = Vector2(310.0, 26.0)
	_apply_label_style(_time_label, 16)
	_hud_root.add_child(_time_label)

	var time_bg := ColorRect.new()
	time_bg.position = Vector2(18.0, 86.0)
	time_bg.size = Vector2(360.0, 18.0)
	time_bg.color = Color(0.02, 0.02, 0.02, 0.22)
	_hud_root.add_child(time_bg)

	_time_fill = ColorRect.new()
	_time_fill.position = time_bg.position
	_time_fill.size = time_bg.size
	_time_fill.color = Color(0.9, 0.14, 0.12, 0.86)
	_hud_root.add_child(_time_fill)

	var timing_bg := ColorRect.new()
	timing_bg.position = Vector2(18.0, 112.0)
	timing_bg.size = Vector2(360.0, 18.0)
	timing_bg.color = Color(0.02, 0.02, 0.02, 0.22)
	_hud_root.add_child(timing_bg)

	_timing_target_fill = ColorRect.new()
	_timing_target_fill.position = timing_bg.position
	_timing_target_fill.size = Vector2.ZERO
	_timing_target_fill.color = Color(0.18, 0.74, 0.28, 0.86)
	_hud_root.add_child(_timing_target_fill)

	_timing_cursor_marker = ColorRect.new()
	_timing_cursor_marker.position = timing_bg.position
	_timing_cursor_marker.size = Vector2(5.0, 26.0)
	_timing_cursor_marker.color = Color(0.02, 0.02, 0.02, 0.92)
	_hud_root.add_child(_timing_cursor_marker)

	var vomit_bg := ColorRect.new()
	vomit_bg.position = Vector2(18.0, 138.0)
	vomit_bg.size = Vector2(360.0, 18.0)
	vomit_bg.color = Color(0.02, 0.02, 0.02, 0.22)
	_hud_root.add_child(vomit_bg)

	_vomit_fill = ColorRect.new()
	_vomit_fill.position = vomit_bg.position
	_vomit_fill.size = Vector2.ZERO
	_vomit_fill.color = Color(0.18, 0.66, 0.2, 0.86)
	_hud_root.add_child(_vomit_fill)

	_vomit_label = Label.new()
	_vomit_label.position = Vector2(390.0, 132.0)
	_vomit_label.size = Vector2(260.0, 26.0)
	_apply_label_style(_vomit_label, 16)
	_hud_root.add_child(_vomit_label)

	_game_over_panel = Control.new()
	_game_over_panel.name = "GameOverPanel"
	_game_over_panel.position = Vector2(392.0, 204.0)
	_game_over_panel.size = Vector2(496.0, 220.0)
	_game_over_panel.visible = false
	_hud_root.add_child(_game_over_panel)

	var panel_bg := ColorRect.new()
	panel_bg.position = Vector2.ZERO
	panel_bg.size = _game_over_panel.size
	panel_bg.color = Color(1.0, 1.0, 1.0, 0.86)
	_game_over_panel.add_child(panel_bg)

	var panel_line := ColorRect.new()
	panel_line.position = Vector2.ZERO
	panel_line.size = Vector2(_game_over_panel.size.x, 6.0)
	panel_line.color = Color(0.02, 0.02, 0.02, 0.95)
	_game_over_panel.add_child(panel_line)

	_game_over_label = Label.new()
	_game_over_label.position = Vector2(28.0, 24.0)
	_game_over_label.size = Vector2(440.0, 172.0)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_label_style(_game_over_label, 24)
	_game_over_panel.add_child(_game_over_label)


func _apply_label_style(label: Label, font_size: int) -> void:
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.02, 0.02, 0.02, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)


func _update_hud() -> void:
	if _score_label == null or _status_label == null:
		return

	_score_label.text = "分数 %d  最高分 %d  第 %d 位乘客" % [_score, _high_score, _round_index + 1]
	_status_label.text = _status_text

	if _time_fill != null:
		var time_ratio: float = 0.0
		if _state == STATE_CRISIS:
			time_ratio = clampf(_crisis_timer / maxf(_current_time_limit, 0.01), 0.0, 1.0)
			_time_fill.color = Color(0.9, 0.14, 0.12, 0.86)
		elif _state == STATE_NORMAL:
			time_ratio = clampf(_next_crisis_timer / maxf(_current_next_crisis_duration, 0.01), 0.0, 1.0)
			_time_fill.color = Color(0.12, 0.45, 0.95, 0.78)
		_time_fill.size = Vector2(360.0 * time_ratio, 18.0)
		_time_fill.visible = _state == STATE_CRISIS or _state == STATE_NORMAL

	if _time_label != null:
		if _state == STATE_CRISIS:
			if _anchor_fired:
				_time_label.text = "抛锚中，时间暂停 %.1fs" % _crisis_timer
			else:
				_time_label.text = "救援倒计时 %.1fs" % _crisis_timer
			_time_label.visible = true
		elif _state == STATE_NORMAL:
			_time_label.text = "下一位乘客 %.1fs" % _next_crisis_timer
			_time_label.visible = true
		else:
			_time_label.visible = false

	if _timing_target_fill != null:
		var target_left: float = _timing_target_center - _timing_target_width * 0.5
		_timing_target_fill.position = Vector2(18.0 + 360.0 * target_left, 112.0)
		_timing_target_fill.size = Vector2(360.0 * _timing_target_width, 18.0)
		_timing_target_fill.visible = _state == STATE_CRISIS and not _anchor_fired

	if _timing_cursor_marker != null:
		_timing_cursor_marker.position = Vector2(18.0 + 360.0 * _timing_value - 2.5, 108.0)
		_timing_cursor_marker.visible = _state == STATE_CRISIS and not _anchor_fired

	if _vomit_fill != null:
		var vomit_ratio: float = clampf(_vomit_level / maxf(max_vomit_level, 1.0), 0.0, 1.0)
		_vomit_fill.size = Vector2(360.0 * vomit_ratio, 18.0)

	if _vomit_label != null:
		_vomit_label.text = "呕吐物 %.0f / %.0f" % [_vomit_level, max_vomit_level]

	if _game_over_panel != null:
		_game_over_panel.visible = _state == STATE_GAME_OVER
		if _state == STATE_GAME_OVER:
			_update_game_over_panel()


func _update_game_over_panel() -> void:
	if _game_over_label == null:
		return
	_game_over_label.text = "GAME OVER\n本局分数 %d\n最高分 %d\n呕吐物已满\n按 Enter 重试" % [_score, _high_score]


func _draw() -> void:
	if _ship_sprite == null or _vomit_blobs.is_empty():
		return
	for blob in _vomit_blobs:
		var offset: Vector2 = blob["offset"] as Vector2
		var radius: float = float(blob["radius"])
		var alpha: float = float(blob["alpha"])
		var world_position: Vector2 = _ship_sprite.global_transform * offset
		var local_position: Vector2 = to_local(world_position)
		draw_circle(local_position, radius * _ship_sprite.global_scale.x, Color(0.18, 0.62, 0.16, alpha))
		draw_arc(local_position, radius * _ship_sprite.global_scale.x, 0.0, TAU, 18, Color(0.02, 0.03, 0.02, alpha * 0.72), 1.5)

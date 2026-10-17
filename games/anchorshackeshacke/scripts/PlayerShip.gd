extends Node2D

@export var cruise_speed: float = 120.0
@export var current_speed: float = 120.0

@export_group("Visual Motion")
@export var ship_visual_path: NodePath = NodePath("ShipSprite")
@export var wave_bob_amplitude: float = 4.4
@export var wave_sway_amplitude: float = 2.2
@export var wave_roll_amplitude: float = 0.012
@export var anchor_pull_pixels: float = 34.0
@export var anchor_pitch_radians: float = 0.055
@export var feedback_spring: float = 62.0
@export var feedback_damping: float = 13.5

@export_group("Runner")
@export var jump_gravity: float = 980.0
@export var max_jump_height: float = 168.0
@export var retract_jump_velocity: float = 460.0
@export var retract_jump_forward_velocity: float = 230.0
@export var jump_forward_spring: float = 3.2
@export var jump_forward_damping: float = 4.8
@export var jump_rotation_radians: float = 0.078
@export var hit_slowdown_ratio: float = 0.42

var elapsed: float = 0.0

var _visual: Node2D
var _visual_base_position: Vector2 = Vector2.ZERO
var _visual_base_rotation: float = 0.0
var _visual_offset: Vector2 = Vector2.ZERO
var _visual_velocity: Vector2 = Vector2.ZERO
var _visual_rotation_offset: float = 0.0
var _visual_rotation_velocity: float = 0.0
var _feedback_tension: float = 0.0
var _feedback_tension_target: float = 0.0
var _feedback_brake: float = 0.0
var _feedback_brake_target: float = 0.0
var _feedback_shock: float = 0.0
var _feedback_locked: bool = false
var _last_speed_ratio: float = 1.0
var _jump_height: float = 0.0
var _jump_velocity: float = 0.0
var _jump_forward_offset: float = 0.0
var _jump_forward_velocity: float = 0.0
var _runner_hit_cooldown: float = 0.0


func _ready() -> void:
	_visual = get_node_or_null(ship_visual_path) as Node2D
	if _visual != null:
		_visual_base_position = _visual.position
		_visual_base_rotation = _visual.rotation


func _physics_process(delta: float) -> void:
	elapsed += delta
	position.x += current_speed * delta
	_update_runner_jump(delta)
	_update_visual_motion(delta)


func set_speed_ratio(ratio: float) -> void:
	var clamped_ratio: float = clampf(ratio, 0.0, 1.0)
	var speed_drop: float = maxf(0.0, _last_speed_ratio - clamped_ratio)
	if speed_drop > 0.035:
		_feedback_shock = maxf(_feedback_shock, speed_drop * 1.6)
	_last_speed_ratio = clamped_ratio
	current_speed = cruise_speed * clamped_ratio


func set_cruise_speed(value: float) -> void:
	cruise_speed = maxf(0.0, value)
	current_speed = cruise_speed * _last_speed_ratio


func get_current_speed() -> float:
	return current_speed


func get_speed_ratio() -> float:
	if cruise_speed <= 0.01:
		return 0.0
	return clampf(current_speed / cruise_speed, 0.0, 1.0)


func get_runner_front_x() -> float:
	return global_position.x + 565.0


func get_runner_clearance() -> float:
	return _jump_height


func is_runner_airborne() -> bool:
	return _jump_height > 2.0 or _jump_velocity > 1.0


func apply_anchor_retract_boost(strength: float) -> void:
	var clamped_strength: float = clampf(strength, 0.0, 1.4)
	_jump_velocity = maxf(_jump_velocity, retract_jump_velocity * (0.72 + clamped_strength * 0.42))
	_jump_forward_velocity = maxf(_jump_forward_velocity, retract_jump_forward_velocity * (0.72 + clamped_strength * 0.35))
	_feedback_shock = maxf(_feedback_shock, 0.45 + clamped_strength * 0.42)
	_feedback_tension_target = maxf(_feedback_tension_target, 0.55)


func register_runner_hit(strength: float) -> void:
	if _runner_hit_cooldown > 0.0:
		return
	var clamped_strength: float = clampf(strength, 0.0, 1.0)
	_runner_hit_cooldown = 0.7
	_feedback_shock = maxf(_feedback_shock, 0.7 + clamped_strength * 0.3)
	_feedback_brake_target = maxf(_feedback_brake_target, 0.6 + clamped_strength * 0.3)
	_last_speed_ratio = minf(_last_speed_ratio, hit_slowdown_ratio)
	current_speed = cruise_speed * _last_speed_ratio


func apply_anchor_feedback(tension: float, shock: float, brake: float, locked: bool) -> void:
	_feedback_tension_target = clampf(tension, 0.0, 1.0)
	_feedback_brake_target = clampf(brake, 0.0, 1.0)
	_feedback_shock = maxf(_feedback_shock, clampf(shock, 0.0, 1.0))
	_feedback_locked = locked
	if is_inside_tree():
		get_tree().call_group("breakable_object", "apply_ship_impact", tension, shock, brake, locked)


func get_visual_mount_global(local_position: Vector2) -> Vector2:
	return to_global(_apply_visual_transform(local_position))


func get_visual_rotation_offset() -> float:
	return _visual_rotation_offset


func get_visual_pivot_local() -> Vector2:
	return _visual_base_position


func get_visual_offset_local() -> Vector2:
	return _visual_offset


func _update_visual_motion(delta: float) -> void:
	if _visual == null:
		return

	_feedback_tension = lerpf(_feedback_tension, _feedback_tension_target, minf(delta * 8.0, 1.0))
	_feedback_brake = lerpf(_feedback_brake, _feedback_brake_target, minf(delta * 6.0, 1.0))
	_feedback_tension_target = maxf(0.0, _feedback_tension_target - delta * 1.2)
	_feedback_brake_target = maxf(0.0, _feedback_brake_target - delta * 1.0)
	_feedback_shock = maxf(0.0, _feedback_shock - delta * (1.2 if _feedback_locked else 2.4))

	var speed_ratio: float = 0.0
	if cruise_speed > 0.01:
		speed_ratio = clampf(current_speed / cruise_speed, 0.0, 1.0)

	var water_energy: float = 0.42 + speed_ratio * 0.58
	var wave_offset: Vector2 = Vector2(
		sin(elapsed * 0.78 + 0.4) * wave_sway_amplitude * water_energy,
		sin(elapsed * 1.36) * wave_bob_amplitude * water_energy + sin(elapsed * 2.15 + 1.7) * wave_bob_amplitude * 0.18
	)
	var wave_rotation: float = sin(elapsed * 0.92 + 0.8) * wave_roll_amplitude * water_energy

	var pull_strength: float = clampf(_feedback_tension * 0.78 + _feedback_brake * 0.52 + _feedback_shock * 0.38, 0.0, 1.35)
	var feedback_offset: Vector2 = Vector2(
		-anchor_pull_pixels * pull_strength,
		sin(elapsed * 7.0) * _feedback_shock * 8.0 + _feedback_tension * 4.5
	)
	var feedback_rotation: float = -anchor_pitch_radians * clampf(_feedback_tension + _feedback_brake * 0.55, 0.0, 1.0)
	feedback_rotation += sin(elapsed * 10.8) * _feedback_shock * 0.035

	var jump_offset := Vector2(_jump_forward_offset, -_jump_height)
	var target_offset: Vector2 = wave_offset + feedback_offset + jump_offset
	var target_rotation: float = wave_rotation + feedback_rotation
	target_rotation += clampf(_jump_velocity / maxf(retract_jump_velocity, 1.0), -1.0, 1.0) * jump_rotation_radians

	_visual_velocity += (target_offset - _visual_offset) * feedback_spring * delta
	_visual_velocity *= exp(-feedback_damping * delta)
	_visual_offset += _visual_velocity * delta

	_visual_rotation_velocity += (target_rotation - _visual_rotation_offset) * feedback_spring * delta
	_visual_rotation_velocity *= exp(-feedback_damping * delta)
	_visual_rotation_offset += _visual_rotation_velocity * delta

	_visual.position = _visual_base_position + _visual_offset
	_visual.rotation = _visual_base_rotation + _visual_rotation_offset


func _update_runner_jump(delta: float) -> void:
	_runner_hit_cooldown = maxf(0.0, _runner_hit_cooldown - delta)

	if absf(_jump_forward_offset) > 0.01 or absf(_jump_forward_velocity) > 0.01:
		_jump_forward_velocity += -_jump_forward_offset * jump_forward_spring * delta
		_jump_forward_velocity *= exp(-jump_forward_damping * delta)
		_jump_forward_offset += _jump_forward_velocity * delta
	else:
		_jump_forward_offset = 0.0
		_jump_forward_velocity = 0.0

	if _jump_height <= 0.0 and _jump_velocity <= 0.0:
		_jump_height = 0.0
		_jump_velocity = 0.0
		return

	_jump_height += _jump_velocity * delta
	_jump_velocity -= jump_gravity * delta
	if _jump_height > max_jump_height:
		_jump_height = max_jump_height
		_jump_velocity = minf(_jump_velocity, 0.0)
	if _jump_height <= 0.0:
		_jump_height = 0.0
		_jump_velocity = 0.0
		_feedback_shock = maxf(_feedback_shock, 0.32)


func _apply_visual_transform(local_position: Vector2) -> Vector2:
	var pivot: Vector2 = _visual_base_position
	if _visual == null:
		return local_position
	return pivot + (local_position - pivot).rotated(_visual_rotation_offset) + _visual_offset

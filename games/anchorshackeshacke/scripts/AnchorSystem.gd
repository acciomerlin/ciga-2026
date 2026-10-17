extends Node2D

const STATE_STOWED := 0
const STATE_DROPPING := 1
const STATE_DRAGGING := 2
const STATE_LOCKED := 3
const DROP_SEQUENCE: Array[String] = ["a", "w", "d", "s"]
const RETRACT_SEQUENCE: Array[String] = ["d", "w", "a", "s"]
const CHAIN_LINK_TEXTURE: Texture2D = preload("res://assets/anchor/chain-link.png")
const ANCHOR_TEXTURE: Texture2D = preload("res://assets/anchor/toy-anchor.png")
const WINCH_VISUAL_SCRIPT: Script = preload("res://scripts/WinchVisual.gd")

@export var ship_path: NodePath = NodePath("../PlayerShip")
@export var sand_layer_path: NodePath = NodePath("../SandLayer")
@export var direct_keyboard_control := false

@export_group("Mount")
@export var winch_local_position := Vector2(-54.0, -148.0)
@export var chain_exit_offset := Vector2(-18.0, 21.0)
@export var stowed_anchor_offset := Vector2(-26.0, 92.0)
@export var anchor_ring_local_offset := Vector2(0.0, -33.0)

@export_group("Chain")
@export var chain_payout_speed := 390.0
@export var max_chain_length := 760.0
@export var chain_link_spacing := 17.0

@export_group("Physics Chain")
@export var use_physics_chain := false
@export_range(8, 42, 1) var physics_link_count := 28
@export var link_texture_scale := 0.032
@export var anchor_texture_scale := 0.083
@export var link_collision_radius := 3.4
@export var link_collision_length := 24.0
@export var link_bar_offset := 5.2
@export var link_gravity_scale := 0.18
@export var link_linear_damp := 2.4
@export var link_angular_damp := 3.0

@export_group("Anchor Physics")
@export var gravity := 780.0
@export var water_drag := 0.26
@export var sand_probe_radius := 46.0
@export var lock_embed_threshold := 0.92
@export var stop_rate := 0.9

@export_group("Runner Controls")
@export var sequence_timeout := 0.86
@export var payout_sequence_bonus := 74.0
@export var retract_sequence_amount := 118.0
@export var retract_jump_strength := 1.0

var _ship: Node2D
var _sand_layer: Node
var _state := STATE_STOWED
var _anchor_position := Vector2.ZERO
var _anchor_velocity := Vector2.ZERO
var _paid_chain_length := 130.0
var _locked_chain_length := 130.0
var _embed_depth := 0.0
var _friction := 0.0
var _lock_strength := 0.0
var _chain_tension := 0.0
var _stop_progress := 0.0
var _shock := 0.0
var _space_was_down := false
var _r_was_down := false
var _puffs: Array[Dictionary] = []
var _gouges: Array[Dictionary] = []
var _gouge_cooldown := 0.0
var _winch_body: StaticBody2D
var _winch_visual: Node2D
var _anchor_body: StaticBody2D
var _anchor_sprite: Sprite2D
var _anchor_connector_line: Line2D
var _anchor_coupler_sprite: Sprite2D
var _chain_links: Array[RigidBody2D] = []
var _chain_joints: Array[PinJoint2D] = []
var _physics_chain_active := false
var _physics_chain_link_count := 0
var _w_was_down := false
var _a_was_down := false
var _s_was_down := false
var _d_was_down := false
var _drop_sequence_index := 0
var _retract_sequence_index := 0
var _sequence_elapsed := 0.0
var _control_flash := ""
var _control_flash_time := 0.0
var _launch_power := 0.0


func _ready() -> void:
	_ship = get_node_or_null(ship_path) as Node2D
	_sand_layer = get_node_or_null(sand_layer_path)
	z_index = 65
	_anchor_position = _get_stowed_anchor_position()
	_ensure_asset_bodies()
	_sync_asset_bodies()


func _physics_process(delta: float) -> void:
	if direct_keyboard_control:
		_handle_input()
	_update_anchor(delta)
	_sync_asset_bodies()
	_update_particles(delta)
	queue_redraw()


func _handle_input() -> void:
	var space_down := Input.is_key_pressed(KEY_SPACE)
	if space_down and not _space_was_down:
		if _state == STATE_STOWED:
			_drop_anchor()
	_space_was_down = space_down

	var r_down := Input.is_key_pressed(KEY_R)
	if r_down and not _r_was_down:
		_command_retract()
	_r_was_down = r_down


func _consume_key_edge(key: Key, letter: String) -> void:
	var is_down: bool = Input.is_key_pressed(key)
	var was_down: bool = false
	match letter:
		"w":
			was_down = _w_was_down
			_w_was_down = is_down
		"a":
			was_down = _a_was_down
			_a_was_down = is_down
		"s":
			was_down = _s_was_down
			_s_was_down = is_down
		"d":
			was_down = _d_was_down
			_d_was_down = is_down

	if is_down and not was_down:
		_accept_sequence_key(letter)


func _accept_sequence_key(letter: String) -> void:
	_sequence_elapsed = 0.0
	_drop_sequence_index = _advance_sequence(DROP_SEQUENCE, _drop_sequence_index, letter)
	_retract_sequence_index = _advance_sequence(RETRACT_SEQUENCE, _retract_sequence_index, letter)

	if _drop_sequence_index >= DROP_SEQUENCE.size():
		_drop_sequence_index = 0
		_retract_sequence_index = 0
		_command_payout()
		return

	if _retract_sequence_index >= RETRACT_SEQUENCE.size():
		_drop_sequence_index = 0
		_retract_sequence_index = 0
		_command_retract()


func _advance_sequence(sequence: Array[String], index: int, letter: String) -> int:
	var next_index: int = index
	if letter == sequence[next_index]:
		next_index += 1
	else:
		next_index = 1 if letter == sequence[0] else 0
	return next_index


func _command_payout() -> void:
	_control_flash = "SPACE 抛锚"
	_control_flash_time = 0.42
	if _state == STATE_STOWED:
		_drop_anchor()
		return
	if _state == STATE_DROPPING or _state == STATE_DRAGGING:
		_paid_chain_length = minf(max_chain_length, _paid_chain_length + payout_sequence_bonus)
		_anchor_velocity += Vector2(-42.0, 76.0)
		_shock = maxf(_shock, 0.18)


func _command_retract() -> void:
	_control_flash = "R 收锚跳"
	_control_flash_time = 0.42
	if _state == STATE_STOWED:
		return

	var boost_strength: float = retract_jump_strength
	if _state == STATE_LOCKED:
		boost_strength += _lock_strength * 0.55 + _chain_tension * 0.45
		_add_sand_puff(_get_anchor_bite_point(), 0.82)
	elif _state == STATE_DRAGGING:
		boost_strength *= 0.78
		_add_sand_puff(_get_anchor_bite_point(), 0.46)
	else:
		boost_strength *= 0.54

	_request_ship_retract_boost(boost_strength)
	_reset_anchor()


func launch_anchor(power: float = 1.0) -> void:
	if _state != STATE_STOWED:
		return
	_drop_anchor(clampf(power, 0.0, 1.0))


func retract_anchor(apply_jump_boost := false) -> void:
	if apply_jump_boost:
		_command_retract()
	else:
		_reset_anchor()


func is_anchor_active() -> bool:
	return _state != STATE_STOWED


func _drop_anchor(power: float = 0.55) -> void:
	_state = STATE_DROPPING
	_launch_power = clampf(power, 0.0, 1.0)
	_anchor_position = _get_stowed_anchor_position()
	_anchor_velocity = Vector2(-22.0 - _launch_power * 92.0, 58.0 + _launch_power * 285.0)
	_paid_chain_length = 135.0
	_locked_chain_length = _paid_chain_length
	_embed_depth = 0.0
	_friction = 0.0
	_lock_strength = 0.0
	_chain_tension = 0.0
	_stop_progress = 0.0
	_shock = 0.0
	if use_physics_chain:
		_rebuild_physics_chain()


func _reset_anchor() -> void:
	_state = STATE_STOWED
	_anchor_position = _get_stowed_anchor_position()
	_anchor_velocity = Vector2.ZERO
	_paid_chain_length = 130.0
	_locked_chain_length = 130.0
	_embed_depth = 0.0
	_friction = 0.0
	_lock_strength = 0.0
	_chain_tension = 0.0
	_stop_progress = 0.0
	_shock = 0.0
	_launch_power = 0.0
	_clear_physics_chain()
	_set_ship_speed_ratio(1.0)
	_apply_ship_feedback(0.0, 0.0, 0.0, false)


func _update_anchor(delta: float) -> void:
	if _ship == null:
		return

	match _state:
		STATE_STOWED:
			_anchor_position = _get_stowed_anchor_position()
			_anchor_velocity = Vector2.ZERO
			_chain_tension = 0.0
			_set_ship_speed_ratio(1.0)
			_apply_ship_feedback(0.0, 0.0, 0.0, false)
		STATE_DROPPING, STATE_DRAGGING:
			_update_falling_anchor(delta)
		STATE_LOCKED:
			_update_locked_anchor(delta)

	_shock = maxf(0.0, _shock - delta * 2.2)


func _update_falling_anchor(delta: float) -> void:
	var power_speed: float = 0.74 + _launch_power * 0.74
	_paid_chain_length = minf(max_chain_length, _paid_chain_length + chain_payout_speed * power_speed * delta)
	_anchor_velocity.y += gravity * delta
	_anchor_velocity *= pow(1.0 - water_drag, delta)
	var brake_feedback: float = 0.0

	var sample_point := _get_anchor_bite_point()
	var speed_factor := clampf(_anchor_velocity.length() / 720.0, 0.0, 1.0)
	var sample: Dictionary = _sample_sand(sample_point, speed_factor)
	var resistance: float = float(sample.get("value", 0.0))
	var contacts: int = int(sample.get("contacts", 0))
	var depth: float = float(sample.get("depth", 0.0))

	if resistance > 0.02:
		_state = STATE_DRAGGING
		_friction = lerpf(_friction, resistance, minf(delta * 10.0, 1.0))
		_embed_depth = clampf(
			_embed_depth + delta * (0.16 + resistance * (0.72 + _launch_power * 0.62) + depth * 0.55 + speed_factor * 0.3),
			0.0,
			1.0
		)
		_anchor_velocity *= maxf(0.04, 1.0 - delta * (2.8 + resistance * 7.2 + _embed_depth * 3.6))
		_anchor_velocity.y = maxf(_anchor_velocity.y - resistance * delta * 420.0, 12.0)
		_maybe_stamp_sand(sample_point, resistance, contacts)

		var ship_ratio := clampf(1.0 - (_friction * (0.18 + _launch_power * 0.1) + _embed_depth * (0.14 + _launch_power * 0.08)), 0.42, 1.0)
		_set_ship_speed_ratio(ship_ratio)
		brake_feedback = clampf(_friction * 0.46 + _embed_depth * 0.34 + _chain_tension * 0.28, 0.0, 1.0)

		if _embed_depth >= lock_embed_threshold or depth > 0.86:
			_lock_anchor()
	else:
		_friction = maxf(0.0, _friction - delta * 1.8)
		_embed_depth = maxf(0.0, _embed_depth - delta * 0.22)
		_set_ship_speed_ratio(1.0)

	_anchor_position += _anchor_velocity * delta
	_constrain_anchor_to_chain()
	_apply_ship_feedback(_chain_tension, _shock, brake_feedback, false)


func _update_locked_anchor(delta: float) -> void:
	var chain_exit := _get_chain_exit_world_position()
	var distance := chain_exit.distance_to(_get_anchor_ring_world_position())
	_chain_tension = clampf((distance - _locked_chain_length) / 240.0, 0.0, 1.0)
	_lock_strength = minf(1.0, _lock_strength + delta * 0.65)

	var brake := clampf(_friction * 0.24 + _embed_depth * 0.34 + _lock_strength * 0.42 + _chain_tension * 0.86 + _launch_power * 0.28, 0.0, 1.0)
	var power_stop_rate: float = stop_rate * (0.62 + _launch_power * 0.9)
	_stop_progress = clampf(_stop_progress + delta * power_stop_rate * (0.2 + brake), 0.0, 1.0)
	_set_ship_speed_ratio(1.0 - _stop_progress)
	_apply_ship_feedback(_chain_tension, _shock, brake, true)

	if _chain_tension > 0.12:
		_shock = maxf(_shock, _chain_tension * 0.5)


func _lock_anchor() -> void:
	_state = STATE_LOCKED
	_anchor_velocity = Vector2.ZERO
	_embed_depth = 1.0
	_friction = maxf(_friction, 0.82)
	_lock_strength = 0.28
	_shock = 1.0
	var chain_exit := _get_chain_exit_world_position()
	_locked_chain_length = maxf(90.0, chain_exit.distance_to(_get_anchor_ring_world_position()) * 0.86)
	_add_sand_puff(_get_anchor_bite_point(), 1.0)
	_add_gouge(_get_anchor_bite_point(), 1.0)
	_apply_ship_feedback(1.0, 1.0, 1.0, true)


func _constrain_anchor_to_chain() -> void:
	var chain_exit := _get_chain_exit_world_position()
	var ring_offset := _get_anchor_ring_offset()
	var ring_position := _anchor_position + ring_offset
	var offset := ring_position - chain_exit
	var distance := offset.length()
	if distance <= _paid_chain_length:
		_chain_tension = 0.0
		return

	var direction := offset / distance
	_anchor_position = chain_exit + direction * _paid_chain_length - ring_offset
	var outward_speed := _anchor_velocity.dot(direction)
	if outward_speed > 0.0:
		_anchor_velocity -= direction * outward_speed * 0.86
	_chain_tension = clampf((distance - _paid_chain_length) / 120.0, 0.0, 1.0)
	_shock = maxf(_shock, _chain_tension * 0.45)


func _sample_sand(world_point: Vector2, speed_factor: float) -> Dictionary:
	if _sand_layer == null or not _sand_layer.has_method("sample_anchor_resistance"):
		return {
			"value": 0.0,
			"contacts": 0,
			"depth": 0.0
		}
	var disturb := 18.0 + speed_factor * 42.0 + _embed_depth * 26.0
	return _sand_layer.call("sample_anchor_resistance", world_point, sand_probe_radius, disturb) as Dictionary


func _set_ship_speed_ratio(ratio: float) -> void:
	if _ship != null and _ship.has_method("set_speed_ratio"):
		_ship.call("set_speed_ratio", ratio)


func _apply_ship_feedback(tension: float, shock: float, brake: float, locked: bool) -> void:
	if _ship != null and _ship.has_method("apply_anchor_feedback"):
		_ship.call("apply_anchor_feedback", tension, shock, brake, locked)


func _ensure_asset_bodies() -> void:
	if _winch_body == null:
		_winch_body = StaticBody2D.new()
		_winch_body.name = "PhysicsWinch"
		add_child(_winch_body)

		var winch_shape := CollisionShape2D.new()
		var winch_circle := CircleShape2D.new()
		winch_circle.radius = 8.0
		winch_shape.shape = winch_circle
		_winch_body.add_child(winch_shape)

	if _winch_visual == null:
		_winch_visual = Node2D.new()
		_winch_visual.name = "WinchVisual"
		_winch_visual.set_script(WINCH_VISUAL_SCRIPT)
		_winch_visual.z_index = 120
		add_child(_winch_visual)

	if _anchor_body == null:
		_anchor_body = StaticBody2D.new()
		_anchor_body.name = "PhysicsAnchor"
		add_child(_anchor_body)

		_anchor_sprite = Sprite2D.new()
		_anchor_sprite.name = "AnchorSprite"
		_anchor_sprite.texture = ANCHOR_TEXTURE
		_anchor_sprite.scale = Vector2.ONE * anchor_texture_scale
		_anchor_sprite.z_index = 6
		_anchor_body.add_child(_anchor_sprite)

		var shank_shape := CollisionShape2D.new()
		var shank_capsule := CapsuleShape2D.new()
		shank_capsule.radius = 10.0
		shank_capsule.height = 80.0
		shank_shape.shape = shank_capsule
		shank_shape.position = Vector2(0.0, 8.0)
		_anchor_body.add_child(shank_shape)

		var fluke_shape := CollisionShape2D.new()
		var fluke_rect := RectangleShape2D.new()
		fluke_rect.size = Vector2(84.0, 24.0)
		fluke_shape.shape = fluke_rect
		fluke_shape.position = Vector2(0.0, 52.0)
		_anchor_body.add_child(fluke_shape)

	if _anchor_connector_line == null:
		_anchor_connector_line = Line2D.new()
		_anchor_connector_line.name = "AnchorRingConnector"
		_anchor_connector_line.width = 6.0
		_anchor_connector_line.default_color = Color(0.04, 0.04, 0.04, 0.74)
		_anchor_connector_line.z_index = 84
		add_child(_anchor_connector_line)

	if _anchor_coupler_sprite == null:
		_anchor_coupler_sprite = Sprite2D.new()
		_anchor_coupler_sprite.name = "AnchorRingCoupler"
		_anchor_coupler_sprite.texture = CHAIN_LINK_TEXTURE
		_anchor_coupler_sprite.scale = Vector2.ONE * link_texture_scale * 1.08
		_anchor_coupler_sprite.z_index = 96
		add_child(_anchor_coupler_sprite)


func _sync_asset_bodies() -> void:
	_sync_asset_body_transforms()
	_sync_chain_end_joints()
	_sync_anchor_ring_connector()
	_refresh_physics_chain_length()


func _sync_asset_body_transforms() -> void:
	if _winch_body == null or _anchor_body == null:
		return

	_winch_body.global_position = _get_winch_world_position()
	if _winch_visual != null:
		_winch_visual.global_position = _get_winch_world_position()
		_winch_visual.global_rotation = _get_ship_visual_rotation_offset()
		_winch_visual.set("wheel_angle", _paid_chain_length / maxf(chain_link_spacing, 1.0))
		_winch_visual.set("exit_offset", chain_exit_offset)
		_winch_visual.queue_redraw()
	_anchor_body.global_position = _anchor_position
	_anchor_body.rotation = _get_anchor_visual_world_angle()


func _refresh_physics_chain_length() -> void:
	if not use_physics_chain or _state == STATE_STOWED:
		return

	var target_link_count: int = _get_target_physics_link_count()
	if not _physics_chain_active:
		_rebuild_physics_chain()
		return

	if abs(target_link_count - _physics_chain_link_count) >= 3:
		_rebuild_physics_chain()


func _sync_chain_end_joints() -> void:
	if not _physics_chain_active or _chain_joints.is_empty():
		return

	var first_joint: PinJoint2D = _chain_joints[0]
	if is_instance_valid(first_joint):
		first_joint.global_position = _get_chain_exit_world_position()

	var last_joint: PinJoint2D = _chain_joints[_chain_joints.size() - 1]
	if is_instance_valid(last_joint):
		last_joint.global_position = _get_anchor_ring_world_position()


func _sync_anchor_ring_connector() -> void:
	if _anchor_connector_line == null or _anchor_coupler_sprite == null:
		return

	var ring_position: Vector2 = _get_anchor_ring_world_position()
	var has_physics_link: bool = _physics_chain_active and not _chain_links.is_empty()
	var connector_visible: bool = has_physics_link and _state != STATE_STOWED
	_anchor_connector_line.visible = connector_visible
	_anchor_coupler_sprite.visible = true
	_anchor_coupler_sprite.global_position = ring_position

	var coupler_rotation: float = _get_anchor_visual_world_angle()
	if has_physics_link:
		var last_link: RigidBody2D = _chain_links[_chain_links.size() - 1]
		if is_instance_valid(last_link):
			var to_ring: Vector2 = ring_position - last_link.global_position
			if to_ring.length() > 0.01:
				coupler_rotation = to_ring.angle() - PI * 0.5

			if connector_visible:
				var start_position: Vector2 = last_link.global_position
				var bend_position: Vector2 = start_position.lerp(ring_position, 0.55)
				_anchor_connector_line.points = PackedVector2Array([
					_anchor_connector_line.to_local(start_position),
					_anchor_connector_line.to_local(bend_position),
					_anchor_connector_line.to_local(ring_position)
				])

	_anchor_coupler_sprite.global_rotation = coupler_rotation


func _rebuild_physics_chain() -> void:
	_clear_physics_chain()
	_ensure_asset_bodies()
	_sync_asset_body_transforms()

	var winch: Vector2 = _get_chain_exit_world_position()
	var anchor: Vector2 = _get_anchor_ring_world_position()
	var direction: Vector2 = anchor - winch
	if direction.length() < 8.0:
		direction = Vector2.DOWN
	else:
		direction = direction.normalized()

	var normal_angle: float = direction.angle() - PI * 0.5
	var previous_body: PhysicsBody2D = _winch_body
	var previous_position: Vector2 = winch
	var link_count: int = _get_target_physics_link_count()

	for i in range(link_count):
		var body := RigidBody2D.new()
		body.name = "ChainLink%02d" % i
		body.z_index = 12
		body.mass = 0.16
		body.gravity_scale = link_gravity_scale
		body.linear_damp = link_linear_damp
		body.angular_damp = link_angular_damp
		body.collision_layer = 1
		body.collision_mask = 1
		add_child(body)
		body.global_position = winch + direction * chain_link_spacing * float(i + 1)
		body.global_rotation = normal_angle
		if i % 2 == 1:
			body.global_rotation += PI * 0.5

		var sprite := Sprite2D.new()
		sprite.name = "Visual"
		sprite.texture = CHAIN_LINK_TEXTURE
		sprite.scale = Vector2.ONE * link_texture_scale
		body.add_child(sprite)

		_add_link_collision(body)
		_chain_links.append(body)
		var joint_position: Vector2 = previous_position.lerp(body.global_position, 0.5)
		if i == 0:
			joint_position = winch
		_add_pin_joint(previous_body, body, joint_position)

		previous_body = body
		previous_position = body.global_position

	_add_pin_joint(previous_body, _anchor_body, anchor)
	_physics_chain_active = true
	_physics_chain_link_count = link_count


func _clear_physics_chain() -> void:
	for joint in _chain_joints:
		if is_instance_valid(joint):
			joint.queue_free()
	_chain_joints.clear()

	for link in _chain_links:
		if is_instance_valid(link):
			link.queue_free()
	_chain_links.clear()
	_physics_chain_active = false
	_physics_chain_link_count = 0


func _get_target_physics_link_count() -> int:
	var target_link_count: int = int(_paid_chain_length / maxf(chain_link_spacing, 1.0))
	target_link_count = clampi(target_link_count, 4, physics_link_count)
	return target_link_count


func _add_link_collision(body: RigidBody2D) -> void:
	_add_capsule_collision(body, Vector2(-link_bar_offset, 0.0), link_collision_radius, link_collision_length, 0.0)
	_add_capsule_collision(body, Vector2(link_bar_offset, 0.0), link_collision_radius, link_collision_length, 0.0)
	_add_capsule_collision(body, Vector2(0.0, -link_collision_length * 0.42), link_collision_radius, link_bar_offset * 2.4, PI * 0.5)
	_add_capsule_collision(body, Vector2(0.0, link_collision_length * 0.42), link_collision_radius, link_bar_offset * 2.4, PI * 0.5)


func _add_capsule_collision(parent: Node, position: Vector2, radius: float, height: float, rotation: float) -> void:
	var collision := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = radius
	capsule.height = height
	collision.shape = capsule
	collision.position = position
	collision.rotation = rotation
	parent.add_child(collision)


func _add_pin_joint(body_a: PhysicsBody2D, body_b: PhysicsBody2D, position: Vector2) -> void:
	var joint := PinJoint2D.new()
	joint.name = "ChainJoint"
	add_child(joint)
	joint.global_position = position
	joint.node_a = joint.get_path_to(body_a)
	joint.node_b = joint.get_path_to(body_b)
	joint.disable_collision = true
	_chain_joints.append(joint)


func _maybe_stamp_sand(world_point: Vector2, resistance: float, contacts: int) -> void:
	_gouge_cooldown -= get_physics_process_delta_time()
	if _gouge_cooldown > 0.0:
		return

	_gouge_cooldown = lerpf(0.22, 0.08, clampf(resistance, 0.0, 1.0))
	_add_sand_puff(world_point, clampf(resistance + contacts * 0.035, 0.25, 1.0))
	_add_gouge(world_point, resistance)
	_shock = maxf(_shock, 0.2 + resistance * 0.56)


func _add_sand_puff(world_point: Vector2, strength: float) -> void:
	var count := int(round(4.0 + strength * 8.0))
	for i in range(count):
		var angle := -PI * 0.5 + randf_range(-1.0, 1.0) * PI * 0.42
		var speed := randf_range(34.0, 110.0) * strength
		_puffs.append({
			"pos": world_point + Vector2(randf_range(-16.0, 16.0), randf_range(-8.0, 8.0)),
			"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(32.0 * strength, 0.0),
			"life": randf_range(0.28, 0.62),
			"max_life": 0.62,
			"radius": randf_range(2.0, 5.5)
		})
	if _puffs.size() > 90:
		while _puffs.size() > 90:
			_puffs.remove_at(0)


func _add_gouge(world_point: Vector2, strength: float) -> void:
	_gouges.append({
		"pos": world_point + Vector2(randf_range(-10.0, 10.0), randf_range(-2.0, 7.0)),
		"angle": randf_range(-0.16, 0.16),
		"length": randf_range(18.0, 38.0) * (0.65 + strength * 0.7)
	})
	if _gouges.size() > 70:
		while _gouges.size() > 70:
			_gouges.remove_at(0)


func _update_particles(delta: float) -> void:
	_control_flash_time = maxf(0.0, _control_flash_time - delta)
	for puff in _puffs:
		puff["life"] = float(puff["life"]) - delta
		var velocity: Vector2 = puff["vel"] as Vector2
		velocity.y += 118.0 * delta
		velocity *= pow(0.16, delta)
		puff["vel"] = velocity
		puff["pos"] = (puff["pos"] as Vector2) + velocity * delta

	var kept: Array[Dictionary] = []
	for puff in _puffs:
		if float(puff["life"]) > 0.0:
			kept.append(puff)
	_puffs = kept


func _get_winch_world_position() -> Vector2:
	return _get_ship_mount_world(winch_local_position)


func _get_chain_exit_world_position() -> Vector2:
	return _get_ship_mount_world(winch_local_position + chain_exit_offset)


func _get_stowed_anchor_position() -> Vector2:
	return _get_ship_mount_world(winch_local_position + stowed_anchor_offset)


func _get_anchor_ring_offset() -> Vector2:
	return anchor_ring_local_offset.rotated(_get_anchor_visual_world_angle())


func _get_anchor_ring_world_position() -> Vector2:
	return _anchor_position + _get_anchor_ring_offset()


func _get_anchor_bite_point() -> Vector2:
	return _anchor_position + Vector2(0.0, 42.0)


func _get_anchor_visual_angle() -> float:
	var angle := -0.18
	if _state == STATE_DROPPING or _state == STATE_DRAGGING:
		angle += clampf(_anchor_velocity.x / 260.0, -0.4, 0.24)
	if _state == STATE_LOCKED:
		angle = -0.32 + _chain_tension * 0.18
	return angle


func _get_anchor_visual_world_angle() -> float:
	if _state == STATE_STOWED:
		return _get_anchor_visual_angle() + _get_ship_visual_rotation_offset()
	return _get_anchor_visual_angle()


func _get_ship_mount_world(local_position: Vector2) -> Vector2:
	if _ship == null:
		return local_position
	if _ship.has_method("get_visual_mount_global"):
		var value: Variant = _ship.call("get_visual_mount_global", local_position)
		if value is Vector2:
			return value as Vector2
	return _ship.to_global(local_position)


func _get_ship_visual_rotation_offset() -> float:
	if _ship != null and _ship.has_method("get_visual_rotation_offset"):
		var value: Variant = _ship.call("get_visual_rotation_offset")
		if value != null:
			return float(value)
	return 0.0


func _request_ship_retract_boost(strength: float) -> void:
	if _ship != null and _ship.has_method("apply_anchor_retract_boost"):
		_ship.call("apply_anchor_retract_boost", strength)


func _draw() -> void:
	var anchor := _anchor_position

	if _state != STATE_STOWED:
		if not _physics_chain_active:
			_draw_chain(_get_chain_exit_world_position(), _get_anchor_ring_world_position())
	else:
		_draw_short_stowed_chain(_get_chain_exit_world_position(), _get_anchor_ring_world_position())
	_draw_puffs()
	if _anchor_body == null:
		_draw_anchor(anchor)
	_draw_control_flash()


func _draw_winch(center: Vector2) -> void:
	var ink := Color(0.04, 0.04, 0.04, 1.0)
	var paper := Color(0.96, 0.96, 0.92, 1.0)
	draw_circle(center, 25.0, paper)
	draw_arc(center, 25.0, 0.0, TAU, 36, ink, 4.0)
	draw_arc(center, 13.0, 0.0, TAU, 28, ink, 3.0)
	draw_line(center + Vector2(-34.0, 28.0), center + Vector2(34.0, 28.0), ink, 5.0)
	draw_line(center + Vector2(0.0, -22.0), center + Vector2(0.0, 22.0), ink, 3.0)
	draw_line(center + Vector2(-22.0, 0.0), center + Vector2(22.0, 0.0), ink, 3.0)


func _draw_chain(start: Vector2, end: Vector2) -> void:
	var points: PackedVector2Array = _make_chain_points(start, end)
	var ink: Color = Color(0.04, 0.04, 0.04, 1.0)
	var highlight: Color = Color(0.86, 0.88, 0.86, 1.0)
	draw_polyline(points, Color(0.04, 0.04, 0.04, 0.52), 7.0, true)
	_draw_textured_chain(points, 0)
	_draw_anchor_end_link(points, end)
	draw_circle(end, 4.2, ink)
	draw_circle(end, 1.8, highlight)


func _draw_short_stowed_chain(start: Vector2, end: Vector2) -> void:
	var points: PackedVector2Array = PackedVector2Array([start, start.lerp(end, 0.5) + Vector2(-9.0, 11.0), end])
	draw_polyline(points, Color(0.04, 0.04, 0.04, 0.42), 6.0, true)
	_draw_textured_chain(points, 1)
	_draw_anchor_end_link(points, end)


func _draw_textured_chain(points: PackedVector2Array, phase: int) -> void:
	if points.size() < 2:
		return

	var spacing: float = maxf(chain_link_spacing, 4.0)
	var link_height: float = spacing * 1.9
	var carried_distance: float = spacing * 0.35
	var link_index: int = phase

	for i in range(points.size() - 1):
		var segment_start: Vector2 = points[i]
		var segment_end: Vector2 = points[i + 1]
		var segment: Vector2 = segment_end - segment_start
		var segment_length: float = segment.length()
		if segment_length < 0.01:
			continue

		var direction: Vector2 = segment / segment_length
		var angle: float = direction.angle() - PI * 0.5
		var distance_on_segment: float = spacing - carried_distance
		while distance_on_segment <= segment_length:
			var center: Vector2 = segment_start + direction * distance_on_segment
			var twist: float = 0.0
			if link_index % 2 == 1:
				twist = PI * 0.5
			_draw_texture_link(center, link_height, angle + twist, 0.96)
			link_index += 1
			distance_on_segment += spacing

		carried_distance = fmod(carried_distance + segment_length, spacing)


func _draw_texture_link(center: Vector2, height: float, rotation: float, alpha: float) -> void:
	var width: float = height * 0.58
	draw_set_transform(center, rotation, Vector2.ONE)
	draw_texture_rect(
		CHAIN_LINK_TEXTURE,
		Rect2(Vector2(-width * 0.5, -height * 0.5), Vector2(width, height)),
		false,
		Color(1.0, 1.0, 1.0, alpha)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_anchor_end_link(points: PackedVector2Array, end: Vector2) -> void:
	if points.size() < 2:
		return

	var previous: Vector2 = points[points.size() - 2]
	var direction: Vector2 = end - previous
	var angle: float = _get_anchor_visual_angle()
	if direction.length() > 0.01:
		angle = direction.angle() - PI * 0.5

	_draw_texture_link(end, maxf(chain_link_spacing * 2.12, 30.0), angle, 1.0)


func _make_chain_points(start: Vector2, end: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var distance := start.distance_to(end)
	var segment_count := clampi(int(distance / 42.0), 8, 28)
	var sag := minf(96.0, distance * 0.16) * (1.0 - _chain_tension * 0.78)
	for i in range(segment_count + 1):
		var t := float(i) / float(segment_count)
		var p := start.lerp(end, t)
		p.y += sin(t * PI) * sag
		if _shock > 0.0:
			p.x += sin(Time.get_ticks_msec() * 0.04 + float(i) * 1.9) * _shock * 4.0
		points.append(p)
	return points


func _sample_chain_point(points: PackedVector2Array, t: float) -> Vector2:
	if points.size() == 0:
		return Vector2.ZERO
	var index_float := clampf(t, 0.0, 1.0) * float(points.size() - 1)
	var index := int(floor(index_float))
	var next_index := index + 1
	if next_index > points.size() - 1:
		next_index = points.size() - 1
	var local_t := index_float - float(index)
	return points[index].lerp(points[next_index], local_t)


func _draw_anchor(center: Vector2) -> void:
	var ink := Color(0.04, 0.04, 0.04, 1.0)
	var fill := Color(0.78, 0.8, 0.78, 1.0)
	var angle := _get_anchor_visual_world_angle()

	draw_set_transform(center, angle, Vector2.ONE)
	draw_arc(Vector2(0.0, -34.0), 13.0, 0.0, TAU, 28, ink, 5.0)
	draw_line(Vector2(0.0, -21.0), Vector2(0.0, 34.0), ink, 8.0)
	draw_line(Vector2(-24.0, -2.0), Vector2(24.0, -2.0), ink, 8.0)
	draw_line(Vector2(0.0, 34.0), Vector2(-34.0, 61.0), ink, 8.0)
	draw_line(Vector2(0.0, 34.0), Vector2(34.0, 61.0), ink, 8.0)
	draw_polygon(PackedVector2Array([Vector2(-34.0, 61.0), Vector2(-54.0, 50.0), Vector2(-41.0, 76.0)]), PackedColorArray([fill, fill, fill]))
	draw_polygon(PackedVector2Array([Vector2(34.0, 61.0), Vector2(54.0, 50.0), Vector2(41.0, 76.0)]), PackedColorArray([fill, fill, fill]))
	draw_polyline(PackedVector2Array([Vector2(-54.0, 50.0), Vector2(-34.0, 61.0), Vector2(-41.0, 76.0), Vector2(-54.0, 50.0)]), ink, 4.0, true)
	draw_polyline(PackedVector2Array([Vector2(54.0, 50.0), Vector2(34.0, 61.0), Vector2(41.0, 76.0), Vector2(54.0, 50.0)]), ink, 4.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_puffs() -> void:
	for puff in _puffs:
		var life: float = float(puff["life"])
		var max_life: float = float(puff["max_life"])
		var alpha := clampf(life / max_life, 0.0, 1.0) * 0.72
		var pos: Vector2 = puff["pos"] as Vector2
		draw_circle(pos, float(puff["radius"]) * (1.0 + (1.0 - alpha) * 0.7), Color(0.05, 0.05, 0.05, alpha))


func _draw_control_flash() -> void:
	if _control_flash_time <= 0.0 or _control_flash.is_empty():
		return
	var alpha: float = clampf(_control_flash_time / 0.42, 0.0, 1.0)
	var position: Vector2 = _get_winch_world_position() + Vector2(-72.0, -56.0)
	draw_rect(Rect2(position + Vector2(-10.0, -18.0), Vector2(118.0, 28.0)), Color(1.0, 1.0, 1.0, 0.58 * alpha), true)
	draw_string(ThemeDB.fallback_font, position, _control_flash, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16.0, Color(0.02, 0.02, 0.02, alpha))


func _draw_gouges() -> void:
	var ink := Color(0.04, 0.04, 0.04, 0.65)
	var seabed_y: float = _get_seabed_y()
	for gouge in _gouges:
		var pos: Vector2 = gouge["pos"] as Vector2
		if pos.y < seabed_y - 8.0:
			continue
		var length: float = float(gouge["length"])
		var direction: Vector2 = Vector2.RIGHT.rotated(float(gouge["angle"]))
		draw_line(pos - direction * length * 0.5, pos + direction * length * 0.5, ink, 3.0)


func _get_seabed_y() -> float:
	if _sand_layer != null:
		var value: Variant = _sand_layer.get("seabed_y")
		if value != null:
			return float(value)
	return 210.0

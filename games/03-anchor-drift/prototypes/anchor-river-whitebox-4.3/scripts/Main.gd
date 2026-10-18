extends Node3D

enum AnchorState { IDLE, FLYING, SINKING, HOOKED, RETRACTING }

const OUTER_HALF := 28.0
const INNER_HALF := 13.0
const PATH_HALF := 20.5
const CANAL_HALF_WIDTH := 7.5
const BOAT_Y := 0.28
const WATER_Y := 0.0
const ANCHOR_BED_Y := -0.38
const CHAIN_LINKS := 24

var water_material: StandardMaterial3D
var bank_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var boat_material: StandardMaterial3D
var metal_material: StandardMaterial3D
var anchor_material: StandardMaterial3D
var marker_material: StandardMaterial3D

var boat: Node3D
var anchor_node: Node3D
var chain_root: Node3D
var chain_links: Array[MeshInstance3D] = []
var camera: Camera3D
var debug_label: Label

var velocity := Vector3.ZERO
var anchor_state := AnchorState.IDLE
var anchor_position := Vector3.ZERO
var anchor_start := Vector3.ZERO
var anchor_target := Vector3.ZERO
var anchor_timer := 0.0
var chain_length := 0.0
var distance_travelled := 0.0
var current_segment := 0
var look_back_amount := 0.0

@export var flow_acceleration := 5.2
@export var max_water_speed := 11.5
@export var water_drag := 0.985
@export var bank_bounce_drag := 0.42
@export var throw_distance := 10.0
@export var anchor_fly_time := 0.24
@export var anchor_sink_time := 0.36
@export var anchor_pull_strength := 38.0
@export var anchor_tension_drag := 0.955
@export var hooked_chain_ratio := 0.56

func _ready() -> void:
	_setup_input_actions()
	_setup_materials()
	_setup_world()
	_create_square_canal()
	_create_boat()
	_create_anchor()
	_create_chain()
	_create_camera()
	_create_debug_ui()
	_reset_run()


func _setup_input_actions() -> void:
	if not InputMap.has_action("throw_anchor"):
		InputMap.add_action("throw_anchor")
		var space_event := InputEventKey.new()
		space_event.keycode = KEY_SPACE
		InputMap.action_add_event("throw_anchor", space_event)
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("throw_anchor", mouse_event)

	if not InputMap.has_action("reset_run"):
		InputMap.add_action("reset_run")
		var reset_event := InputEventKey.new()
		reset_event.keycode = KEY_R
		InputMap.action_add_event("reset_run", reset_event)


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("reset_run"):
		_reset_run()

	if Input.is_action_just_pressed("throw_anchor"):
		if anchor_state == AnchorState.IDLE:
			_throw_anchor()
		else:
			_release_anchor()

	_update_anchor(delta)
	_update_boat(delta)
	_update_chain()
	_update_camera(delta)
	_update_debug_ui()


func _setup_materials() -> void:
	water_material = _make_material(Color(0.38, 0.70, 0.84, 0.78), 0.25, 0.35, true)
	bank_material = _make_material(Color(0.72, 0.70, 0.55), 0.8, 0.05, false)
	wall_material = _make_material(Color(0.42, 0.44, 0.38), 0.55, 0.0, false)
	boat_material = _make_material(Color(0.95, 0.77, 0.24), 0.5, 0.1, false)
	metal_material = _make_material(Color(0.70, 0.73, 0.74), 0.26, 0.85, false)
	anchor_material = _make_material(Color(0.18, 0.22, 0.25), 0.33, 0.75, false)
	marker_material = _make_material(Color(0.95, 0.96, 1.0), 0.18, 0.15, false)


func _make_material(color: Color, roughness: float, metallic: float, transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _setup_world() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.08, 0.11, 0.14)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.82, 0.88, 0.95)
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Low Afternoon Key Light"
	sun.light_energy = 2.4
	sun.rotation_degrees = Vector3(-54.0, -36.0, 0.0)
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "Soft Fill Light"
	fill.light_energy = 0.9
	fill.omni_range = 52.0
	fill.position = Vector3(0.0, 13.0, 0.0)
	add_child(fill)


func _create_square_canal() -> void:
	var map_root := Node3D.new()
	map_root.name = "Square Loop Canal"
	add_child(map_root)

	_make_box(map_root, "North Water", Vector3(0, WATER_Y - 0.08, -PATH_HALF), Vector3(OUTER_HALF * 2.0, 0.12, CANAL_HALF_WIDTH * 2.0), water_material)
	_make_box(map_root, "East Water", Vector3(PATH_HALF, WATER_Y - 0.08, 0), Vector3(CANAL_HALF_WIDTH * 2.0, 0.12, OUTER_HALF * 2.0), water_material)
	_make_box(map_root, "South Water", Vector3(0, WATER_Y - 0.08, PATH_HALF), Vector3(OUTER_HALF * 2.0, 0.12, CANAL_HALF_WIDTH * 2.0), water_material)
	_make_box(map_root, "West Water", Vector3(-PATH_HALF, WATER_Y - 0.08, 0), Vector3(CANAL_HALF_WIDTH * 2.0, 0.12, OUTER_HALF * 2.0), water_material)

	_make_box(map_root, "Center Island Bank", Vector3(0, -0.34, 0), Vector3(INNER_HALF * 2.0, 0.72, INNER_HALF * 2.0), bank_material)
	_make_box(map_root, "North Outer Bank", Vector3(0, -0.32, -33.0), Vector3(70.0, 0.70, 10.0), bank_material)
	_make_box(map_root, "East Outer Bank", Vector3(33.0, -0.32, 0), Vector3(10.0, 0.70, 70.0), bank_material)
	_make_box(map_root, "South Outer Bank", Vector3(0, -0.32, 33.0), Vector3(70.0, 0.70, 10.0), bank_material)
	_make_box(map_root, "West Outer Bank", Vector3(-33.0, -0.32, 0), Vector3(10.0, 0.70, 70.0), bank_material)

	_make_box(map_root, "Center North Wall", Vector3(0, 0.42, -INNER_HALF), Vector3(INNER_HALF * 2.0, 1.05, 0.35), wall_material)
	_make_box(map_root, "Center East Wall", Vector3(INNER_HALF, 0.42, 0), Vector3(0.35, 1.05, INNER_HALF * 2.0), wall_material)
	_make_box(map_root, "Center South Wall", Vector3(0, 0.42, INNER_HALF), Vector3(INNER_HALF * 2.0, 1.05, 0.35), wall_material)
	_make_box(map_root, "Center West Wall", Vector3(-INNER_HALF, 0.42, 0), Vector3(0.35, 1.05, INNER_HALF * 2.0), wall_material)

	_make_box(map_root, "North Outer Wall", Vector3(0, 0.42, -OUTER_HALF), Vector3(OUTER_HALF * 2.0, 1.05, 0.35), wall_material)
	_make_box(map_root, "East Outer Wall", Vector3(OUTER_HALF, 0.42, 0), Vector3(0.35, 1.05, OUTER_HALF * 2.0), wall_material)
	_make_box(map_root, "South Outer Wall", Vector3(0, 0.42, OUTER_HALF), Vector3(OUTER_HALF * 2.0, 1.05, 0.35), wall_material)
	_make_box(map_root, "West Outer Wall", Vector3(-OUTER_HALF, 0.42, 0), Vector3(0.35, 1.05, OUTER_HALF * 2.0), wall_material)

	for i in range(4):
		_make_flow_arrow(map_root, i)


func _create_boat() -> void:
	boat = Node3D.new()
	boat.name = "Boat"
	add_child(boat)

	_make_box(boat, "Hull", Vector3.ZERO, Vector3(1.25, 0.44, 2.1), boat_material)
	_make_box(boat, "Cabin", Vector3(0.0, 0.42, -0.25), Vector3(0.92, 0.58, 0.82), marker_material)
	_make_box(boat, "Bow Marker", Vector3(0.0, 0.20, -1.28), Vector3(0.55, 0.18, 0.42), boat_material)
	_make_box(boat, "Left Pontoon", Vector3(-0.82, -0.08, 0.1), Vector3(0.24, 0.22, 1.65), marker_material)
	_make_box(boat, "Right Pontoon", Vector3(0.82, -0.08, 0.1), Vector3(0.24, 0.22, 1.65), marker_material)


func _create_anchor() -> void:
	anchor_node = Node3D.new()
	anchor_node.name = "Anchor"
	add_child(anchor_node)

	var core := SphereMesh.new()
	core.radius = 0.22
	core.height = 0.42
	var core_mesh := MeshInstance3D.new()
	core_mesh.name = "Anchor Head"
	core_mesh.mesh = core
	core_mesh.material_override = anchor_material
	anchor_node.add_child(core_mesh)

	_make_box(anchor_node, "Anchor Stem", Vector3(0.0, 0.15, 0.0), Vector3(0.12, 0.62, 0.12), anchor_material)
	var fluke_left := _make_box(anchor_node, "Anchor Fluke Left", Vector3(-0.32, -0.08, 0.0), Vector3(0.55, 0.11, 0.16), anchor_material)
	fluke_left.rotation_degrees.z = -22.0
	var fluke_right := _make_box(anchor_node, "Anchor Fluke Right", Vector3(0.32, -0.08, 0.0), Vector3(0.55, 0.11, 0.16), anchor_material)
	fluke_right.rotation_degrees.z = 22.0
	anchor_node.visible = false


func _create_chain() -> void:
	chain_root = Node3D.new()
	chain_root.name = "Chain"
	add_child(chain_root)

	for i in range(CHAIN_LINKS):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.20, 0.08, 0.72)
		var link := MeshInstance3D.new()
		link.name = "Chain Link %02d" % i
		link.mesh = mesh
		link.material_override = metal_material
		link.visible = false
		chain_root.add_child(link)
		chain_links.append(link)


func _create_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Follow Camera"
	camera.fov = 54.0
	camera.current = true
	add_child(camera)


func _create_debug_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "Debug UI"
	add_child(canvas)

	debug_label = Label.new()
	debug_label.name = "Debug Label"
	debug_label.position = Vector2(24, 20)
	debug_label.add_theme_font_size_override("font_size", 18)
	debug_label.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
	debug_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	debug_label.add_theme_constant_override("shadow_offset_x", 2)
	debug_label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(debug_label)


func _reset_run() -> void:
	boat.position = Vector3(-PATH_HALF + 5.0, BOAT_Y, -PATH_HALF)
	velocity = Vector3(5.0, 0.0, 0.0)
	anchor_state = AnchorState.IDLE
	anchor_node.visible = false
	chain_length = 0.0
	distance_travelled = 0.0
	current_segment = 0
	look_back_amount = 0.0
	_update_chain()
	_update_camera(1.0)


func _throw_anchor() -> void:
	var flow := _get_flow_info(boat.global_position)
	var forward := _flat_direction(velocity)
	if forward == Vector3.ZERO:
		forward = flow["dir"]

	anchor_state = AnchorState.FLYING
	anchor_timer = 0.0
	anchor_start = boat.global_position + Vector3.UP * 0.35
	anchor_target = _clamp_to_canal(boat.global_position + forward * throw_distance)
	anchor_target.y = WATER_Y + 0.08
	anchor_position = anchor_start
	anchor_node.global_position = anchor_position
	anchor_node.visible = true


func _release_anchor() -> void:
	anchor_state = AnchorState.RETRACTING
	anchor_timer = 0.0


func _update_anchor(delta: float) -> void:
	match anchor_state:
		AnchorState.IDLE:
			pass
		AnchorState.FLYING:
			anchor_timer += delta
			var t := clamp(anchor_timer / anchor_fly_time, 0.0, 1.0)
			anchor_position = anchor_start.lerp(anchor_target, t)
			anchor_position.y += sin(t * PI) * 1.2
			anchor_node.global_position = anchor_position
			if t >= 1.0:
				anchor_state = AnchorState.SINKING
				anchor_timer = 0.0
		AnchorState.SINKING:
			anchor_timer += delta
			var sink_t := clamp(anchor_timer / anchor_sink_time, 0.0, 1.0)
			anchor_position = anchor_target.lerp(Vector3(anchor_target.x, ANCHOR_BED_Y, anchor_target.z), sink_t)
			anchor_node.global_position = anchor_position
			if sink_t >= 1.0:
				anchor_state = AnchorState.HOOKED
				var dist := _horizontal_distance(boat.global_position, anchor_position)
				chain_length = max(2.4, dist * hooked_chain_ratio)
		AnchorState.HOOKED:
			anchor_node.global_position = anchor_position
			_apply_anchor_tension(delta)
		AnchorState.RETRACTING:
			anchor_timer += delta
			var rt := clamp(anchor_timer / 0.18, 0.0, 1.0)
			anchor_position = anchor_position.lerp(boat.global_position + Vector3.UP * 0.28, rt)
			anchor_node.global_position = anchor_position
			if rt >= 1.0:
				anchor_state = AnchorState.IDLE
				anchor_node.visible = false


func _update_boat(delta: float) -> void:
	var flow := _get_flow_info(boat.global_position)
	var flow_dir: Vector3 = flow["dir"]
	current_segment = flow["segment"]

	velocity += flow_dir * flow_acceleration * delta
	if velocity.length() > max_water_speed:
		velocity = velocity.normalized() * max_water_speed
	velocity *= water_drag

	boat.global_position += velocity * delta
	boat.global_position.y = BOAT_Y
	distance_travelled += max(0.0, velocity.dot(flow_dir)) * delta

	var post_move_flow := _get_flow_info(boat.global_position)
	_keep_boat_in_canal(post_move_flow)
	_face_boat()


func _apply_anchor_tension(delta: float) -> void:
	var boat_pos := boat.global_position
	var flat_boat := Vector3(boat_pos.x, 0.0, boat_pos.z)
	var flat_anchor := Vector3(anchor_position.x, 0.0, anchor_position.z)
	var offset := flat_anchor - flat_boat
	var dist := offset.length()
	if dist <= chain_length or dist <= 0.01:
		return

	var pull_dir := offset / dist
	var tension := dist - chain_length
	velocity += pull_dir * anchor_pull_strength * tension * delta
	velocity *= anchor_tension_drag

	var flow := _get_flow_info(boat.global_position)
	var flow_dir: Vector3 = flow["dir"]
	var against_flow := max(0.0, -pull_dir.dot(flow_dir))
	if against_flow > 0.25:
		velocity -= flow_dir * against_flow * 6.0 * delta


func _keep_boat_in_canal(flow: Dictionary) -> void:
	var center: Vector3 = flow["point"]
	var lateral_vec := Vector3(boat.global_position.x - center.x, 0.0, boat.global_position.z - center.z)
	var lateral := lateral_vec.length()
	var safe_half_width := CANAL_HALF_WIDTH - 0.75
	if lateral <= safe_half_width:
		return

	var normal := lateral_vec.normalized()
	boat.global_position.x = center.x + normal.x * safe_half_width
	boat.global_position.z = center.z + normal.z * safe_half_width

	var outward_speed := velocity.dot(normal)
	if outward_speed > 0.0:
		velocity -= normal * outward_speed * (1.0 + bank_bounce_drag)
	velocity *= 0.78


func _face_boat() -> void:
	var direction := _flat_direction(velocity)
	if direction == Vector3.ZERO:
		return
	var target := boat.global_position + direction
	boat.look_at(target, Vector3.UP)


func _update_chain() -> void:
	var active := anchor_state != AnchorState.IDLE and anchor_node.visible
	for link in chain_links:
		link.visible = false
	if not active:
		return

	var start := boat.global_position + Vector3.UP * 0.16
	var end := anchor_position + Vector3.UP * 0.12
	var span := end - start
	var dist := span.length()
	if dist <= 0.05:
		return

	var dir := span / dist
	var count := clamp(int(dist / 0.58), 2, CHAIN_LINKS)
	for i in range(count):
		var t := float(i + 1) / float(count + 1)
		var link := chain_links[i]
		link.visible = true
		link.global_position = start.lerp(end, t)
		link.look_at(link.global_position + dir, Vector3.UP)
		link.rotate_object_local(Vector3.FORWARD, PI * 0.5 * float(i % 2))


func _update_camera(delta: float) -> void:
	var flow := _get_flow_info(boat.global_position)
	var movement_dir := _flat_direction(velocity)
	if movement_dir == Vector3.ZERO:
		movement_dir = flow["dir"]

	var flow_dir: Vector3 = flow["dir"]
	var should_look_back := anchor_state == AnchorState.HOOKED and (velocity.dot(flow_dir) < 1.2 or _horizontal_distance(boat.global_position, anchor_position) > chain_length + 1.6)
	var target_amount := 1.0 if should_look_back else 0.0
	look_back_amount = lerp(look_back_amount, target_amount, clamp(delta * 3.0, 0.0, 1.0))

	var chase_pos := boat.global_position - movement_dir * 8.5 + Vector3.UP * 6.2
	var reverse_pos := boat.global_position + movement_dir * 7.2 + Vector3.UP * 4.8
	var desired_pos := chase_pos.lerp(reverse_pos, look_back_amount)
	camera.global_position = camera.global_position.lerp(desired_pos, clamp(delta * 5.0, 0.0, 1.0))

	var look_target := boat.global_position + Vector3.UP * 0.55
	if anchor_state == AnchorState.HOOKED:
		look_target = look_target.lerp(anchor_position + Vector3.UP * 0.15, 0.25)
	camera.look_at(look_target, Vector3.UP)


func _update_debug_ui() -> void:
	var flow := _get_flow_info(boat.global_position)
	var dist_to_anchor := 0.0
	if anchor_state != AnchorState.IDLE:
		dist_to_anchor = _horizontal_distance(boat.global_position, anchor_position)

	debug_label.text = "方形循环河道  |  Space/左键 抛锚/收锚  |  R 重置\n"
	debug_label.text += "水流段: %s   速度: %.1f   行驶: %.0fm\n" % [_segment_name(flow["segment"]), velocity.length(), distance_travelled]
	debug_label.text += "锚状态: %s   绳距: %.1f / %.1f" % [_anchor_state_name(anchor_state), dist_to_anchor, chain_length]
	if look_back_amount > 0.35:
		debug_label.text += "   LOOK BACK"


func _get_flow_info(pos: Vector3) -> Dictionary:
	var points := [
		Vector3(-PATH_HALF, 0.0, -PATH_HALF),
		Vector3(PATH_HALF, 0.0, -PATH_HALF),
		Vector3(PATH_HALF, 0.0, PATH_HALF),
		Vector3(-PATH_HALF, 0.0, PATH_HALF)
	]
	var dirs := [
		Vector3.RIGHT,
		Vector3.BACK,
		Vector3.LEFT,
		Vector3.FORWARD
	]

	var best_segment := 0
	var best_point := points[0]
	var best_dist := INF
	var flat_pos := Vector3(pos.x, 0.0, pos.z)

	for i in range(4):
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i + 1) % 4]
		var ab := b - a
		var t := clamp((flat_pos - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var closest := a + ab * t
		var dist := flat_pos.distance_to(closest)
		if dist < best_dist:
			best_dist = dist
			best_point = closest
			best_segment = i

	return {
		"point": best_point,
		"dir": dirs[best_segment],
		"lateral": best_dist,
		"segment": best_segment,
	}


func _clamp_to_canal(pos: Vector3) -> Vector3:
	var flow := _get_flow_info(pos)
	var center: Vector3 = flow["point"]
	var lateral_vec := Vector3(pos.x - center.x, 0.0, pos.z - center.z)
	var lateral := lateral_vec.length()
	var safe_half_width := CANAL_HALF_WIDTH - 1.0
	if lateral <= safe_half_width:
		return Vector3(pos.x, pos.y, pos.z)
	var normal := lateral_vec.normalized()
	return Vector3(center.x + normal.x * safe_half_width, pos.y, center.z + normal.z * safe_half_width)


func _make_box(parent: Node, name: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance


func _make_flow_arrow(parent: Node, segment: int) -> void:
	var flow_positions := [
		Vector3(-3.5, 0.04, -PATH_HALF),
		Vector3(PATH_HALF, 0.04, -3.5),
		Vector3(3.5, 0.04, PATH_HALF),
		Vector3(-PATH_HALF, 0.04, 3.5),
	]
	var rotations := [90.0, 180.0, -90.0, 0.0]
	var arrow := Node3D.new()
	arrow.name = "Current Arrow %d" % segment
	arrow.position = flow_positions[segment]
	arrow.rotation_degrees.y = rotations[segment]
	parent.add_child(arrow)
	_make_box(arrow, "Shaft", Vector3(0.0, 0.0, 0.0), Vector3(0.16, 0.08, 2.2), marker_material)
	var head_left := _make_box(arrow, "Head Left", Vector3(-0.28, 0.0, -1.0), Vector3(0.16, 0.08, 0.74), marker_material)
	head_left.rotation_degrees.y = 36.0
	var head_right := _make_box(arrow, "Head Right", Vector3(0.28, 0.0, -1.0), Vector3(0.16, 0.08, 0.74), marker_material)
	head_right.rotation_degrees.y = -36.0


func _flat_direction(vector: Vector3) -> Vector3:
	var flat := Vector3(vector.x, 0.0, vector.z)
	if flat.length() <= 0.001:
		return Vector3.ZERO
	return flat.normalized()


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _anchor_state_name(state: int) -> String:
	match state:
		AnchorState.IDLE:
			return "READY"
		AnchorState.FLYING:
			return "THROWING"
		AnchorState.SINKING:
			return "SINKING"
		AnchorState.HOOKED:
			return "HOOKED"
		AnchorState.RETRACTING:
			return "RETRACTING"
	return "UNKNOWN"


func _segment_name(segment: int) -> String:
	match segment:
		0:
			return "北岸向东"
		1:
			return "东岸向南"
		2:
			return "南岸向西"
		3:
			return "西岸向北"
	return "未知"

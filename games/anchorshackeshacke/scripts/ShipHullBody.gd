extends RigidBody2D

@export var ship_visual_path: NodePath = NodePath("../PlayerShip/ShipSprite")
@export_file("*.json") var polygon_json_path: String = "res://assets/ship/cruise_hull_polygon.json"
@export var show_debug_polygon: bool = true:
	set(value):
		show_debug_polygon = value
		_refresh_debug_visibility()
@export var debug_color: Color = Color(0.1, 0.9, 0.65, 0.8)
@export var debug_line_width: float = 2.0

var _ship_visual: Node2D
var _collision: CollisionPolygon2D
var _debug_line: Line2D


func _ready() -> void:
	gravity_scale = 0.0
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	lock_rotation = true
	_ship_visual = get_node_or_null(ship_visual_path) as Node2D
	_ensure_nodes()
	_load_polygon()
	_sync_to_ship_visual()


func _physics_process(_delta: float) -> void:
	_sync_to_ship_visual()


func _ensure_nodes() -> void:
	_collision = get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if _collision == null:
		_collision = CollisionPolygon2D.new()
		_collision.name = "CollisionPolygon2D"
		add_child(_collision)

	_debug_line = get_node_or_null("DebugHullLine") as Line2D
	if _debug_line == null:
		_debug_line = Line2D.new()
		_debug_line.name = "DebugHullLine"
		_debug_line.z_index = 100
		add_child(_debug_line)

	_refresh_debug_visibility()


func _load_polygon() -> void:
	var file: FileAccess = FileAccess.open(polygon_json_path, FileAccess.READ)
	if file == null:
		push_warning("Ship hull polygon file missing: %s" % polygon_json_path)
		return

	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("Ship hull polygon JSON is invalid: %s" % polygon_json_path)
		return

	var data: Dictionary = parsed as Dictionary
	var raw_points: Array = data.get("points", []) as Array
	var points := PackedVector2Array()
	for raw_point in raw_points:
		var pair: Array = raw_point as Array
		if pair.size() < 2:
			continue
		points.append(Vector2(float(pair[0]), float(pair[1])))

	if points.size() < 3:
		push_warning("Ship hull polygon has too few points.")
		return

	_collision.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	_collision.polygon = points
	_refresh_debug_line(points)


func _refresh_debug_line(points: PackedVector2Array) -> void:
	if _debug_line == null:
		return

	var line_points := PackedVector2Array(points)
	line_points.append(points[0])
	_debug_line.points = line_points
	_debug_line.default_color = debug_color
	_debug_line.width = debug_line_width
	_refresh_debug_visibility()


func _refresh_debug_visibility() -> void:
	if _debug_line != null:
		_debug_line.visible = show_debug_polygon


func _sync_to_ship_visual() -> void:
	if _ship_visual == null:
		_ship_visual = get_node_or_null(ship_visual_path) as Node2D
	if _ship_visual == null:
		return
	global_transform = _ship_visual.global_transform

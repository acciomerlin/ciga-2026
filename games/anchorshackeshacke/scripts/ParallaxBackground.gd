extends Node2D

const VIEW_SIZE := Vector2(1280.0, 720.0)

@export var ship_path: NodePath = NodePath("..")
@export var travel_scale := 1.0
@export var horizon_y := -72.0

var _ship: Node2D
var _sky_layers := []
var _water_layers := []


func _ready() -> void:
	_ship = get_node_or_null(ship_path) as Node2D
	z_index = -100
	_sky_layers = [
		{
			"texture": preload("res://assets/parallax/pixel_ocean_sky/1.png"),
			"y": -360.0,
			"height": 720.0,
			"factor": 0.08,
			"alpha": 1.0,
			"bob_speed": 0.04,
			"bob": 0.0
		},
		{
			"texture": preload("res://assets/parallax/pixel_ocean_sky/2.png"),
			"y": -360.0,
			"height": 720.0,
			"factor": 0.16,
			"alpha": 0.72,
			"bob_speed": 0.12,
			"bob": 2.0
		},
		{
			"texture": preload("res://assets/parallax/pixel_ocean_sky/3.png"),
			"y": -360.0,
			"height": 720.0,
			"factor": 0.3,
			"alpha": 0.95,
			"bob_speed": 0.2,
			"bob": 4.0
		}
	]
	_water_layers = [
		{
			"texture": preload("res://assets/parallax/preview143-water-far.png"),
			"y": horizon_y + 24.0,
			"height": 122.0,
			"factor": 0.38,
			"alpha": 0.54,
			"bob_speed": 0.45,
			"bob": 1.5
		},
		{
			"texture": preload("res://assets/parallax/preview143-water-mid.png"),
			"y": horizon_y + 122.0,
			"height": 188.0,
			"factor": 0.72,
			"alpha": 0.56,
			"bob_speed": 0.82,
			"bob": 3.0
		},
		{
			"texture": preload("res://assets/parallax/preview143-water-near.png"),
			"y": horizon_y + 292.0,
			"height": 170.0,
			"factor": 1.08,
			"alpha": 0.46,
			"bob_speed": 1.2,
			"bob": 4.0
		}
	]


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var ship_x := 0.0
	if _ship != null:
		ship_x = _ship.global_position.x

	draw_rect(
		Rect2(Vector2(-VIEW_SIZE.x * 0.75, -VIEW_SIZE.y * 0.75), Vector2(VIEW_SIZE.x * 1.5, VIEW_SIZE.y * 2.1)),
		Color("#75add9")
	)

	for layer in _sky_layers:
		_draw_layer(layer, ship_x)
	_draw_ocean_body(ship_x)
	for layer in _water_layers:
		_draw_layer(layer, ship_x)


func _draw_layer(layer: Dictionary, ship_x: float) -> void:
	var texture := layer["texture"] as Texture2D
	var height := float(layer["height"])
	var width := float(texture.get_width()) * height / float(texture.get_height())
	var factor := float(layer["factor"])
	var alpha := float(layer["alpha"])
	var bob := sin(Time.get_ticks_msec() * 0.001 * float(layer["bob_speed"])) * float(layer["bob"])
	var y := float(layer["y"]) + bob
	var scroll := fposmod(ship_x * factor * travel_scale, width)
	var x := -VIEW_SIZE.x * 0.5 - width - scroll
	var end_x := VIEW_SIZE.x * 0.5 + width

	while x < end_x:
		draw_texture_rect(
			texture,
			Rect2(Vector2(x, y), Vector2(width, height)),
			false,
			Color(1.0, 1.0, 1.0, alpha)
		)
		x += width


func _draw_ocean_body(ship_x: float) -> void:
	var top := horizon_y + 8.0
	var bottom := VIEW_SIZE.y * 0.58
	var rect := Rect2(Vector2(-VIEW_SIZE.x * 0.75, top), Vector2(VIEW_SIZE.x * 1.5, bottom - top))
	draw_rect(rect, Color(0.32, 0.61, 0.84, 0.56))

	var line_color := Color(0.83, 0.93, 1.0, 0.22)
	for row in range(8):
		var y := top + 28.0 + row * 34.0
		var points := PackedVector2Array()
		for i in range(34):
			var x := -VIEW_SIZE.x * 0.75 + i * 54.0
			var wave := sin((x + ship_x * (0.18 + row * 0.05)) * 0.018 + row) * (2.0 + row * 0.35)
			points.append(Vector2(x, y + wave))
		draw_polyline(points, line_color, 2.0, true)

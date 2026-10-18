extends Node2D

const VIEW_SIZE := Vector2(1280.0, 720.0)

@export var cover_y := 28.0
@export_range(0.0, 1.0, 0.01) var opacity := 0.7
@export var scroll_factor := 0.86

var _ship: Node2D
var _water_texture := preload("res://assets/parallax/preview143-water-mid.png")


func _ready() -> void:
	_ship = get_parent() as Node2D
	z_index = 30


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var ship_x := 0.0
	if _ship != null:
		ship_x = _ship.global_position.x

	var left := -VIEW_SIZE.x * 0.75
	var top := cover_y
	var bottom := VIEW_SIZE.y * 0.58
	var width := VIEW_SIZE.x * 1.5
	draw_rect(
		Rect2(Vector2(left, top), Vector2(width, bottom - top)),
		Color(0.36, 0.64, 0.86, opacity * 0.62)
	)

	var texture_height := 188.0
	var texture_width := float(_water_texture.get_width()) * texture_height / float(_water_texture.get_height())
	var scroll := fposmod(ship_x * scroll_factor, texture_width)
	var x := left - texture_width - scroll
	while x < left + width + texture_width:
		draw_texture_rect(
			_water_texture,
			Rect2(Vector2(x, top - 8.0), Vector2(texture_width, texture_height)),
			false,
			Color(1.0, 1.0, 1.0, opacity)
		)
		x += texture_width

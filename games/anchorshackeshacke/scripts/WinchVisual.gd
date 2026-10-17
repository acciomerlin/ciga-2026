extends Node2D

const CHAIN_LINK_TEXTURE: Texture2D = preload("res://assets/anchor/chain-link.png")

@export var radius: float = 30.0
@export var chain_link_height: float = 28.0
@export var ink: Color = Color(0.04, 0.04, 0.04, 1.0)
@export var paper: Color = Color(0.96, 0.96, 0.92, 1.0)

var wheel_angle: float = 0.0
var exit_offset: Vector2 = Vector2(-18.0, 21.0)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, paper)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, ink, 6.0)
	draw_arc(Vector2.ZERO, radius * 0.52, 0.0, TAU, 36, ink, 4.0)

	for i in range(10):
		var angle: float = wheel_angle * 0.25 + TAU * float(i) / 10.0
		var link_position: Vector2 = Vector2(cos(angle), sin(angle)) * radius * 0.84
		_draw_link(link_position, chain_link_height, angle, 0.96)

	for i in range(6):
		var spoke_angle: float = wheel_angle + TAU * float(i) / 6.0
		draw_line(
			Vector2(cos(spoke_angle), sin(spoke_angle)) * radius * 0.17,
			Vector2(cos(spoke_angle), sin(spoke_angle)) * radius * 0.72,
			ink,
			4.0
		)

	draw_circle(Vector2.ZERO, radius * 0.16, ink)
	draw_circle(Vector2.ZERO, radius * 0.08, paper)
	_draw_link(exit_offset, chain_link_height * 0.94, exit_offset.angle() - PI * 0.5, 0.98)


func _draw_link(center: Vector2, height: float, rotation: float, alpha: float) -> void:
	var width: float = height * 0.58
	draw_set_transform(center, rotation, Vector2.ONE)
	draw_texture_rect(
		CHAIN_LINK_TEXTURE,
		Rect2(Vector2(-width * 0.5, -height * 0.5), Vector2(width, height)),
		false,
		Color(1.0, 1.0, 1.0, alpha)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

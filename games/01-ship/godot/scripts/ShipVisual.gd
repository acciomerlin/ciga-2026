extends Node2D

@export var bob_amount := 4.0
@export var roll_amount := 0.012

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var ink := Color("#171717")
	var paper := Color(1.0, 0.98, 0.93, 0.94)
	var bob := sin(_time * 1.25) * bob_amount
	var roll := sin(_time * 0.86) * roll_amount

	draw_set_transform(Vector2(0.0, bob), roll, Vector2.ONE)

	var hull := PackedVector2Array([
		Vector2(-360, 70),
		Vector2(-306, 146),
		Vector2(282, 146),
		Vector2(350, 88),
		Vector2(330, 46),
		Vector2(-336, 40),
	])
	draw_colored_polygon(hull, paper)
	_stroke_polygon(hull, ink, 5.0)

	var deck := PackedVector2Array([
		Vector2(-238, -62),
		Vector2(176, -56),
		Vector2(230, 40),
		Vector2(-270, 38),
	])
	draw_colored_polygon(deck, paper)
	_stroke_polygon(deck, ink, 5.0)

	var bridge := PackedVector2Array([
		Vector2(-160, -152),
		Vector2(70, -142),
		Vector2(118, -60),
		Vector2(-188, -62),
	])
	draw_colored_polygon(bridge, paper)
	_stroke_polygon(bridge, ink, 5.0)

	_draw_rect_outline(Rect2(Vector2(-304, 54), Vector2(156, 78)), paper, ink)
	_draw_rect_outline(Rect2(Vector2(-126, 52), Vector2(242, 82)), paper, ink)
	_draw_rect_outline(Rect2(Vector2(136, 54), Vector2(162, 78)), paper, ink)
	_draw_rect_outline(Rect2(Vector2(-128, -126), Vector2(88, 54)), Color(0.9, 0.97, 1.0, 0.34), ink)
	_draw_rect_outline(Rect2(Vector2(-24, -124), Vector2(88, 54)), Color(0.9, 0.97, 1.0, 0.34), ink)

	draw_line(Vector2(-356, 38), Vector2(-420, -10), ink, 5.0, true)
	draw_line(Vector2(-406, -10), Vector2(-256, 18), ink, 5.0, true)
	draw_line(Vector2(314, 70), Vector2(392, 70), ink, 5.0, true)
	draw_line(Vector2(354, 86), Vector2(410, 86), ink, 5.0, true)

	for mast_x in [-40.0, 20.0, 68.0]:
		draw_line(Vector2(mast_x, -146), Vector2(mast_x, -202), ink, 4.0, true)

	draw_arc(Vector2(-286, 22), 28.0, 0.0, TAU, 36, ink, 4.0, true)
	draw_line(Vector2(-314, 22), Vector2(-258, 22), ink, 3.0, true)
	draw_line(Vector2(-286, -6), Vector2(-286, 50), ink, 3.0, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_rect_outline(rect: Rect2, fill: Color, stroke: Color) -> void:
	draw_rect(rect, fill, true)
	draw_rect(rect, stroke, false, 4.0)


func _stroke_polygon(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, color, width, true)

extends Node2D

@onready var start_button: Sprite2D = $Startbutton

const HOVER_SCALE := 1.08
const CLICK_SCALE := 1.16

var _is_starting := false
var _is_hovering := false
var _base_scale := Vector2.ONE
var _hover_tween: Tween


func _ready() -> void:
	set_process_input(true)
	_base_scale = start_button.scale


func _process(_delta: float) -> void:
	if _is_starting:
		return

	var hovering := _is_mouse_on_start_button(get_global_mouse_position())
	if hovering == _is_hovering:
		return

	_is_hovering = hovering
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if _is_hovering else Input.CURSOR_ARROW)
	_tween_button_scale(_base_scale * HOVER_SCALE if _is_hovering else _base_scale, 0.12)


func _input(event: InputEvent) -> void:
	if _is_starting:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _is_mouse_on_start_button(event.position):
			_play_start_animation()


func _is_mouse_on_start_button(mouse_position: Vector2) -> bool:
	if start_button.texture == null:
		return false

	var texture_size := start_button.texture.get_size()
	var local_position := start_button.to_local(mouse_position)
	var button_rect := Rect2(-texture_size * 0.5, texture_size)
	return button_rect.has_point(local_position)


func _play_start_animation() -> void:
	_is_starting = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	if _hover_tween:
		_hover_tween.kill()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(start_button, "scale", _base_scale * CLICK_SCALE, 0.12)
	tween.tween_property(start_button, "scale", _base_scale, 0.08)
	await tween.finished

	get_tree().change_scene_to_file("res://Scenes/comic.tscn")


func _tween_button_scale(target_scale: Vector2, duration: float) -> void:
	if _hover_tween:
		_hover_tween.kill()

	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_QUAD)
	_hover_tween.set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(start_button, "scale", target_scale, duration)

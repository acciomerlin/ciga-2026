extends Node2D

const PAGE_TEXTS: Array[String] = [
	"“这简直是人工智障！”",
	"愚蠢的AI播报员在新闻联播里经常会把事实说跑偏，让观众听得一头雾水。",
	"面对频繁出现的大模型幻觉问题，严谨的新闻事实校对员再也忍不下去了！",
	"把新闻里的错误一一纠正，还大家一档真实可靠的新闻联播吧~"
]

@onready var comics: Array[Sprite2D] = [$Comic1, $Comic2, $Comic3, $Comic4]
@onready var dialogue: RichTextLabel = $Sprite2D/TextureRect/RichTextLabel
@onready var typewriter: TypewriterComponent = $Sprite2D/TextureRect/RichTextLabel/typewriter

var page_index := 0
var typing_finished := false
var _base_scales: Array[Vector2] = []


func _ready() -> void:
	for comic in comics:
		_base_scales.append(comic.scale)

	typewriter.finished.connect(_on_typewriter_finished)
	_show_page(0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if typing_finished:
			_show_page(page_index + 1)
		else:
			typewriter.skip()


func _show_page(next_index: int) -> void:
	if next_index >= comics.size():
		get_tree().change_scene_to_file("res://Scenes/level1.tscn")
		return

	page_index = next_index
	typing_finished = false

	for i in range(comics.size()):
		comics[i].visible = i == page_index
		comics[i].scale = _base_scales[i]

	var current_comic := comics[page_index]
	current_comic.modulate.a = 0.0
	current_comic.scale = _base_scales[page_index] * 0.96

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(current_comic, "modulate:a", 1.0, 0.18)
	tween.tween_property(current_comic, "scale", _base_scales[page_index], 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	dialogue.visible_ratio = 0.0
	typewriter.start(PAGE_TEXTS[page_index], 0.055)


func _on_typewriter_finished() -> void:
	typing_finished = true

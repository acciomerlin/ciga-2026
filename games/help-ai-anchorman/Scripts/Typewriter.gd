extends Node
class_name TypewriterComponent

signal finished
signal char_typed(index: int)

@export_group("Core")
@export_range(0.005, 0.5, 0.005) var speed: float = 0.03
@export_range(0.0, 1.0, 0.01) var punctuation_pause: float = 0.15
@export var auto_start: bool = false

@export_group("Pauses")
@export var punctuations: Array[String] = []

var _timer: Timer
var _target: Control
var _raw_text := ""
var _has_finished := false


func _ready() -> void:
	_target = get_parent()
	if not (_target is Label or _target is RichTextLabel):
		push_error("TypewriterComponent parent must be Label or RichTextLabel.")
		return

	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timer_timeout)

	_target.visible_ratio = 0.0

	if auto_start:
		start()


func start(new_text: String = "", custom_speed: float = -1.0) -> void:
	if not _target:
		return

	if new_text != "":
		_raw_text = new_text
		if _target is RichTextLabel:
			_target.parse_bbcode(new_text)
		else:
			_target.text = new_text

	_has_finished = false
	_target.visible_ratio = 0.0

	if _target.get_total_character_count() == 0:
		_finish()
		return

	var start_speed = custom_speed if custom_speed > 0 else speed
	_timer.start(start_speed)


func skip() -> void:
	if not _timer or not _target or _has_finished:
		return

	_timer.stop()
	_target.visible_ratio = 1.0
	_finish()


func change_speed(new_speed: float) -> void:
	if not _timer:
		return

	var safe_speed = max(0.001, new_speed)
	if _timer.wait_time != safe_speed:
		_timer.wait_time = safe_speed
		if not _timer.is_stopped():
			_timer.start(safe_speed)


func _continue_typing() -> void:
	var total_chars = _target.get_total_character_count()

	if _target.visible_ratio >= 1.0:
		_timer.stop()
		_finish()
		return

	var next_wait_time = speed
	var current_idx = int(_target.visible_ratio * total_chars)
	var plain_text: String = ""
	if _target is RichTextLabel:
		plain_text = _target.get_parsed_text()
	else:
		plain_text = _target.text

	if current_idx < plain_text.length():
		var current_char = plain_text[current_idx]
		if current_char in punctuations:
			next_wait_time += punctuation_pause

	_timer.start(next_wait_time)


func _on_timer_timeout() -> void:
	var total_chars = _target.get_total_character_count()

	if total_chars > 0:
		var step = 1.0 / total_chars
		_target.visible_ratio = min(1.0, _target.visible_ratio + step)
		char_typed.emit(int(_target.visible_ratio * total_chars))

	_continue_typing()


func _finish() -> void:
	if _has_finished:
		return

	_has_finished = true
	finished.emit()

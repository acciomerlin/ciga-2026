extends Node2D

const INTRO_DIALOGUE := "观众朋友们好，欢迎收看今天的[shake rate=24.0 level=7 connected=1]《最新消息，绝无假货》[/shake]（[color=#e5322d]C[/color]urrent [color=#e5322d]i[/color]nfo, [color=#e5322d]G[/color]enuine [color=#e5322d]A[/color]lways）新闻节目，我是你们的主持人德劳克。"
const SECOND_DIALOGUE := "接下来，我将播报近日发生的新鲜事。"
const LOCATION_DIALOGUE := "前天下午，CiGA 万物破元站在广州市天河区天河路533号开启。本次活动吸引了众多游戏开发者踊跃参与。"
const WRONG_PERSON_NAME := "拼命学二郎"
const CORRECT_PERSON_NAME := "拼命玩三郎"
const WRONG_PERSON_DIALOGUE := "本站点的负责人是拼命学二郎。"
const CORRECT_PERSON_DIALOGUE := "本站点的负责人是拼命玩三郎。"
const THEME_HOUR := 15
const THEME_MINUTE := 0
const THEME_DIALOGUE := "下午3点，本次 Game Jam 的主题在万众瞩目中正式公布，那就是——"
const EMOJI_DIALOGUE := ""
const FINAL_DIALOGUE := "此次 Game Jam 活动已经接近尾声，让我们一起期待会诞生哪些好玩的作品吧！"
const WRONG_EMOJI := "🐱"
const CORRECT_EMOJI := "⚓"
const EMOJI_FONT := preload("res://fonts/NotoColorEmoji.ttf")
const CORRECT_CARD_INDEX := 0
const WRONG_CARD_INDEX := 1
const INITIAL_CLOCK_HOUR := 11
const INITIAL_CLOCK_MINUTE := 45

const CARD_HIDDEN_OFFSET := Vector2(0.0, 48.0)
const CARD_HOVER_OFFSET := Vector2(0.0, -12.0)
const CARD_SELECTED_OFFSET := Vector2(0.0, -28.0)
const CARD_HOVER_SCALE := 1.08
const CARD_SELECTED_SCALE := 1.18
const CONFIRM_HOVER_SCALE := 1.08
const CONFIRM_CLICK_SCALE := 1.16

const CLOCK_CENTER := Vector2(-1.0, -5.0)
const MINUTE_HAND_HIT_RADIUS := 92.0

@onready var dialogue_label: RichTextLabel = $TV/Dialogue/RichTextLabel
@onready var typewriter: TypewriterComponent = $TV/Dialogue/RichTextLabel/typewriter
@onready var cross_hand: Sprite2D = $TV/CrossHand
@onready var cards_root: Node2D = $TV/Cards
@onready var correct_card: Sprite2D = $TV/Cards/Correct
@onready var wrong_card: Sprite2D = $TV/Cards/Wrong
@onready var clock_root: Node2D = $TV/Clock
@onready var clock_hour_hand: Sprite2D = $TV/Clock/ClockHour
@onready var clock_minute_hand: Sprite2D = $TV/Clock/ClockMinit
@onready var confirm_button: Button = $TV/ConfirmButton
@onready var confirm_button_sprite: Sprite2D = $TV/Confirmbutton
@onready var answer_input: LineEdit = $TV/AnswerInput
@onready var big_emoji_label: Label = $TV/BigEmoji
@onready var big_emoji_name_label: Label = $TV/BigEmojiName
@onready var emoji_library: GridContainer = $TV/EmojiLibraryGrid
@onready var broadcast_log_label: RichTextLabel = $TV/BroadcastLog


var dialogues: Array[String] = []
var dialogue_index := 0
var theme_dialogue_index := -1
var emoji_dialogue_index := -1
var final_dialogue_index := -1
var typing_finished := false
var settlement_showing := false
var cards_active := false
var cards_animating := false
var hovered_card_index := -1
var selected_card_index := -1
var card_round := 0
var cards: Array[Sprite2D] = []
var card_base_positions: Array[Vector2] = []
var card_base_scales: Array[Vector2] = []
var card_base_rotations: Array[float] = []
var hover_tween: Tween

var clock_editing := false
var dragging_minute_hand := false
var clock_hour_24 := INITIAL_CLOCK_HOUR
var clock_minute := INITIAL_CLOCK_MINUTE
var player_clock_is_correct := false
var map_placeholder_active := false
var player_location_is_correct := false
var text_editing := false
var emoji_editing := false
var player_person_is_correct := false
var player_theme_time_is_correct := false
var player_emoji_is_correct := false
var player_final_text_is_correct := false
var other_correct_was_marked_wrong := false
var submitted_broadcasts: Array[String] = []
var confirm_button_hovering := false
var confirm_button_animating := false
var confirm_button_base_scale := Vector2.ONE
var confirm_button_tween: Tween
var big_emoji_base_position := Vector2.ZERO
var big_emoji_name_base_position := Vector2.ZERO
var emoji_shake_time := 0.0


func _ready() -> void:
	dialogue_label.bbcode_enabled = true
	cross_hand.visible = false
	clock_root.visible = false
	confirm_button.visible = false
	confirm_button_sprite.visible = false
	answer_input.visible = false
	big_emoji_label.visible = false
	big_emoji_name_label.visible = false
	emoji_library.visible = false
	var old_emoji_library := get_node_or_null("TV/EmojiLibrary")
	if old_emoji_library is CanvasItem:
		(old_emoji_library as CanvasItem).visible = false
	broadcast_log_label.text = ""
	big_emoji_base_position = big_emoji_label.position
	big_emoji_name_base_position = big_emoji_name_label.position
	answer_input.text_changed.connect(_on_answer_input_text_changed)
	_connect_emoji_buttons()
	_style_emoji_buttons()
	_apply_emoji_fonts()
	confirm_button_base_scale = confirm_button_sprite.scale
	typewriter.finished.connect(_on_typewriter_finished)

	cards = [correct_card, wrong_card]
	for card in cards:
		card_base_positions.append(card.position)
		card_base_scales.append(card.scale)
		card_base_rotations.append(card.rotation)

	_set_clock_time(INITIAL_CLOCK_HOUR, INITIAL_CLOCK_MINUTE, false)
	_reset_cards_to_hidden()
	_rebuild_dialogues()
	_play_dialogue(0)


func _process(_delta: float) -> void:
	_update_big_emoji_shake(_delta)

	if clock_editing or text_editing or emoji_editing:
		_update_confirm_button_hover()
		return

	if not cards_active or cards_animating:
		return

	var next_hovered_index := _get_card_index_at_position(get_global_mouse_position())
	if next_hovered_index == hovered_card_index:
		return

	_set_hovered_card(next_hovered_index)


func _input(event: InputEvent) -> void:
	if clock_editing or text_editing or emoji_editing:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _is_mouse_on_sprite(confirm_button_sprite, event.position):
				_confirm_button_clicked()
				return

		if clock_editing:
			_handle_clock_input(event)
			if dragging_minute_hand:
				return

		if text_editing or emoji_editing:
			return

	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	if cards_active and not cards_animating:
		var card_index := _get_card_index_at_position(event.position)
		if card_index != -1:
			_select_card(card_index)
		return

	if typing_finished and not clock_editing:
		_play_dialogue(dialogue_index + 1)
	elif not clock_editing:
		typewriter.skip()


func _handle_clock_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_mouse_on_minute_hand(event.position):
			dragging_minute_hand = true
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			_update_clock_from_mouse(event.position)
		elif not event.pressed:
			dragging_minute_hand = false
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	elif event is InputEventMouseMotion and dragging_minute_hand:
		_update_clock_from_mouse(event.position)


func _play_dialogue(next_index: int) -> void:
	if next_index >= dialogues.size():
		return

	dialogue_index = next_index
	typing_finished = false
	typewriter.start(dialogues[dialogue_index], 0.045)


func _on_typewriter_finished() -> void:
	typing_finished = true
	if settlement_showing:
		return

	if dialogue_index == dialogues.size() - 1:
		card_round = _get_card_round_for_dialogue(dialogue_index, dialogues[dialogue_index])
		_show_cards()


func _get_card_round_for_dialogue(index: int, dialogue: String) -> int:
	if dialogue == LOCATION_DIALOGUE:
		return 1
	if dialogue == _build_person_dialogue(WRONG_PERSON_NAME):
		return 2
	if index == theme_dialogue_index:
		return 3
	if dialogue == EMOJI_DIALOGUE:
		return 4
	if index == final_dialogue_index:
		return 5
	return 0


func _rebuild_dialogues() -> void:
	dialogues = [
		INTRO_DIALOGUE,
		SECOND_DIALOGUE,
		_build_time_dialogue()
	]


func _build_time_dialogue() -> String:
	return "现在是北京时间2026年7月5日%s时%s分。" % [_format_two_digits(clock_hour_24), _format_two_digits(clock_minute)]


func _format_two_digits(value: int) -> String:
	return "%02d" % value


func _reset_cards_to_hidden() -> void:
	cards_root.visible = false
	cards_active = false
	cards_animating = false
	hovered_card_index = -1
	selected_card_index = -1
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	for i in range(cards.size()):
		cards[i].position = card_base_positions[i] + CARD_HIDDEN_OFFSET
		cards[i].scale = card_base_scales[i]
		cards[i].rotation = card_base_rotations[i]
		cards[i].modulate.a = 0.0


func _show_cards() -> void:
	cards_root.visible = true
	cards_active = false
	cards_animating = true

	var tween := create_tween()
	tween.set_parallel(true)
	for i in range(cards.size()):
		cards[i].position = card_base_positions[i] + CARD_HIDDEN_OFFSET
		cards[i].scale = card_base_scales[i] * 0.92
		cards[i].rotation = card_base_rotations[i]
		cards[i].modulate.a = 0.0
		tween.tween_property(cards[i], "position", card_base_positions[i], 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.06)
		tween.tween_property(cards[i], "scale", card_base_scales[i], 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.06)
		tween.tween_property(cards[i], "modulate:a", 1.0, 0.18).set_delay(i * 0.06)

	await tween.finished
	cards_animating = false
	cards_active = true


func _select_card(card_index: int) -> void:
	cards_active = false
	cards_animating = true
	selected_card_index = card_index
	cross_hand.visible = card_index == WRONG_CARD_INDEX
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	if hover_tween:
		hover_tween.kill()

	var selected_card := cards[card_index]
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(selected_card, "scale", card_base_scales[card_index] * CARD_SELECTED_SCALE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(selected_card, "position", card_base_positions[card_index] + CARD_SELECTED_OFFSET, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(selected_card, "rotation", card_base_rotations[card_index] + 0.08, 0.08)
	tween.tween_property(selected_card, "rotation", card_base_rotations[card_index], 0.08)
	tween.tween_interval(0.08)
	await tween.finished

	await _hide_cards()
	if card_index == CORRECT_CARD_INDEX:
		_record_current_broadcast()
		_advance_after_correct_selection()
	elif card_index == WRONG_CARD_INDEX and (card_round == 0 or card_round == 3):
		_start_clock_editing()
	elif card_index == WRONG_CARD_INDEX and card_round == 1:
		_start_text_editing()
	elif card_index == WRONG_CARD_INDEX and card_round == 2:
		_start_text_editing()
	elif card_index == WRONG_CARD_INDEX and card_round == 4:
		_start_emoji_editing()
	elif card_index == WRONG_CARD_INDEX and card_round == 5:
		other_correct_was_marked_wrong = true
		_start_text_editing()
	elif card_round == 1:
		other_correct_was_marked_wrong = true
		_start_map_placeholder(card_index)


func _hide_cards() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	for i in range(cards.size()):
		tween.tween_property(cards[i], "position", card_base_positions[i] + CARD_HIDDEN_OFFSET, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(i * 0.03)
		tween.tween_property(cards[i], "scale", card_base_scales[i] * 0.9, 0.22).set_delay(i * 0.03)
		tween.tween_property(cards[i], "modulate:a", 0.0, 0.18).set_delay(i * 0.03)

	await tween.finished
	_reset_cards_to_hidden()


func _set_hovered_card(next_hovered_index: int) -> void:
	if hover_tween:
		hover_tween.kill()

	hovered_card_index = next_hovered_index
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered_card_index != -1 else Input.CURSOR_ARROW)

	hover_tween = create_tween()
	hover_tween.set_parallel(true)
	for i in range(cards.size()):
		var target_scale := card_base_scales[i]
		var target_rotation := card_base_rotations[i]
		var target_position := card_base_positions[i]
		if i == hovered_card_index:
			target_scale = card_base_scales[i] * CARD_HOVER_SCALE
			target_rotation = card_base_rotations[i] * 0.75
			target_position = card_base_positions[i] + CARD_HOVER_OFFSET

		hover_tween.tween_property(cards[i], "scale", target_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hover_tween.tween_property(cards[i], "rotation", target_rotation, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hover_tween.tween_property(cards[i], "position", target_position, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _start_clock_editing() -> void:
	clock_editing = true
	dragging_minute_hand = false
	clock_root.visible = true
	confirm_button.visible = false
	confirm_button_sprite.visible = true
	confirm_button_sprite.scale = confirm_button_base_scale
	if card_round == 3:
		_set_clock_time(THEME_HOUR, THEME_MINUTE, false)
	dialogue_label.visible_ratio = 1.0
	dialogue_label.parse_bbcode(_build_active_clock_dialogue())


func _update_clock_from_mouse(mouse_position: Vector2) -> void:
	var local_position := clock_root.to_local(mouse_position) - CLOCK_CENTER
	var angle := atan2(local_position.x, -local_position.y)
	if angle < 0.0:
		angle += TAU

	var next_minute := int(round(angle / TAU * 60.0)) % 60
	var delta := next_minute - clock_minute
	if delta > 30:
		delta -= 60
	elif delta < -30:
		delta += 60

	clock_hour_24 = posmod(clock_hour_24 + int(floor(float(clock_minute + delta) / 60.0)), 24)
	_set_clock_time(clock_hour_24, next_minute, true)


func _set_clock_time(hour_24: int, minute: int, update_dialogue: bool) -> void:
	clock_hour_24 = posmod(hour_24, 24)
	clock_minute = posmod(minute, 60)

	clock_minute_hand.rotation = float(clock_minute) / 60.0 * TAU
	clock_hour_hand.rotation = (float(clock_hour_24 % 12) + float(clock_minute) / 60.0) / 12.0 * TAU

	if update_dialogue:
		var clock_dialogue := _build_active_clock_dialogue()
		dialogues[dialogue_index] = clock_dialogue
		dialogue_label.visible_ratio = 1.0
		dialogue_label.parse_bbcode(clock_dialogue)


func _on_confirm_button_pressed() -> void:
	if text_editing:
		_finish_text_editing()
		return
	if emoji_editing:
		_finish_emoji_editing()
		return

	var system_time := Time.get_datetime_dict_from_system(false)
	var clock_answer_is_correct := clock_hour_24 == int(system_time.hour) and clock_minute == int(system_time.minute)
	if card_round == 3:
		player_theme_time_is_correct = clock_hour_24 == THEME_HOUR and clock_minute == THEME_MINUTE
	else:
		player_clock_is_correct = clock_answer_is_correct
	clock_editing = false
	dragging_minute_hand = false
	cross_hand.visible = false
	clock_root.visible = false
	confirm_button.visible = false
	confirm_button_sprite.visible = false
	confirm_button_hovering = false
	confirm_button_animating = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_record_current_broadcast()

	if card_round == 3:
		_play_emoji_dialogue()
	else:
		_play_location_dialogue()


func _finish_text_editing() -> void:
	var answer := answer_input.text.strip_edges()
	if card_round == 5:
		player_final_text_is_correct = answer == FINAL_DIALOGUE
	else:
		player_person_is_correct = answer == CORRECT_PERSON_DIALOGUE or answer == CORRECT_PERSON_NAME

	text_editing = false
	cross_hand.visible = false
	answer_input.visible = false
	confirm_button.visible = false
	confirm_button_sprite.visible = false
	confirm_button_hovering = false
	confirm_button_animating = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_record_current_broadcast()
	if card_round == 5:
		_show_settlement()
	else:
		_play_theme_dialogue()


func _confirm_button_clicked() -> void:
	if confirm_button_animating:
		return

	confirm_button_animating = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if confirm_button_tween:
		confirm_button_tween.kill()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(confirm_button_sprite, "scale", confirm_button_base_scale * CONFIRM_CLICK_SCALE, 0.12)
	tween.tween_property(confirm_button_sprite, "scale", confirm_button_base_scale, 0.08)
	await tween.finished
	_on_confirm_button_pressed()


func _update_confirm_button_hover() -> void:
	if confirm_button_animating or not confirm_button_sprite.visible:
		return

	var hovering := _is_mouse_on_sprite(confirm_button_sprite, get_global_mouse_position())
	if hovering == confirm_button_hovering:
		return

	confirm_button_hovering = hovering
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if confirm_button_hovering else Input.CURSOR_ARROW)
	_tween_confirm_button_scale(confirm_button_base_scale * CONFIRM_HOVER_SCALE if confirm_button_hovering else confirm_button_base_scale, 0.12)


func _tween_confirm_button_scale(target_scale: Vector2, duration: float) -> void:
	if confirm_button_tween:
		confirm_button_tween.kill()

	confirm_button_tween = create_tween()
	confirm_button_tween.set_trans(Tween.TRANS_QUAD)
	confirm_button_tween.set_ease(Tween.EASE_OUT)
	confirm_button_tween.tween_property(confirm_button_sprite, "scale", target_scale, duration)


func _advance_after_correct_selection() -> void:
	cross_hand.visible = false
	if card_round == 0:
		_play_location_dialogue()
	elif card_round == 1:
		player_location_is_correct = true
		_play_person_dialogue()
	elif card_round == 2:
		_play_theme_dialogue()
	elif card_round == 3:
		player_theme_time_is_correct = true
		_play_emoji_dialogue()
	elif card_round == 4:
		player_emoji_is_correct = false
		_play_final_dialogue()
	elif card_round == 5:
		player_final_text_is_correct = true
		_show_settlement()
	else:
		_start_map_placeholder(CORRECT_CARD_INDEX)


func _play_location_dialogue() -> void:
	if dialogues.back() != LOCATION_DIALOGUE:
		dialogues.append(LOCATION_DIALOGUE)
	_play_dialogue(dialogues.size() - 1)


func _play_person_dialogue() -> void:
	var person_dialogue := _build_person_dialogue(WRONG_PERSON_NAME)
	if dialogues.back() != person_dialogue:
		dialogues.append(person_dialogue)
	_play_dialogue(dialogues.size() - 1)


func _play_theme_dialogue() -> void:
	if theme_dialogue_index == -1:
		dialogues.append(THEME_DIALOGUE)
		theme_dialogue_index = dialogues.size() - 1
	else:
		dialogues[theme_dialogue_index] = THEME_DIALOGUE

	_play_dialogue(theme_dialogue_index)


func _play_emoji_dialogue() -> void:
	big_emoji_label.text = WRONG_EMOJI
	big_emoji_label.visible = true
	big_emoji_name_label.text = _get_emoji_name(WRONG_EMOJI)
	big_emoji_name_label.visible = true

	if emoji_dialogue_index == -1:
		dialogues.append(EMOJI_DIALOGUE)
		emoji_dialogue_index = dialogues.size() - 1
	else:
		dialogues[emoji_dialogue_index] = EMOJI_DIALOGUE

	dialogue_index = emoji_dialogue_index
	typing_finished = true
	card_round = 4
	dialogue_label.text = ""
	dialogue_label.visible_ratio = 1.0
	_show_cards()


func _play_final_dialogue() -> void:
	big_emoji_label.visible = false
	big_emoji_name_label.visible = false
	emoji_library.visible = false
	if final_dialogue_index == -1:
		dialogues.append(FINAL_DIALOGUE)
		final_dialogue_index = dialogues.size() - 1
	else:
		dialogues[final_dialogue_index] = FINAL_DIALOGUE

	_play_dialogue(final_dialogue_index)

@onready var summary: RichTextLabel = $TV/summary

func _show_settlement() -> void:
	settlement_showing = true
	cards_root.visible = false
	clock_root.visible = false
	answer_input.visible = false
	emoji_library.visible = false
	confirm_button.visible = false
	confirm_button_sprite.visible = false
	cross_hand.visible = false
	big_emoji_label.visible = false
	big_emoji_name_label.visible = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	dialogue_label.visible_ratio = 0.0
	summary.text = _build_settlement_text()

@onready var earth: Sprite2D = $TV/Earth
@onready var live_room: Sprite2D = $TV/LiveRoom
@onready var dialogue: Sprite2D = $TV/Dialogue



func _build_settlement_text() -> String:
	earth.hide()
	live_room.hide()
	dialogue.hide()
	var feedbacks: Array[String] = []
	if not player_clock_is_correct:
		feedbacks.append("直播开始的时间好像不太对，难道我穿越了？")
	if not player_person_is_correct:
		feedbacks.append("负责人的名字为什么和我记忆中的不一样？")
	if not player_theme_time_is_correct:
		feedbacks.append("奇怪，我记得这次 Game Jam 的主题好像不是这个？")

	var other_is_wrong := other_correct_was_marked_wrong or not player_location_is_correct or not player_emoji_is_correct or not player_final_text_is_correct
	if other_is_wrong:
		feedbacks.append("其他的也有点怪怪的......")

	var wrong_count := _count_wrong_answers()
	var rating := _get_rating(wrong_count)
	var result_text := "观众反馈：\n"
	if feedbacks.is_empty():
		result_text += "新闻播报准确可靠，观众非常满意！"
	else:
		for feedback in feedbacks:
			result_text += feedback + "\n"

	result_text += "\n最终评级：" + rating
	return result_text


func _count_wrong_answers() -> int:
	var wrong_count := 0
	if not player_clock_is_correct:
		wrong_count += 1
	if not player_location_is_correct:
		wrong_count += 1
	if not player_person_is_correct:
		wrong_count += 1
	if not player_theme_time_is_correct:
		wrong_count += 1
	if not player_emoji_is_correct:
		wrong_count += 1
	if not player_final_text_is_correct:
		wrong_count += 1
	if other_correct_was_marked_wrong and player_location_is_correct and player_final_text_is_correct:
		wrong_count += 1
	return wrong_count


func _get_rating(wrong_count: int) -> String:
	match wrong_count:
		0:
			return "S"
		1:
			return "A"
		2:
			return "B"
		3:
			return "C"
		4:
			return "D"
		_:
			return "F"


func _start_emoji_editing() -> void:
	emoji_editing = true
	emoji_library.visible = true
	big_emoji_label.visible = true
	big_emoji_label.text = WRONG_EMOJI
	big_emoji_name_label.visible = true
	big_emoji_name_label.text = _get_emoji_name(WRONG_EMOJI)
	confirm_button.visible = false
	confirm_button_sprite.visible = true
	confirm_button_sprite.scale = confirm_button_base_scale


func _select_emoji(value: String) -> void:
	if not emoji_editing:
		return

	big_emoji_label.text = value
	big_emoji_name_label.text = _get_emoji_name(value)
	player_emoji_is_correct = value == CORRECT_EMOJI


func _finish_emoji_editing() -> void:
	player_emoji_is_correct = big_emoji_label.text == CORRECT_EMOJI
	emoji_editing = false
	emoji_library.visible = false
	cross_hand.visible = false
	confirm_button.visible = false
	confirm_button_sprite.visible = false
	confirm_button_hovering = false
	confirm_button_animating = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_record_current_broadcast()
	_play_final_dialogue()


func _connect_emoji_buttons() -> void:
	for child in emoji_library.get_children():
		if child is Button:
			var emoji_button := child as Button
			emoji_button.pressed.connect(_select_emoji.bind(emoji_button.text))


func _style_emoji_buttons() -> void:
	var border_texture := load("res://assets/boarder.png") as Texture2D
	if border_texture == null:
		return

	for child in emoji_library.get_children():
		if child is Button:
			var emoji_button := child as Button
			var normal_style := _make_emoji_button_style(border_texture)
			var hover_style := _make_emoji_button_style(border_texture)
			var pressed_style := _make_emoji_button_style(border_texture)
			var focus_style := StyleBoxEmpty.new()
			emoji_button.add_theme_stylebox_override("normal", normal_style)
			emoji_button.add_theme_stylebox_override("hover", hover_style)
			emoji_button.add_theme_stylebox_override("pressed", pressed_style)
			emoji_button.add_theme_stylebox_override("focus", focus_style)


func _apply_emoji_fonts() -> void:
	big_emoji_label.add_theme_font_override("font", EMOJI_FONT)
	for child in emoji_library.get_children():
		if child is Button:
			(child as Button).add_theme_font_override("font", EMOJI_FONT)

	var old_emoji_library := get_node_or_null("TV/EmojiLibrary")
	if old_emoji_library == null:
		return
	for child in old_emoji_library.get_children():
		if child is Button:
			(child as Button).add_theme_font_override("font", EMOJI_FONT)


func _make_emoji_button_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style


func _update_big_emoji_shake(delta: float) -> void:
	if not big_emoji_label.visible:
		big_emoji_label.position = big_emoji_base_position
		big_emoji_name_label.position = big_emoji_name_base_position
		emoji_shake_time = 0.0
		return

	emoji_shake_time += delta
	var emoji_offset := Vector2(sin(emoji_shake_time * 34.0) * 2.5, cos(emoji_shake_time * 29.0) * 1.6)
	var name_offset := Vector2(cos(emoji_shake_time * 31.0) * 1.7, sin(emoji_shake_time * 27.0) * 1.2)
	big_emoji_label.position = big_emoji_base_position + emoji_offset
	big_emoji_name_label.position = big_emoji_name_base_position + name_offset


func _get_emoji_name(value: String) -> String:
	match value:
		"🐱":
			return "CAT！"
		"⚓":
			return "ANCHOR！"
		"⭐":
			return "STAR！"
		"🐶":
			return "DOG！"
		"🔥":
			return "FIRE！"
		"❤️":
			return "HEART！"
		"🎮":
			return "GAME！"
		"🚀":
			return "ROCKET！"
		"🏆":
			return "TROPHY！"
		"☀️":
			return "SUN！"
		"🌙":
			return "MOON！"
		"🌊":
			return "WAVE！"
		"🗺️":
			return "MAP！"
		"💡":
			return "IDEA！"
		"📰":
			return "NEWS！"
		_:
			return "ITEM！"


func _record_current_broadcast() -> void:
	var current_text := _get_current_broadcast_text()
	if current_text.strip_edges() == "":
		return

	submitted_broadcasts.append(current_text)
	var log_text := ""
	for i in range(submitted_broadcasts.size()):
		if i > 0:
			log_text += "\n\n"
		log_text += submitted_broadcasts[i]

	broadcast_log_label.text = ""
	if log_text != "":
		broadcast_log_label.text += "\n\n" + log_text
		await get_tree().process_frame
		broadcast_log_label.scroll_to_line(broadcast_log_label.get_line_count())


func _get_current_broadcast_text() -> String:
	if card_round == 4 or emoji_editing:
		return big_emoji_name_label.text
	if text_editing:
		return answer_input.text
	if dialogue_label is RichTextLabel:
		return dialogue_label.get_parsed_text()
	return dialogue_label.text


func _build_active_clock_dialogue() -> String:
	if card_round == 3:
		return _build_theme_dialogue()
	return _build_time_dialogue()


func _build_theme_dialogue() -> String:
	return "下午%s，本次 Game Jam 的主题在万众瞩目中正式公布，那就是——" % _format_clock_time_for_theme()


func _format_clock_time_for_theme() -> String:
	var display_hour := clock_hour_24 % 12
	if display_hour == 0:
		display_hour = 12

	if clock_minute == 0:
		return "%d点" % display_hour

	return "%d点%s分" % [display_hour, _format_two_digits(clock_minute)]


func _build_person_dialogue(person_name: String) -> String:
	return "本站点的负责人是%s。" % person_name


func _start_text_editing() -> void:
	text_editing = true
	answer_input.visible = true
	if card_round == 5:
		answer_input.text = FINAL_DIALOGUE
	elif card_round == 1:
		answer_input.text = LOCATION_DIALOGUE
	else:
		answer_input.text = WRONG_PERSON_DIALOGUE
	answer_input.grab_focus()
	confirm_button.visible = false
	confirm_button_sprite.visible = true
	confirm_button_sprite.scale = confirm_button_base_scale
	dialogue_label.visible_ratio = 1.0
	dialogue_label.parse_bbcode(answer_input.text)


func _on_answer_input_text_changed(new_text: String) -> void:
	if not text_editing:
		return

	var person_dialogue := new_text
	dialogues[dialogue_index] = person_dialogue
	dialogue_label.visible_ratio = 1.0
	dialogue_label.parse_bbcode(person_dialogue)


func _start_map_placeholder(card_index: int) -> void:
	map_placeholder_active = card_index == WRONG_CARD_INDEX
	player_location_is_correct = card_index != WRONG_CARD_INDEX


func _get_card_index_at_position(mouse_position: Vector2) -> int:
	for i in range(cards.size() - 1, -1, -1):
		if _is_mouse_on_sprite(cards[i], mouse_position):
			return i

	return -1


func _is_mouse_on_minute_hand(mouse_position: Vector2) -> bool:
	var local_position := clock_root.to_local(mouse_position)
	return local_position.distance_to(CLOCK_CENTER) <= MINUTE_HAND_HIT_RADIUS


func _is_mouse_on_sprite(sprite: Sprite2D, mouse_position: Vector2) -> bool:
	if sprite.texture == null:
		return false

	var texture_size := sprite.texture.get_size()
	var local_position := sprite.to_local(mouse_position)
	var sprite_rect := Rect2(-texture_size * 0.5, texture_size)
	return sprite_rect.has_point(local_position)

extends Control

const Night := preload("res://src/night.gd")
const Minimap := preload("res://src/minimap.gd")
const GOLD := Color("f7c77e")
const PAPER := Color("f8e9d0")
const AQUA := Color("a1dcd0")
const MUTED := Color("a8b9bf")
const VIOLET := Color("d5a9f4")

signal restart_requested

var _flames: Label
var _carry: Label
var _score: Label
var _clock: Label
var _lamps: Label
var _prompt: Label
var _prompt_panel: PanelContainer
var _toast: Label
var _minimap: Minimap
var _result: ColorRect
var _result_title: Label
var _result_text: Label
var _restart: Button
var _serif := SystemFont.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_serif.font_names = PackedStringArray(["Times New Roman", "Liberation Serif", "DejaVu Serif"])
	_make_title()
	_make_status()
	_make_map()
	_make_help()
	_make_result()


func update_night(night: Night, yaw: float, toast: String) -> void:
	_flames.text = "✦ ".repeat(night.flames) + "◇ ".repeat(maxi(0, int(night.tuning.flames) - night.flames))
	_carry.text = "%02d / %02d" % [night.carried, int(night.tuning.carry_capacity)]
	_score.text = "%04d" % night.score
	var seconds := ceili(night.time_left())
	_clock.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	_clock.add_theme_color_override("font_color", VIOLET if seconds <= 30 else PAPER)
	_lamps.text = "ĐÈN LỒNG   %d / %d" % [night.lit_count(), night.lanterns.size()]
	_toast.text = toast
	_minimap.night = night
	_minimap.yaw = yaw
	_minimap.queue_redraw()
	var lantern := night.nearest_lantern()
	_prompt_panel.visible = night.state == "playing" and not lantern.is_empty()
	if _prompt_panel.visible:
		var progress := "%d/%d" % [lantern.deposited, int(night.tuning.lantern_cost)]
		_prompt.text = "E    Nạp đèn %s   ·   %s" % [lantern.id, progress] if night.carried > 0 \
			else "Đèn %s   ·   %s   ·   Cần đom đóm" % [lantern.id, progress]


func show_result(night: Night, reason: String) -> void:
	var won := night.state == "won"
	_result_title.text = "Đảo đã sáng" if won else "Đêm khép lại"
	var detail: String = {
		"all_lit": "Mây đã thắp sáng cả năm Đèn Lồng Lớn.",
		"no_flames": "Bóng Mực đã làm tắt ngọn lửa cuối cùng của Mây.",
		"dawn": "Bình minh đến khi đảo vẫn còn đèn chưa sáng.",
	}.get(reason, "")
	_result_text.text = "%s\n\n%d điểm   ·   %d/%d đèn sáng" % [detail, night.score, night.lit_count(), night.lanterns.size()]
	_result.visible = true
	_restart.grab_focus()


func hide_result() -> void:
	_result.visible = false


func _make_title() -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	_place(stack, Vector2.ZERO, Rect2(31, 23, 320, 145))
	var chapter := _label("ĐÊM 1  /  ĐẢO BẾN", 13, AQUA)
	stack.add_child(chapter)
	var title := _label("Đảo Đèn Lồng", 35, PAPER)
	title.add_theme_font_override("font", _serif)
	stack.add_child(title)
	var card := _panel()
	stack.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 27)
	card.add_child(row)
	var health := VBoxContainer.new()
	var load := VBoxContainer.new()
	row.add_child(health)
	row.add_child(load)
	health.add_child(_label("NGỌN LỬA", 11, MUTED))
	_flames = _label("", 22, GOLD)
	health.add_child(_flames)
	load.add_child(_label("ĐOM ĐÓM", 11, MUTED))
	_carry = _label("", 22, GOLD)
	load.add_child(_carry)


func _make_status() -> void:
	var card := _panel()
	_place(card, Vector2(1, 0), Rect2(-238, 28, 207, 104))
	var stack := VBoxContainer.new()
	card.add_child(stack)
	var values := HBoxContainer.new()
	values.add_theme_constant_override("separation", 23)
	stack.add_child(values)
	var countdown := VBoxContainer.new()
	var score_stack := VBoxContainer.new()
	values.add_child(countdown)
	values.add_child(score_stack)
	countdown.add_child(_label("TỚI BÌNH MINH", 11, MUTED))
	_clock = _label("", 23, PAPER)
	countdown.add_child(_clock)
	score_stack.add_child(_label("ĐIỂM", 11, MUTED))
	_score = _label("", 23, PAPER)
	score_stack.add_child(_score)
	_lamps = _label("", 13, AQUA)
	stack.add_child(_lamps)


func _make_map() -> void:
	var card := _panel()
	_place(card, Vector2.ONE, Rect2(-197, -205, 166, 178))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	card.add_child(stack)
	var map_title := _label("BẢN ĐỒ ĐẢO", 11, AQUA)
	map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(map_title)
	_minimap = Minimap.new()
	_minimap.custom_minimum_size = Vector2(132, 132)
	_minimap.size_flags_vertical = SIZE_EXPAND_FILL
	_minimap.mouse_filter = MOUSE_FILTER_IGNORE
	stack.add_child(_minimap)


func _make_help() -> void:
	var card := _panel()
	_place(card, Vector2(0, 1), Rect2(31, -72, 570, 45))
	var help := _label("WASD  Đi    ·    Chuột  Camera    ·    Space  Nhảy    ·    E  Nạp đèn    ·    Q  Tỏa sáng", 14, PAPER)
	card.add_child(help)
	_prompt_panel = _panel()
	_place(_prompt_panel, Vector2(0.5, 1), Rect2(-163, -136, 326, 47))
	_prompt = _label("", 17, GOLD)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_panel.add_child(_prompt)
	_toast = _label("", 17, PAPER)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_shadow_color", Color("121828"))
	_toast.add_theme_constant_override("shadow_offset_y", 2)
	_place(_toast, Vector2(0.5, 0), Rect2(-235, 33, 470, 36))


func _make_result() -> void:
	_result = ColorRect.new()
	_result.color = Color(0.045, 0.065, 0.11, 0.70)
	add_child(_result)
	_result.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var card := _panel(25)
	_result.add_child(card)
	card.set_anchors_and_offsets_preset(PRESET_CENTER)
	card.offset_left = -269
	card.offset_right = 269
	card.offset_top = -147
	card.offset_bottom = 147
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 15)
	card.add_child(stack)
	_result_title = _label("", 48, GOLD)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_font_override("font", _serif)
	stack.add_child(_result_title)
	_result_text = _label("", 17, PAPER)
	_result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_result_text)
	_restart = Button.new()
	_restart.text = "Chơi lại  ·  R"
	_restart.custom_minimum_size = Vector2(166, 42)
	_restart.size_flags_horizontal = SIZE_SHRINK_CENTER
	_restart.add_theme_color_override("font_color", Color("272130"))
	_restart.add_theme_color_override("font_hover_color", Color("272130"))
	_restart.add_theme_color_override("font_focus_color", Color("272130"))
	_restart.add_theme_stylebox_override("normal", _box_style(GOLD, GOLD, 5, 8))
	_restart.add_theme_stylebox_override("hover", _box_style(PAPER, PAPER, 5, 8))
	_restart.pressed.connect(func() -> void: restart_requested.emit())
	stack.add_child(_restart)
	_result.hide()


func _place(node: Control, anchor: Vector2, rect: Rect2) -> void:
	add_child(node)
	node.anchor_left = anchor.x
	node.anchor_right = anchor.x
	node.anchor_top = anchor.y
	node.anchor_bottom = anchor.y
	node.offset_left = rect.position.x
	node.offset_top = rect.position.y
	node.offset_right = rect.end.x
	node.offset_bottom = rect.end.y


func _panel(padding: int = 13) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box_style(Color(0.049, 0.082, 0.13, 0.94), Color("3e5261"), 8, padding))
	return panel


func _box_style(fill: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding * 0.72
	style.content_margin_bottom = padding * 0.72
	return style


func _label(value: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	return label

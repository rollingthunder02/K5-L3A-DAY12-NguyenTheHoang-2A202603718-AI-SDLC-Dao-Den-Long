extends Control

const Night := preload("res://src/night.gd")
const Map := preload("res://src/island_map.gd")
const Minimap := preload("res://src/minimap.gd")
const GOLD := Color("f2c14e")
const PAPER := Color("f5f1e6")
const AQUA := Color("a1dcd0")
const MUTED := Color("a8b9bf")
const DANGER := Color("ff5a5f")


class WarningMark extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(18, 18)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := size * 0.5
		var triangle := PackedVector2Array([center + Vector2(0, -8), center + Vector2(-8.5, 7), center + Vector2(8.5, 7)])
		draw_colored_polygon(triangle, Color.WHITE)
		draw_line(center + Vector2(0, -2.5), center + Vector2(0, 1.0), Color("10192a"), 1.8, true)
		draw_circle(center + Vector2(0, 4.0), 0.95, Color("10192a"), true, -1.0, true)


signal action_requested(action: String)
signal setting_changed(key: String, value: Variant)

var mode := ""
var accessible_palette := false
var _hud: Control
var _veil: ColorRect
var _panel_content: CenterContainer
var _flames: Label
var _chapter: Label
var _score: Label
var _clock: Label
var _lamps: Label
var _prompt: Label
var _clock_icon: WarningMark
var _prompt_icon: WarningMark
var _toast_icon: WarningMark
var _toast: Label
var _charm: Label
var _inventory_count: Label
var _dash: Label
var _pulse: Label
var _marker: Label
var _minimap: Minimap
var _cells: Array[ColorRect] = []
var _serif := SystemFont.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_serif.font_names = PackedStringArray(["Times New Roman", "Liberation Serif", "DejaVu Serif"])
	_hud = Control.new()
	_hud.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_hud)
	_hud.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_make_hud()
	_veil = ColorRect.new()
	_veil.color = Color(0.034, 0.043, 0.093, 0.70)
	add_child(_veil)
	_veil.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_panel_content = CenterContainer.new()
	_veil.add_child(_panel_content)
	_panel_content.set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func update_night(night: Night, yaw: float, toast: String, warn_toast: bool = false) -> void:
	_chapter.text = "ĐÊM %d  /  %s" % [night.number, Map.NAMES[night.number - 1].to_upper()]
	_flames.text = "✦ ".repeat(night.flames) + "◇ ".repeat(maxi(0, int(night.tuning.flames) - night.flames))
	_score.text = "%04d ĐIỂM" % night.score
	var seconds := ceili(night.time_left())
	_clock.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	_clock.modulate.a = 0.51 if seconds <= 30 and night.sim_tick % 60 >= 30 else 1.0
	_clock_icon.visible = accessible_palette and seconds <= 30
	_clock_icon.modulate.a = _clock.modulate.a
	_clock.add_theme_color_override("font_color", _danger_color() if seconds <= 30 else PAPER)
	_lamps.text = "ĐÈN SÁNG  %d/%d\nCẦN %d ĐẾN BÌNH MINH" % [night.lit_count(), night.lanterns.size(), night.required_lamps()]
	var capacity := night.capacity()
	_inventory_count.text = "ĐOM ĐÓM   %d / %d" % [night.carried, capacity]
	for index in range(_cells.size()):
		_cells[index].visible = index < capacity
		_cells[index].color = GOLD if index < night.carried else Color("3b4856")
	_dash.text = "⇥  LƯỚT   %.1f s" % night.dash_cooldown() if night.dash_cooldown() > 0.0 else "⇥  LƯỚT   Sẵn sàng"
	_pulse.text = "✦  TỎA SÁNG   %.1f s" % night.pulse_cooldown() if night.pulse_cooldown() > 0.0 else "✦  TỎA SÁNG   %s" % ("Sẵn sàng" if night.carried >= 3 else "Cần 3 đốm")
	_charm.text = "BÙA GIÓ   %.1f s" % night.charm_left() if night.charm_left() > 0.0 else ""
	_toast.text = toast
	_toast_icon.visible = accessible_palette and warn_toast and not toast.is_empty()
	_toast.add_theme_color_override("font_color", _danger_color() if warn_toast else PAPER)
	_minimap.night = night
	_minimap.yaw = yaw
	_minimap.accessible_palette = accessible_palette
	_minimap.queue_redraw()
	var lantern := night.nearest_lantern()
	_prompt.visible = night.state == "playing" and not lantern.is_empty() and night.respawn_at == 0
	_prompt_icon.visible = false
	if _prompt.visible:
		var weak := night.lamp_is_weak(lantern)
		_prompt_icon.visible = accessible_palette and weak
		_prompt.add_theme_color_override("font_color", _danger_color() if weak else GOLD)
		if lantern.lit:
			_prompt.text = "E — Châm dầu (%d%%)" % floori(night.lamp_fuel(lantern))
		else:
			var action := "Thắp lại" if lantern.ever_lit else "Nạp ánh sáng"
			_prompt.text = "E — %s (%d/%d)" % [action, lantern.deposited, night.light_cost(lantern)]


func _danger_color() -> Color:
	return Color.WHITE if accessible_palette else DANGER


func update_marker(camera: Camera3D, night: Night) -> void:
	var target := night.nearest_lantern(false, false)
	_marker.hide()
	if mode != "play" or target.is_empty():
		return
	var point: Vector3 = target.pos + Vector3.UP * 2.1
	var projected := camera.unproject_position(point)
	var rect := Rect2(Vector2(68, 110), size - Vector2(136, 220))
	var behind := camera.is_position_behind(point)
	if not behind and get_viewport_rect().has_point(projected):
		return
	var center := size * 0.5
	var heading := projected - center
	if behind:
		var side := camera.to_local(point).x
		heading = Vector2(side, maxf(absf(side) * 0.4, 1.0))
	_marker.position = Vector2(clampf(center.x + heading.normalized().x * size.x, rect.position.x, rect.end.x),
		clampf(center.y + heading.normalized().y * size.y, rect.position.y, rect.end.y)) - _marker.size * 0.5
	_marker.pivot_offset = _marker.size * 0.5
	_marker.rotation = heading.angle()
	_marker.show()


func show_play() -> void:
	mode = "play"
	_hud.show()
	_veil.hide()


func show_panel(page: String, eyebrow: String, title: String, message: String, actions: Array,
		options: Dictionary = {}) -> void:
	mode = page
	_marker.hide()
	_hud.visible = page in ["pause", "result"]
	for child in _panel_content.get_children():
		_panel_content.remove_child(child)
		child.queue_free()
	var card := _card(30)
	card.custom_minimum_size = Vector2(530, 0)
	_panel_content.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 13)
	card.add_child(stack)
	var kicker := _centered_label(eyebrow, 13, AQUA)
	stack.add_child(kicker)
	var heading := _centered_label(title, 53, GOLD)
	heading.add_theme_font_override("font", _serif)
	stack.add_child(heading)
	if not message.is_empty():
		var body := _centered_label(message, 17, PAPER)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = 470
		stack.add_child(body)
	if page == "settings":
		_add_slider(stack, "Âm lượng", "volume", options.volume, 0.0, 1.0)
		_add_slider(stack, "Độ nhạy chuột", "sensitivity", options.sensitivity, 0.3, 2.0)
		var toggle := CheckButton.new()
		toggle.text = "Bảng màu dễ phân biệt"
		toggle.button_pressed = options.get("accessible_palette", false)
		toggle.toggled.connect(func(enabled: bool) -> void: setting_changed.emit("accessible_palette", enabled))
		stack.add_child(toggle)
	var first_button: Button
	for entry: Array in actions:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(241, 38)
		button.size_flags_horizontal = SIZE_SHRINK_CENTER
		button.add_theme_color_override("font_color", Color("0e1430") if first_button == null else PAPER)
		button.add_theme_color_override("font_hover_color", Color("0e1430"))
		button.add_theme_color_override("font_focus_color", Color("0e1430") if first_button == null else PAPER)
		button.add_theme_stylebox_override("normal", _box(GOLD if first_button == null else Color("182538"), GOLD, 5, 9))
		button.add_theme_stylebox_override("hover", _box(PAPER, GOLD, 5, 9))
		button.pressed.connect(_dispatch.bind(entry[1]))
		stack.add_child(button)
		if first_button == null:
			first_button = button
	_veil.show()
	if first_button != null:
		first_button.grab_focus()


func _dispatch(action: String) -> void:
	action_requested.emit(action)


func _add_slider(parent: VBoxContainer, title: String, key: String, value: float, low: float, high: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := _label(title, 15, PAPER)
	name_label.custom_minimum_size.x = 140
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(165, 24)
	slider.size_flags_horizontal = SIZE_EXPAND_FILL
	var readout := _label("%d%%" % roundi(value * 100), 13, GOLD)
	readout.custom_minimum_size.x = 52
	slider.value_changed.connect(func(next: float) -> void:
		readout.text = "%d%%" % roundi(next * 100)
		setting_changed.emit(key, next))
	row.add_child(slider)
	row.add_child(readout)
	parent.add_child(row)


func _make_hud() -> void:
	var left := _stack_card(Vector2.ZERO, Rect2(26, 22, 221, 90))
	_chapter = _label("", 13, AQUA)
	left.add_child(_chapter)
	left.add_child(_label("NGỌN LỬA", 11, MUTED))
	_flames = _label("", 24, GOLD)
	left.add_child(_flames)

	var timer := _stack_card(Vector2(0.5, 0), Rect2(-71, 22, 142, 71))
	timer.add_child(_centered_label("TỚI BÌNH MINH", 11, MUTED))
	_clock = _centered_label("", 26, PAPER)
	_clock_icon = WarningMark.new()
	timer.add_child(_warning_row(_clock, _clock_icon))

	var right := _stack_card(Vector2(1, 0), Rect2(-216, 22, 190, 100))
	_lamps = _label("", 13, PAPER)
	right.add_child(_lamps)
	_score = _label("", 24, GOLD)
	right.add_child(_score)

	var map_stack := _stack_card(Vector2(0, 1), Rect2(26, -162, 156, 139))
	map_stack.add_child(_centered_label("BẢN ĐỒ ĐẢO", 11, AQUA))
	_minimap = Minimap.new()
	_minimap.custom_minimum_size = Vector2(127, 99)
	_minimap.size_flags_vertical = SIZE_EXPAND_FILL
	_minimap.mouse_filter = MOUSE_FILTER_IGNORE
	map_stack.add_child(_minimap)

	var abilities := _stack_card(Vector2.ONE, Rect2(-220, -110, 194, 87))
	_dash = _label("", 14, PAPER)
	_pulse = _label("", 14, PAPER)
	_charm = _label("", 12, GOLD)
	abilities.add_child(_dash)
	abilities.add_child(_pulse)
	abilities.add_child(_charm)

	var inventory := _stack_card(Vector2(0.5, 1), Rect2(-258, -90, 516, 67))
	_inventory_count = _centered_label("", 11, AQUA)
	inventory.add_child(_inventory_count)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	inventory.add_child(row)
	for index in range(20):
		var cell := ColorRect.new()
		cell.custom_minimum_size = Vector2(17, 9)
		cell.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(cell)
		_cells.append(cell)
	inventory.add_child(_centered_label("WASD  Đi    Space  Nhảy    Shift  Lướt    E  Nạp    Q  Tỏa sáng    P  Dừng", 13, PAPER))

	_prompt = _centered_label("", 20, GOLD)
	_prompt_icon = WarningMark.new()
	_shaded(_prompt)
	_place(_warning_row(_prompt, _prompt_icon), Vector2(0.5, 1), Rect2(-175, -139, 350, 35))
	_toast = _centered_label("", 17, PAPER)
	_toast_icon = WarningMark.new()
	_shaded(_toast)
	_place(_warning_row(_toast, _toast_icon), Vector2(0.5, 0), Rect2(-277, 108, 554, 30))
	_marker = _centered_label("➤", 29, GOLD)
	_shaded(_marker)
	_marker.custom_minimum_size = Vector2(38, 38)
	_hud.add_child(_marker)
	_marker.hide()


func _warning_row(label: Label, mark: WarningMark) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	mark.hide()
	row.add_child(mark)
	row.add_child(label)
	return row


func _stack_card(anchor: Vector2, rect: Rect2) -> VBoxContainer:
	var panel := _card(13)
	_place(panel, anchor, rect)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	panel.add_child(stack)
	return stack


func _place(node: Control, anchor: Vector2, rect: Rect2) -> void:
	_hud.add_child(node)
	node.set_anchor(SIDE_LEFT, anchor.x)
	node.set_anchor(SIDE_RIGHT, anchor.x)
	node.set_anchor(SIDE_TOP, anchor.y)
	node.set_anchor(SIDE_BOTTOM, anchor.y)
	node.offset_left = rect.position.x
	node.offset_top = rect.position.y
	node.offset_right = rect.end.x
	node.offset_bottom = rect.end.y


func _card(padding: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(Color("10192ae6"), Color("42546a"), 8, padding))
	return panel


func _box(fill: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding * 0.75
	style.content_margin_bottom = padding * 0.75
	return style


func _centered_label(value: String, font_size: int, font_color: Color) -> Label:
	var label := _label(value, font_size, font_color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _label(value: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	return label


func _shaded(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color", Color("090e22"))
	label.add_theme_constant_override("shadow_offset_y", 2)

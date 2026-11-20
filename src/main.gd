extends Node3D

const Night := preload("res://src/night.gd")
const Map := preload("res://src/island_map.gd")
const IslandArt := preload("res://src/island_art.gd")
const NightHUD := preload("res://src/hud.gd")
const NightAudio := preload("res://src/night_audio.gd")
const Leaderboard := preload("res://src/leaderboard.gd")
const ActorBatch := preload("res://src/actor_batch.gd")
const ACTION_NAMES := {"walk_left": "Đi trái", "walk_right": "Đi phải", "walk_back": "Đi lùi",
	"walk_forward": "Đi tới", "jump": "Nhảy", "dash": "Lướt", "interact": "Tương tác",
	"pulse": "Tỏa sáng", "pause": "Tạm dừng"}
const KEYS := {
	"walk_left": [KEY_A, KEY_LEFT], "walk_right": [KEY_D, KEY_RIGHT],
	"walk_forward": [KEY_W, KEY_UP], "walk_back": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE], "interact": [KEY_E], "pulse": [KEY_Q], "dash": [KEY_SHIFT],
	"pause": [KEY_ESCAPE, KEY_P], "restart": [KEY_R],
}
const STORIES := [
	"Mây ơi, đèn cũng cạn dầu. Hãy châm thêm đom đóm khi đèn yếu để giữ đảo sáng tới bình minh.",
	"Cầu tre dẫn sang đảo bên. Nếu đi vòng qua bờ đá, hãy tìm vòng ngọc của bục nhảy. Gió Lạc thích đom đóm lắm đấy.",
	"Hai con dốc dẫn lên vành chuông. Từ bục nhảy trên vành, con sẽ tới ngọn đèn cao nhất. Nhìn lá bay để đón gió.",
]

var night: Night
var seed_value := randi()
var settings_path := "user://settings.cfg"
var leaderboard_path := "user://leaderboard.json"
var _board: Leaderboard
var _score_saved := false
var _capture_action := ""
var _bindings := {}
var total_score := 0
var _settings := {"volume": 0.8, "sensitivity": 1.0, "accessible_palette": false,
	"reduced_motion": false, "large_text": false}
var _return_page := "menu"
var _art: IslandArt
var _hud: NightHUD
var _audio: NightAudio
var _camera: Camera3D
var _actors: Node3D
var _player: Node3D
var _body: Node3D
var _pulse_ring: MeshInstance3D
var _lantern_nodes := {}
var _entity_nodes := {}
var _motes_batch: ActorBatch
var _shades_batch: ActorBatch
var _stunned_batch: ActorBatch
var _yaw := 0.0
var _camera_height := 5.15
var _toast := ""
var _toast_is_warning := false
var _toast_until := 0
var _pulse_at := -100
var _last_second := -1
var _mouse_guard_until := 0
var _ambient_lit := -1


func _ready() -> void:
	_board = Leaderboard.new(leaderboard_path)
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty() and arguments[0] == "--export-leaderboard":
		if arguments.size() != 2:
			printerr("Usage: --export-leaderboard out.json")
			get_tree().quit(2)
		else:
			var result := _board.export_to(arguments[1])
			if result != OK:
				printerr(error_string(result))
			get_tree().quit(0 if result == OK else 1)
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		return
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.far = 240.0
	add_child(_camera)
	_camera.make_current()
	var overlay := CanvasLayer.new()
	add_child(overlay)
	_hud = NightHUD.new()
	overlay.add_child(_hud)
	_hud.action_requested.connect(handle_action)
	_hud.setting_changed.connect(_update_setting)
	_audio = NightAudio.new()
	add_child(_audio)
	_art = IslandArt.new()
	add_child(_art)
	_load_settings()
	_setup_actions()
	_prepare_night(1)
	_show_menu()


func handle_action(action: String) -> void:
	match action:
		"new":
			total_score = 0
			_prepare_night(1)
			_show_intro()
		"begin":
			_begin_play()
		"resume":
			night.resume_from_menu()
			_begin_play()
		"retry":
			_prepare_night(night.number)
			_begin_play()
		"next":
			_prepare_night(night.number + 1)
			_show_intro()
		"menu":
			_show_menu()
		"settings":
			_return_page = _hud.mode
			_show_settings()
		"leaderboard":
			_show_leaderboard()
		"save_score":
			_save_score()
		"bindings":
			_show_bindings()
		"reset_bindings":
			_bindings.clear()
			_capture_action = ""
			_setup_actions()
			_save_settings()
			_show_bindings("Đã khôi phục phím mặc định.")
		"settings_back":
			_capture_action = ""
			_show_settings()
		"back":
			if _return_page == "pause":
				_show_pause()
			else:
				_show_menu()
		_:
			if action.begins_with("bind/"):
				_capture_action = action.trim_prefix("bind/")
				_show_bindings("Nhấn phím mới cho %s. Esc để hủy." % ACTION_NAMES[_capture_action])


func _prepare_night(number: int, scenario: Dictionary = {}) -> void:
	night = Night.new(seed_value ^ (number - 1) * 193939, scenario, number)
	_yaw = 0.0
	_camera_height = 5.15
	_toast = ""
	_toast_is_warning = false
	_toast_until = 0
	_pulse_at = -100
	_last_second = -1
	_score_saved = false
	_hud.clear_spawn()
	_ambient_lit = -1
	_art.set_night(number)
	if _actors != null:
		remove_child(_actors)
		_actors.queue_free()
	_lantern_nodes.clear()
	_entity_nodes.clear()
	_actors = Node3D.new()
	add_child(_actors)
	_motes_batch = _batch(_art.make_mote(), false)
	_shades_batch = _batch(_art.make_shade(), false)
	var stunned := _art.make_shade()
	_art.update_shade(stunned, true)
	_stunned_batch = _batch(stunned, false)
	_player = _art.make_player()
	_actors.add_child(_player)
	_body = _player.get_node("Body")
	_pulse_ring = _art.make_ring(1.0, 0.032, Color("f2c14e"), 0.78)
	_pulse_ring.hide()
	_actors.add_child(_pulse_ring)
	for lantern in night.lanterns:
		var lamp := _art.make_lantern()
		lamp.position = lantern.pos
		_actors.add_child(lamp)
		_lantern_nodes[lantern.id] = lamp
	_update_camera(1.0)
	_sync_world()
	_hud.update_night(night, _yaw, "")


func _show_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_audio.pause_music(true)
	_hud.show_panel("menu", "BA HÒN ĐẢO", "Đảo Đèn Lồng",
		"Theo chân Mây qua ba đêm và giữ những ngọn đèn sáng tới bình minh.",
		[["Bắt đầu", "new"], ["Bảng xếp hạng", "leaderboard"], ["Cài đặt", "settings"]])


func _show_intro() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.show_panel("intro", "ĐÊM %d  /  ÔNG ĐĂNG" % night.number, Map.NAMES[night.number - 1],
		"%s\n\nGiữ ít nhất %d/%d đèn sáng khi tới bình minh." % [STORIES[night.number - 1], night.required_lamps(), night.lanterns.size()],
		[["Bắt đầu đêm", "begin"], ["Về menu", "menu"]])


func _begin_play() -> void:
	_mouse_guard_until = night.tick + 3
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_audio.play_music()
	_hud.show_play()


func _show_pause() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_audio.pause_music(true)
	_hud.show_panel("pause", "ĐÊM %d  /  %s" % [night.number, Map.NAMES[night.number - 1].to_upper()],
		"Tạm dừng", "", [["Tiếp tục", "resume"], ["Chơi lại Đêm", "retry"], ["Cài đặt", "settings"], ["Về menu", "menu"]])


func _show_result(reason: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_audio.pause_music(true)
	_audio.play_effect(night.state)
	if night.state == "won":
		total_score += night.score
		if night.number == 3:
			_camera.position = Vector3(27, 22, 44)
			_camera.look_at(Vector3(0, 3, 3), Vector3.UP)
			_hud.show_panel("dawn", "BA HÒN ĐẢO ĐÃ SÁNG", "Bình Minh",
				"Mây đã mang ánh sáng về cả ba hòn đảo.\nTổng điểm   %d" % total_score,
				[["Về menu", "menu"], ["Chơi lại từ đầu", "new"]], {"score_entry": true})
		else:
			_hud.show_panel("result", Map.NAMES[night.number - 1].to_upper(), "Đảo đã sáng",
				"%d/%d đèn sáng  ·  %d điểm đêm này\nTổng điểm   %d" % [night.lit_count(), night.lanterns.size(), night.score, total_score],
				[["Đêm kế tiếp", "next"], ["Về menu", "menu"]])
	else:
		var detail := "Bình minh có %d đèn sáng. Mây cần ít nhất %d đèn." % [night.lit_count(), night.required_lamps()]
		if reason == "no_flames":
			detail = "Mây đã mất ngọn lửa cuối cùng."
		_hud.show_panel("result", Map.NAMES[night.number - 1].to_upper(), "Đêm khép lại",
			"%s\nTổng điểm các đêm đã thắng   %d" % [detail, total_score],
			[["Chơi lại Đêm  ·  R", "retry"], ["Về menu", "menu"]], {"score_entry": true})


func _show_leaderboard() -> void:
	var rows := _board.entries()
	var lines := PackedStringArray()
	for index in range(rows.size()):
		var entry: Dictionary = rows[index]
		lines.append("%d.  %s     %d điểm     %d/3 đêm" % [index + 1, entry.name, entry.score, entry.nights_won])
	var message := "\n".join(lines) if not lines.is_empty() else "Chưa có điểm được lưu."
	_hud.show_panel("leaderboard", "ĐẢO ĐÈN LỒNG", "Bảng xếp hạng", message, [["Về menu", "menu"]])


func _save_score() -> void:
	if _score_saved or not night.finished():
		return
	var won := 3 if _hud.mode == "dawn" else night.number - 1
	var status := _board.record(_hud.score_name.text, total_score, won, seed_value)
	if status != OK:
		_hud.form_notice.text = "Tên cần 3–12 ký tự A–Z, 0–9 hoặc _." if status == ERR_INVALID_DATA else "Không ghi được bảng xếp hạng."
		return
	_score_saved = true
	_hud.score_name.editable = false
	_hud.form_notice.text = "Đã lưu %d điểm." % total_score


func _show_settings() -> void:
	_hud.show_panel("settings", "ĐẢO ĐÈN LỒNG", "Cài đặt", "",
		[["Đổi phím", "bindings"], ["Quay lại", "back"]], _settings)


func _show_bindings(message: String = "") -> void:
	var rows := []
	for action: String in ACTION_NAMES:
		var keys := PackedStringArray()
		for key: int in _bindings.get(action, KEYS[action]):
			keys.append(_key_name(key))
		rows.append([ACTION_NAMES[action] + "   " + " / ".join(keys), "bind/" + action])
	_hud.show_panel("bindings", "ĐIỀU KHIỂN", "Đổi phím", message,
		[["Khôi phục mặc định", "reset_bindings"], ["Quay lại", "settings_back"]], {"bindings": rows})


func _input(event: InputEvent) -> void:
	if _capture_action.is_empty() or not event is InputEventKey or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var action := _capture_action
	var key := int(event.physical_keycode)
	if key == 0:
		return
	if key != KEY_ESCAPE:
		for other: String in KEYS:
			if other != action and key in _bindings.get(other, KEYS[other]):
				_show_bindings("Phím đã dùng cho %s. Chọn phím khác." % ACTION_NAMES.get(other, "Chơi lại"))
				return
		_bindings[action] = [key]
		_setup_actions()
		_save_settings()
	_capture_action = ""
	_show_bindings("Đã lưu phím." if key != KEY_ESCAPE else "Đã hủy đổi phím.")


func _unhandled_input(event: InputEvent) -> void:
	if _hud.mode == "play" and event is InputEventMouseMotion and night.tick > _mouse_guard_until:
		var scale_factor: float = _settings.sensitivity
		_yaw = fposmod(_yaw - event.relative.x * 0.0037 * scale_factor, TAU)
		_camera_height = clampf(_camera_height + event.relative.y * 0.033 * scale_factor, 3.6, 12.2)


func _physics_process(_delta: float) -> void:
	if _hud.mode == "result" and night.state == "lost" and Input.is_action_just_pressed("restart") \
			and not (_hud.score_name != null and is_instance_valid(_hud.score_name) and _hud.score_name.has_focus()):
		handle_action("retry")
		return
	if _hud.mode == "settings" and Input.is_action_just_pressed("pause"):
		handle_action("back")
		return
	if _hud.mode not in ["play", "pause"]:
		return
	var walk := Input.get_vector("walk_right", "walk_left", "walk_back", "walk_forward", 0.0)
	var input := {"move": walk, "cam_yaw_deg": rad_to_deg(_yaw)}
	for action: String in Night.BUTTONS:
		input[action] = Input.is_action_pressed(action)
	for event in night.step(input):
		_on_game_event(event)
	if night.state != "paused":
		_sync_world()
		_update_timed_effects()
		_hud.update_night(night, _yaw, _toast if night.sim_tick < _toast_until else "", _toast_is_warning)


func _process(delta: float) -> void:
	if _hud.mode == "play":
		_update_camera(1.0 - exp(-delta * 12.0))
		_hud.update_marker(_camera, night)


func _on_game_event(event: Dictionary) -> void:
	_audio.play_effect(event.name)
	match event.name:
		"lantern_lit":
			_show_toast("Đèn %s đã sáng  ·  Vùng an toàn" % event.data.lantern_id)
		"refuel":
			_show_toast("Đã châm dầu cho đèn %s" % event.data.lantern_id)
		"lantern_out":
			_show_toast("Đèn %s đã cạn dầu" % event.data.lantern_id, true)
		"shade_spawned":
			_show_toast("Bóng Mực xuất hiện", true)
			_hud.note_spawn(event.data.id, night.sim_tick)
		"pulse":
			_pulse_ring.position = night.player_pos + Vector3.UP * 0.065
			_pulse_at = night.sim_tick
			_show_toast("Mây tỏa sáng  ·  −3 đom đóm")
		"player_hit":
			_show_toast("Mây rơi khỏi đảo" if event.data.by == "fall" else "Mất một ngọn lửa  ·  Rơi %d đom đóm" % event.data.dropped, true)
		"charm_picked":
			_show_toast("Bùa Gió  ·  Chạy nhanh và lướt liên tiếp")
		"drifter_steal":
			_show_toast("Gió Lạc đã cướp %d đom đóm" % event.data.amount)
		"drifter_drop":
			_show_toast("Gió Lạc đã thả số đom đóm đã cướp")
		"paused":
			_show_pause()
		"resumed":
			_begin_play()
		"game_over":
			_show_result(event.data.reason)


func _update_timed_effects() -> void:
	var seconds := ceili(night.time_left())
	if seconds != _last_second and seconds >= 1 and seconds <= 10:
		_audio.play_effect("countdown")
	_last_second = seconds
	if night.wind_warning and night.sim_tick % 1800 == 1680:
		_audio.play_effect("wind")
		_show_toast("Gió mạnh sắp tới  ·  Quan sát hướng lá bay", true)


func _show_toast(message: String, warning: bool = false) -> void:
	_toast = message
	_toast_is_warning = warning
	_toast_until = night.sim_tick + 108


func _sync_lanterns() -> void:
	for lamp in night.lanterns:
		_art.update_lantern(_lantern_nodes[lamp.id], lamp, night, _camera.position)
	var lit := night.lit_count()
	if lit != _ambient_lit:
		_ambient_lit = lit
		_art.set_restored_light(float(lit) / night.lanterns.size())


func _sync_world() -> void:
	_sync_lanterns()
	var seconds := float(night.sim_tick) / Night.TICKS_PER_SECOND
	_player.position = night.player_pos
	_player.rotation.y = lerp_angle(_player.rotation.y, atan2(night.facing.x, night.facing.z), 0.32)
	var moving := Vector2(night.velocity.x, night.velocity.z).length_squared() > 0.1
	_body.position.y = sin(seconds * 16.0) * 0.04 if moving and night.grounded and not _settings.reduced_motion else 0.0
	_body.visible = night.respawn_at == 0 and (not night.player_is_protected() or night.sim_tick % 10 < 7)
	var mote_poses: Array[Transform3D] = []
	for mote in night.motes:
		var phase := float(String(mote.id).substr(1).to_int()) * 0.78
		var position: Vector3 = mote.pos + Vector3.UP * (0.48 + sin(seconds * 3.6 + phase) * 0.17)
		mote_poses.append(Transform3D(Basis.IDENTITY, position))
	_motes_batch.sync(mote_poses)
	var shade_poses: Array[Transform3D] = []
	var stunned_poses: Array[Transform3D] = []
	for shade in night.shades:
		var position: Vector3 = shade.pos + Vector3.UP * sin(seconds * 4.0) * 0.09
		var direction := night.player_pos - position
		var pose := Transform3D(Basis(Vector3.UP, atan2(direction.x, direction.z)), position)
		if shade.state == "stunned":
			stunned_poses.append(pose)
		else:
			shade_poses.append(pose)
	_shades_batch.sync(shade_poses)
	_stunned_batch.sync(stunned_poses)
	var active := {}
	for drifter in night.drifters:
		var node := _entity(drifter.id, _art.make_drifter, active)
		node.position = drifter.pos + Vector3.UP * sin(seconds * 7.2) * 0.15
		_face_player(node)
		if drifter.state == "flee":
			node.rotate_y(PI)
	for charm in night.charms:
		var node := _entity(charm.id, _art.make_charm, active)
		node.visible = night.sim_tick >= int(charm.ready)
		node.position = charm.pos + Vector3.UP * (0.74 + sin(seconds * 4.3) * 0.1)
		node.rotation.y = seconds * 1.9
	for id: String in _entity_nodes.keys():
		if not active.has(id):
			_entity_nodes[id].queue_free()
			_entity_nodes.erase(id)
	var pulse_progress := float(night.sim_tick - _pulse_at) / 24.0
	_pulse_ring.visible = pulse_progress < 1.0
	if _pulse_ring.visible:
		var radius := lerpf(0.20, float(night.tuning.pulse_radius), pulse_progress)
		_pulse_ring.scale = Vector3(radius, 1, radius)
	_art.update_wind(night.wind_active or night.wind_warning, night.wind_dir_deg, seconds, night.player_pos)


func _entity(id: String, factory: Callable, active: Dictionary) -> Node3D:
	active[id] = true
	if not _entity_nodes.has(id):
		var node: Node3D = factory.call()
		_actors.add_child(node)
		_entity_nodes[id] = node
	return _entity_nodes[id]


func _batch(template: Node3D, casts_shadow: bool) -> ActorBatch:
	var batch := ActorBatch.new()
	batch.configure(template, casts_shadow)
	_actors.add_child(batch)
	return batch


func _face_player(node: Node3D) -> void:
	var direction := night.player_pos - node.position
	if Vector2(direction.x, direction.z).length_squared() > 0.001:
		node.rotation.y = atan2(direction.x, direction.z)


func _update_camera(weight: float) -> void:
	var forward := Vector3(0, 0, 1).rotated(Vector3.UP, _yaw)
	var at := Vector3(night.player_pos.x, maxf(-9, night.player_pos.y), night.player_pos.z)
	var destination := at - forward * 9.6 + Vector3.UP * _camera_height
	var anchor := at + Vector3.UP * 1.30
	var shoulder := 1.0
	if night.number == 3:
		for index in range(2, 21):
			if Map.blocks_camera(night.number, anchor.lerp(destination, index / 20.0)):
				shoulder = maxf(0.10, (index - 1) / 20.0)
				destination = anchor.lerp(destination, shoulder)
				weight = 1.0
				break
	_camera.position = _camera.position.lerp(destination, weight)
	_camera.look_at(anchor + forward * (3.2 * shoulder) + Vector3.UP * 0.35, Vector3.UP)


func _setup_actions() -> void:
	for action: String in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for key: int in _bindings.get(action, KEYS[action]):
			var binding := InputEventKey.new()
			binding.physical_keycode = key
			InputMap.action_add_event(action, binding)
	_hud.interact_key = _primary_key("interact")
	_hud.help_text.text = "%s%s%s%s  ·  %s  ·  %s  ·  %s  ·  %s  ·  %s" % [
		_primary_key("walk_forward"), _primary_key("walk_left"), _primary_key("walk_back"), _primary_key("walk_right"),
		_primary_key("jump"), _primary_key("dash"), _hud.interact_key, _primary_key("pulse"), _primary_key("pause")]


func _primary_key(action: String) -> String:
	var key := int(_bindings.get(action, KEYS[action])[0])
	return _key_name(key)


func _key_name(key: int) -> String:
	return OS.get_keycode_string(key if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(key))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		_settings.volume = clampf(float(config.get_value("settings", "volume", _settings.volume)), 0.0, 1.0)
		_settings.sensitivity = clampf(float(config.get_value("settings", "sensitivity", _settings.sensitivity)), 0.3, 2.0)
		_settings.accessible_palette = bool(config.get_value("settings", "accessible_palette", _settings.accessible_palette))
		_settings.reduced_motion = bool(config.get_value("settings", "reduced_motion", false))
		_settings.large_text = bool(config.get_value("settings", "large_text", false))
		var saved: Variant = config.get_value("settings", "bindings", {})
		if saved is Dictionary:
			for action: String in ACTION_NAMES:
				var keys: Variant = saved.get(action)
				if keys is Array and keys.size() == 1 and keys[0] is int and keys[0] > 0:
					_bindings[action] = keys
	_audio.set_volume(_settings.volume)
	_apply_palette()


func _update_setting(key: String, value: Variant) -> void:
	_settings[key] = value
	_audio.set_volume(_settings.volume)
	_apply_palette()
	_save_settings()


func _save_settings() -> void:
	var config := ConfigFile.new()
	for name: String in _settings:
		config.set_value("settings", name, _settings[name])
	config.set_value("settings", "bindings", _bindings)
	if config.save(settings_path) != OK:
		push_warning("Không lưu được cài đặt.")


func _apply_palette() -> void:
	_hud.accessible_palette = _settings.accessible_palette
	_hud.reduced_motion = _settings.reduced_motion
	_hud.set_large_text(_settings.large_text)
	_art.set_accessible_palette(_settings.accessible_palette)

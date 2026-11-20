extends SceneTree

const SCENE := preload("res://src/main.tscn")
const Map := preload("res://src/island_map.gd")
const NightAudio := preload("res://src/night_audio.gd")

var _game
var _capture_dir := ""
var _settings_path := ""


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		_capture_dir = arguments[0]
	var local := ProjectSettings.globalize_path("res://.godot")
	DirAccess.make_dir_recursive_absolute(local)
	_settings_path = local.path_join("campaign-settings-%d.cfg" % OS.get_process_id())
	_game = SCENE.instantiate()
	_game.settings_path = _settings_path
	_game.seed_value = 42
	root.add_child(_game)
	var music: AudioStreamWAV = _game._audio._make_music()
	if not _expect(music.loop_mode == AudioStreamWAV.LOOP_FORWARD and music.data.size() > 0
			and NightAudio.EFFECTS.size() >= 10, "looping soundtrack and required sound cues are defined"):
		return
	await _capture("01-menu.jpg")
	_click("Cài đặt")
	var sliders: Array[Node] = _game._hud.find_children("*", "HSlider", true, false)
	if not _expect(sliders.size() == 2, "settings opens with two sliders"):
		return
	sliders[0].value = 0.42
	sliders[1].value = 1.35
	var config := ConfigFile.new()
	if not _expect(config.load(_settings_path) == OK and is_equal_approx(config.get_value("settings", "volume"), 0.42)
			and is_equal_approx(config.get_value("settings", "sensitivity"), 1.35), "saved volume and mouse sensitivity"):
		return
	await _capture("02-cai-dat.jpg")
	_game.queue_free()
	await process_frame
	_game = SCENE.instantiate()
	_game.settings_path = _settings_path
	_game.seed_value = 42
	root.add_child(_game)
	if not _expect(is_equal_approx(_game._settings.volume, 0.42) and is_equal_approx(_game._settings.sensitivity, 1.35),
			"settings restored in new scene"):
		return
	_click("Bắt đầu")
	if not _expect(_game._hud.mode == "intro" and _game.night.number == 1, "Night 1 intro opened from menu"):
		return
	await _capture("03-gioi-thieu.jpg")
	_click("Bắt đầu đêm")
	await _wait_ticks(6)
	await _tap(KEY_SPACE)
	if not _expect(_game.night.player_pos.y > 0.0, "Space jumps through game input"):
		return
	await _tap(KEY_SHIFT)
	if not _expect(_game.night.dash_cooldown() > 0.0, "Shift dashes through game input"):
		return
	await _tap(KEY_P)
	var frozen: Dictionary = _game.night.snapshot()
	await _wait_ticks(12)
	if not _expect(_game._hud.mode == "pause" and frozen.sim_tick == _game.night.sim_tick
			and frozen.player == _game.night.snapshot().player, "P pauses and freezes the simulation"):
		return
	await _capture("04-tam-dung.jpg")
	_click("Cài đặt")
	_click("Quay lại")
	_click("Tiếp tục")
	await _wait_ticks(2)
	if not _expect(_game._hud.mode == "play" and _game.night.sim_tick > int(frozen.sim_tick), "resume button continues play"):
		return
	await _tap(KEY_ESCAPE)
	_click("Chơi lại Đêm")
	if not _expect(_game.night.number == 1 and _game.night.tick == 0, "Esc and pause restart reset current night"):
		return
	await _capture("05-dao-ben.jpg")
	_game._prepare_night(1, {"time_left_s": 29, "player": {"pos": [0, 0, 24], "carried": 5}})
	_game._begin_play()
	await _wait_ticks(2)
	if not _expect(_game._hud._prompt.visible and _game._hud._prompt.text == "E — Nạp ánh sáng (0/10)"
			and _game._hud._clock.get_theme_color("font_color") == Color("ff5a5f")
			and _game._hud._cells.size() == 10, "HUD shows deposit prompt, warning clock and ten inventory cells"):
		return
	if not _expect(is_equal_approx(_game._art._environment.ambient_light_energy, 0.15)
			and _game._art._mat.coat.albedo_color == Color("e8e2d0"), "standard ambient and costume colors"):
		return
	for number in range(1, 4):
		if not _expect(_game.night.number == number, "loaded actual map for night %d" % number):
			return
		if number == 2:
			_game._prepare_night(2, {"player": {"pos": [20, 0, 0]}})
			_game._yaw = PI / 2
			_game._update_camera(1.0)
			await _capture("06-dao-cau.jpg")
		if number == 3:
			_game._prepare_night(3, {"player": {"pos": [0, 0, 31]}})
			_game._yaw = PI
			_game._update_camera(1.0)
			await _capture("07-dao-chuong.jpg")
			_game.night.sim_tick = 1679
			_game.night.tick = 1679
			await _wait_ticks(2)
			if not _expect(_game.night.wind_warning and not _game.night.wind_active
					and not _game._art._leaves.is_empty(), "wind warning adds leaves before the gust"):
				return
			await _capture("10-la-bay.jpg")
		var scenario := _last_lamp(number)
		_game._prepare_night(number, scenario)
		_game._begin_play()
		await _tap(KEY_E)
		if not _expect(_game.night.state == "won" and _game.night.lit_count() == number + 4,
				"E lights the last lantern and wins controlled Night %d scenario" % number):
			return
		if not _expect(is_equal_approx(_game._art._environment.ambient_light_energy, 0.70), "fully lit island raises ambient light to 0.70"):
			return
		if number < 3:
			_click("Đêm kế tiếp")
			if not _expect(_game._hud.mode == "intro", "intro shown before next night"):
				return
			_click("Bắt đầu đêm")
	if not _expect(_game._hud.mode == "dawn" and _game.total_score == 3 * 368, "Bình Minh shows the total of the three wins"):
		return
	await _capture("08-binh-minh.jpg")
	_click("Về menu")
	_click("Bắt đầu")
	_click("Bắt đầu đêm")
	_game._prepare_night(2, {"time_left_s": 0.05})
	_game._begin_play()
	await _wait_ticks(6)
	if not _expect(_game._hud.mode == "result" and _game.total_score == 0 and _game.night.state == "lost",
			"loss is visible and does not add to campaign score"):
		return
	await _capture("09-ket-qua-thua.jpg")
	await _tap(KEY_R)
	if not _expect(_game._hud.mode == "play" and _game.night.number == 2 and _game.night.flames == 3,
			"R restarts the lost night with full flames"):
		return
	_game.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _last_lamp(number: int) -> Dictionary:
	var lamps := []
	var positions: Array = Map.LANTERNS[number - 1]
	for index in range(1, positions.size()):
		lamps.append({"id": "L%d" % (index + 1), "lit": true})
	var position: Vector3 = positions[0] - Vector3(0, 0, 1.3)
	return {"lanterns": lamps, "random_motes": false, "random_shades": false, "random_drifters": false,
		"time_left_s": 10, "player": {"pos": [position.x, position.y, position.z], "carried": 10}}


func _click(caption: String) -> void:
	for button: Button in _game._hud.find_children("*", "Button", true, false):
		if button.text == caption and button.is_visible_in_tree():
			button.pressed.emit()
			return
	_expect(false, "button available: " + caption)


func _tap(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await physics_frame
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	await physics_frame


func _wait_ticks(count: int) -> void:
	for index in range(count):
		await physics_frame


func _capture(name: String) -> void:
	if _capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_jpg(_capture_dir.path_join(name), 0.90) != OK:
		_expect(false, "capture " + name)


func _expect(answer: bool, detail: String) -> bool:
	if answer:
		print("PASS " + detail)
	else:
		printerr("FAIL " + detail)
		quit(1)
	return answer

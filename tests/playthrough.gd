extends SceneTree

const SCENE := preload("res://src/main.tscn")
const WALK := ["walk_left", "walk_right", "walk_back", "walk_forward"]

var _game
var _capture_dir := ""


func _initialize() -> void:
	call_deferred("_play")


func _play() -> void:
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		_capture_dir = arguments[0]
	_game = SCENE.instantiate()
	_game.seed_value = 42
	root.add_child(_game)
	await _wait_ticks(3)
	if not _require(_game.night.flames == 3 and _game.night.lit_count() == 0, "fresh scene"):
		return
	await _capture("01-dao-ben.jpg")
	await _tap_key(KEY_SPACE)
	if not _require(_game.night.player_pos.y > 0.0, "Space lifts Mây off the ground"):
		return
	print("PASS jump via scene input")
	for lamp: Dictionary in _game.night.lanterns:
		if not await _collect(int(_game.night.tuning.lantern_cost)):
			return
		await _walk_to(lamp.pos, 1.4)
		await _tap_key(KEY_E)
		if not _require(lamp.lit, "lit " + lamp.id):
			return
		print("PASS %s lit through movement, pickup and interact at tick %d" % [lamp.id, _game.night.tick])
		if lamp.id == "L1":
			await _capture("02-den-da-sang.jpg")
	if not _require(_game.night.state == "won" and _game._hud._result.visible, "winning result visible"):
		return
	print("PASS win shown (score %d)" % _game.night.score)
	await _capture("03-ket-qua-thang.jpg")
	# Exercise the button after winning and the keyboard shortcut after losing.
	_game._hud._restart.pressed.emit()
	if not _require(_game.night.tick == 0 and _game.night.lit_count() == 0 and not _game._hud._result.visible,
			"result button resets the night"):
		return
	print("PASS restart button resets the scene")
	if not await _collect(int(_game.night.tuning.pulse_cost)):
		return
	await _walk_to(Vector3.ZERO, 0.2)
	while _game.night.tick < 850 and not _shade_in_pulse_range():
		await physics_frame
	var carried: int = _game.night.carried
	await _tap_key(KEY_Q)
	if not _require(_game.night.carried == carried - int(_game.night.tuning.pulse_cost) and _game._pulse_ring.visible,
			"Q spends light and displays the pulse ring"):
		return
	if not _require(_game.night.shades.any(func(shade: Dictionary) -> bool: return shade.state == "stunned"),
			"Q stuns a chasing shade"):
		return
	print("PASS Q spends light, stuns shade and displays the pulse ring")
	await _wait_ticks(13)
	await _capture("05-toa-sang.jpg")
	while _game.night.state == "playing" and _game.night.tick < 3000:
		await physics_frame
	if not _require(_game.night.state == "lost" and _game.night.flames == 0 and _game._hud._result.visible,
			"shades can defeat an idle player"):
		return
	print("PASS loss shown after shade hits (tick %d)" % _game.night.tick)
	await _capture("04-ket-qua-thua.jpg")
	await _tap_key(KEY_R)
	if not _require(_game.night.state == "playing" and _game.night.score == 0 and _game.night.flames == 3,
			"R starts a fresh night"):
		return
	print("PASS restart via keyboard action")
	_game.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _collect(count: int) -> bool:
	for attempt in range(40):
		if _game.night.carried >= count:
			return true
		var mote := _nearest_mote()
		if mote.is_empty() or _game.night.state != "playing":
			break
		await _walk_to(mote.pos, 0.3)
	return _require(false, "could not gather %d motes" % count)


func _nearest_mote() -> Dictionary:
	var closest := {}
	var best := INF
	for mote: Dictionary in _game.night.motes:
		var offset: Vector3 = mote.pos - _game.night.player_pos
		var distance := Vector2(offset.x, offset.z).length_squared()
		if distance < best:
			best = distance
			closest = mote
	return closest


func _walk_to(target: Vector3, reach: float) -> void:
	for index in range(660):
		var offset: Vector3 = target - _game.night.player_pos
		var move := Vector2(offset.x, offset.z)
		if move.length() <= reach or _game.night.state != "playing":
			break
		move = move.normalized().rotated(_game._yaw)
		_release_walk()
		Input.action_press("walk_left", maxf(0.0, move.x))
		Input.action_press("walk_right", maxf(0.0, -move.x))
		Input.action_press("walk_forward", maxf(0.0, move.y))
		Input.action_press("walk_back", maxf(0.0, -move.y))
		await physics_frame
	_release_walk()


func _release_walk() -> void:
	for action: String in WALK:
		Input.action_release(action)


func _shade_in_pulse_range() -> bool:
	for shade: Dictionary in _game.night.shades:
		var offset: Vector3 = shade.pos - _game.night.player_pos
		if Vector2(offset.x, offset.z).length() < 4.9:
			return true
	return false


func _tap_key(key: Key) -> void:
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
	var path := _capture_dir.path_join(name)
	var image := root.get_texture().get_image()
	if image.save_jpg(path, 0.92) != OK:
		printerr("Could not save scene evidence: " + path)
		quit(1)


func _require(value: bool, detail: String) -> bool:
	if not value:
		printerr("FAIL " + detail)
		quit(1)
	return value

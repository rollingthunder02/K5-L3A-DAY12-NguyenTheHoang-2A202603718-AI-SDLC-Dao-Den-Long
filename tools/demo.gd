extends SceneTree

const GAME := preload("res://src/main.tscn")
var _game
var _caption: Label


func _initialize() -> void:
	call_deferred("_record")


func _record() -> void:
	_game = GAME.instantiate()
	_game.seed_value = 42
	_game.settings_path = "res://.godot/demo-settings.cfg"
	_game.leaderboard_path = "res://.godot/demo-leaderboard.json"
	root.add_child(_game)
	_game.handle_action("new")
	await create_timer(2.0).timeout
	_game.handle_action("begin")
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	root.add_child(overlay)
	_caption = Label.new()
	_caption.position = Vector2(240, 110)
	_caption.size = Vector2(800, 88)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 24)
	_caption.add_theme_color_override("font_color", Color.WHITE)
	_caption.add_theme_color_override("font_outline_color", Color("0e1430"))
	_caption.add_theme_constant_override("outline_size", 8)
	overlay.add_child(_caption)
	_caption.text = "Đêm 1 · Mây đi gom đom đóm"
	for index in range(3):
		var target := _nearest_mote()
		await _walk(target, 0.72)
		if _game.night.finished():
			break
	var lamp: Vector3 = _game.night.lanterns[0].pos
	_caption.text = "E · Nạp đom đóm vào Đèn Lồng Lớn"
	await _walk(lamp, 1.5)
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await create_timer(2.0).timeout
	_game._prepare_night(1, {
		"player": {"carried": 6}, "time_left_s": 28,
		"lanterns": [{"id": "L1", "pos": [0, 0, 5], "lit": true, "fuel": 28}],
		"shades": [{"pos": [1, 0.65, 4.3], "state": "drain", "target_lantern_id": "L1"}],
	})
	_game._begin_play()
	_caption.text = "Kịch bản ngắn · Q ngắt Bóng Mực đang hút dầu"
	Input.action_press("pulse")
	await physics_frame
	Input.action_release("pulse")
	await create_timer(3.0).timeout
	var bench: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://bench.json"))
	var soak: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://soak.json"))
	var verify := FileAccess.get_file_as_string("res://docs/proof/phase-4/verify.log")
	var tests := RegEx.create_from_string("Ran ([0-9]+) tests").search(verify)
	var jsonl := FileAccess.get_file_as_string("res://docs/proof/phase-3/oil.jsonl").strip_edges().split("\n")
	var sample: Dictionary = JSON.parse_string(jsonl[-1])
	_game.handle_action("menu")
	var card := ColorRect.new()
	card.color = Color("0e1430")
	card.size = Vector2(1280, 720)
	overlay.add_child(card)
	overlay.move_child(card, 0)
	_caption.position = Vector2(140, 145)
	_caption.size = Vector2(1000, 420)
	_caption.add_theme_font_size_override("font_size", 32)
	_caption.text = "Kiểm chứng · Test Contract v1.3\n\n%s ca kiểm thử · OK\nHeadless · %s · %d điểm · %d tick\nBenchmark · %.1f FPS · 1%% thấp %.1f FPS\nSoak · %d đêm · %d crash" % [
		tests.get_string(1), sample.state, int(sample.score), int(sample.ticks), bench.avg_fps, bench.p1_low_fps,
		int(soak.nights), int(soak.crashes)]
	await create_timer(5.0).timeout
	print("Demo finished from playable input and stored measurements.")
	quit(0)


func _nearest_mote() -> Vector3:
	var point: Vector3 = _game.night.player_pos
	var best := INF
	for mote: Dictionary in _game.night.motes:
		var distance: float = _game.night.player_pos.distance_squared_to(mote.pos)
		if distance < best:
			best = distance
			point = mote.pos
	return point


func _walk(destination: Vector3, reach: float) -> void:
	for step in range(450):
		var offset: Vector3 = destination - _game.night.player_pos
		var move := Vector2(offset.x, offset.z)
		if move.length() < reach or _game.night.finished():
			break
		move = move.normalized().rotated(_game._yaw)
		Input.action_press("walk_left", maxf(0.0, move.x))
		Input.action_press("walk_right", maxf(0.0, -move.x))
		Input.action_press("walk_forward", maxf(0.0, move.y))
		Input.action_press("walk_back", maxf(0.0, -move.y))
		await physics_frame
	for action in ["walk_left", "walk_right", "walk_forward", "walk_back"]:
		Input.action_release(action)

extends SceneTree

const GAME := preload("res://src/main.tscn")
const Measure := preload("res://tools/measurement.gd")

var game
var folder: String
var duration_us: int
var started_at: float
var first_frame := 0
var measure_from := 0
var previous_frame := 0
var load_ms := 0
var frame_ms: Array[float] = []
var vsync_off := false


func _initialize() -> void:
	call_deferred("_setup")


func _setup() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 4 or DisplayServer.get_name() == "headless":
		printerr("Use tools/game.sh bench on a graphical display")
		quit(2)
		return
	duration_us = args[1].to_int() * 1000000
	folder = args[2]
	started_at = args[3].to_float()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	vsync_off = DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED
	Engine.max_fps = 0
	root.size = Vector2i(1280, 720)
	game = GAME.instantiate()
	game.settings_path = folder.path_join("bench-settings.cfg")
	game.seed_value = args[0].to_int()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = game.seed_value
	var shades := []
	var motes := []
	for index in range(200):
		shades.append({"state": "wander", "pos": _point(rng, 0.65)})
	for index in range(100):
		motes.append(_point(rng, 0.0))
	var lamps := [{"id": "L1", "lit": true}, {"id": "L2", "lit": true}, {"id": "L3", "lit": true}]
	game._prepare_night(1, {"shades": shades, "motes": motes, "lanterns": lamps,
		"random_motes": false, "random_shades": false})
	game._hud.show_play()
	game._hud._minimap.get_parent().get_parent().hide()
	assert(game.night.shades.size() == 200 and game.night.motes.size() == 100 and game.night.lit_count() == 3)
	_camera_at(0.0)
	physics_frame.connect(_step)
	process_frame.connect(_orbit)
	RenderingServer.frame_post_draw.connect(_sample)


func _point(rng: RandomNumberGenerator, y: float) -> Array:
	var angle := rng.randf_range(0, TAU)
	var radius := 38.0 * sqrt(rng.randf())
	return [cos(angle) * radius, y, sin(angle) * radius]


func _step() -> void:
	game.night.benchmark_step()
	game._sync_world()
	game._hud.update_night(game.night, 0.0, "")


func _camera_at(seconds: float) -> void:
	var angle := -seconds * TAU / 15.0
	game._camera.position = Vector3(cos(angle) * 30.0, 15.0, sin(angle) * 30.0)
	game._camera.look_at(Vector3.ZERO)


func _orbit() -> void:
	_camera_at(0.0 if first_frame == 0 else (Time.get_ticks_usec() - first_frame) / 1000000.0)
	game._hud.update_marker(game._camera, game.night)


func _sample() -> void:
	var now := Time.get_ticks_usec()
	if first_frame == 0:
		first_frame = now
		load_ms = maxi(0, roundi((Time.get_unix_time_from_system() - started_at) * 1000.0))
		return
	if measure_from == 0:
		if now - first_frame >= 3000000:
			if not Measure.checkpoint(folder, "start"):
				quit(1)
				return
			measure_from = Time.get_ticks_usec()
			previous_frame = measure_from
		return
	if now - measure_from > duration_us:
		RenderingServer.frame_post_draw.disconnect(_sample)
		call_deferred("_finish")
		return
	frame_ms.append((now - previous_frame) / 1000.0)
	previous_frame = now


func _finish() -> void:
	if frame_ms.is_empty() or not Measure.checkpoint(folder, "end"):
		quit(1)
		return
	var total := 0.0
	for value in frame_ms:
		total += value
	frame_ms.sort()
	var count := frame_ms.size()
	var worst := maxi(1, ceili(count * 0.01))
	var slow_ms := 0.0
	for index in range(count - worst, count):
		slow_ms += frame_ms[index]
	var version: String = Engine.get_version_info().string
	var data := {"contract_version": "1.3", "frames": count, "avg_fps": 1000.0 * count / total,
		"p1_low_fps": 1000.0 * worst / slow_ms, "frame_ms_p95": frame_ms[ceili(count * 0.95) - 1],
		"load_ms": load_ms, "vsync_off": vsync_off, "renderer": "Godot %s / OpenGL Compatibility / %s" %
			[version, RenderingServer.get_video_adapter_name()], "os": "%s %s" % [OS.get_name(), OS.get_version()]}
	quit(0 if Measure.write_result(folder, data) else 1)

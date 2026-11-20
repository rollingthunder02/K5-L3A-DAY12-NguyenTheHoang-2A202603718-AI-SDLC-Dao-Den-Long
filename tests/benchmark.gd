extends SceneTree

const SCENE := preload("res://src/main.tscn")


func _initialize() -> void:
	call_deferred("_measure")


func _measure() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("A display is required to measure renderer FPS.")
		quit(2)
		return
	var game := SCENE.instantiate()
	game.seed_value = 42
	root.add_child(game)
	var status := 0
	for number in range(1, 4):
		var shades := []
		for index in range(4 + 2 * number):
			shades.append({"pos": [-10 + index * 2, 0.65, 10], "state": "wander"})
		var drifters := [{"pos": [-3, 1.3, 12]}, {"pos": [5, 1.3, 9]}] if number > 1 else []
		game._prepare_night(number, {"player": {"invuln_ticks": 3600}, "shades": shades, "drifters": drifters})
		game._begin_play()
		await create_timer(2.0).timeout
		var begin := Time.get_ticks_usec()
		var frames := 0
		while Time.get_ticks_usec() - begin < 4000000:
			await process_frame
			frames += 1
		var elapsed := (Time.get_ticks_usec() - begin) / 1000000.0
		var fps := frames / elapsed
		print("Night %d | %dx%d | %d frames in %.3f s | %.2f FPS" % [number, root.size.x, root.size.y, frames, elapsed, fps])
		if fps < 30.0 or root.size != Vector2i(1280, 720):
			status = 1
	game.queue_free()
	await process_frame
	await process_frame
	quit(status)

extends SceneTree

const Night := preload("res://src/night.gd")
const Measure := preload("res://tools/measurement.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 4:
		printerr("Use tools/game.sh soak")
		quit(2)
		return
	var begun := Time.get_ticks_usec()
	var seed_value := args[0].to_int()
	var count := args[1].to_int()
	var folder := args[2]
	var results: Array[String] = []
	for index in range(count):
		var night := Night.new(seed_value + index, {}, index % 3 + 1)
		if index == 0 and not Measure.checkpoint(folder, "start"):
			quit(1)
			return
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + index
		var input := {}
		var limit := roundi(night.time_left() * Night.TICKS_PER_SECOND)
		while not night.finished() and night.tick < limit:
			if night.tick % 30 == 0:
				var angle := rng.randf_range(0, TAU)
				input.move = Vector2(cos(angle), sin(angle))
			input.jump = rng.randf() < 0.05
			input.dash = rng.randf() < 0.03
			input.pulse = rng.randf() < 0.02
			input.interact = rng.randf() < 0.10
			night.step(input)
		if not night.finished():
			printerr("Soak night did not reach a terminal state.")
			quit(1)
			return
		results.append(night.state)
		night = null
	if not Measure.checkpoint(folder, "end"):
		quit(1)
		return
	var elapsed := (Time.get_ticks_usec() - begun) / 1000000.0
	quit(0 if Measure.write_result(folder, {"nights": count, "crashes": 0, "results": results,
		"duration_s": elapsed}) else 1)

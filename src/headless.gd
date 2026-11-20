extends SceneTree

const Night := preload("res://src/night.gd")
const ContractFiles := preload("res://src/contract_files.gd")
const OPTIONS := ["--seed", "--night", "--ticks", "--out", "--snapshot-every", "--scenario", "--inputs"]


func _initialize() -> void:
	quit(_run(OS.get_cmdline_user_args()))


func _run(arguments: PackedStringArray) -> int:
	var options := _parse_options(arguments)
	if options.is_empty():
		return _fail("usage: --seed <int> --night 1 --ticks <int> --out <file.jsonl> " +
			"[--snapshot-every <int>] [--scenario <file.json>] [--inputs <file.json>]")
	var scenario := {}
	var frames := []
	for option in ["--scenario", "--inputs"]:
		if not options.has(option):
			continue
		var loaded := ContractFiles.read(options[option])
		if loaded.has("error"):
			return _fail(loaded.error)
		var document: Dictionary = loaded.data
		var error := ContractFiles.scenario_error(document) if option == "--scenario" else ContractFiles.input_error(document)
		if not error.is_empty():
			return _fail("%s: %s" % [options[option], error])
		if option == "--scenario":
			scenario = document
		else:
			frames = document.frames
	var output := FileAccess.open(options["--out"], FileAccess.WRITE)
	if output == null:
		return _fail("cannot write '%s' (%s)" % [options["--out"], error_string(FileAccess.get_open_error())], 1)
	var ticks := int(options["--ticks"])
	var interval := int(options.get("--snapshot-every", "10"))
	var night := Night.new(int(options["--seed"]), scenario)
	var inputs := {}
	var frame_index := 0
	_write(output, night.snapshot())
	while night.tick < ticks and night.state == "playing":
		if frame_index < frames.size() and int(frames[frame_index].tick) == night.tick:
			_apply_frame(inputs, frames[frame_index])
			frame_index += 1
		for event in night.step(inputs):
			_write(output, event)
		if night.tick % interval == 0:
			_write(output, night.snapshot())
	_write(output, {"type": "end", "ticks": night.tick, "state": night.state, "score": night.score})
	output.flush()
	if output.get_error() != OK:
		return _fail("failed writing '%s'" % options["--out"], 1)
	return 0


func _parse_options(arguments: PackedStringArray) -> Dictionary:
	if arguments.size() % 2 != 0:
		return {}
	var parsed := {}
	for index in range(0, arguments.size(), 2):
		var name := arguments[index]
		if name not in OPTIONS or parsed.has(name) or arguments[index + 1].is_empty():
			return {}
		parsed[name] = arguments[index + 1]
	for name in ["--seed", "--night", "--ticks"]:
		if not parsed.has(name) or not String(parsed[name]).is_valid_int():
			return {}
	var interval: String = parsed.get("--snapshot-every", "10")
	if int(parsed["--night"]) != 1 or not parsed.has("--out") or int(parsed["--ticks"]) < 0:
		return {}
	if not interval.is_valid_int() or int(interval) < 1:
		return {}
	return parsed


func _apply_frame(inputs: Dictionary, frame: Dictionary) -> void:
	for key: String in frame:
		if key == "move":
			inputs.move = Vector2(frame.move[0], frame.move[1])
		elif key != "tick":
			inputs[key] = frame[key]


func _write(output: FileAccess, record: Dictionary) -> void:
	output.store_line(JSON.stringify(record))


func _fail(message: String, status: int = 2) -> int:
	printerr("headless: " + message)
	return status

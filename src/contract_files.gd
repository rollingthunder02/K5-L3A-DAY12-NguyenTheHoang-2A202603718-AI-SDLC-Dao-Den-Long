extends RefCounted

const Night := preload("res://src/night.gd")
const Map := preload("res://src/island_map.gd")
const ACTIONS := Night.BUTTONS
const JSON_TOKEN := r'\G(?:[ \t\r\n]+|"(?:[^"\\\x00-\x1f]|\\(?:["\\/bfnrt]|u[0-9A-Fa-f]{4}))*"|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?|true|false|null|[{}\[\],:])'


static func read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "cannot read '%s' (%s)" % [path, error_string(FileAccess.get_open_error())]}
	var parser := JSON.new()
	var text := file.get_as_text().trim_prefix("\ufeff")
	if parser.parse(text) != OK:
		return {"error": "%s:%d: %s" % [path, parser.get_error_line(), parser.get_error_message()]}
	if not _strict_json_tokens(text):
		return {"error": "%s: invalid JSON syntax" % path}
	if not parser.data is Dictionary:
		return {"error": "%s: root must be an object" % path}
	return {"data": parser.data}


static func _strict_json_tokens(text: String) -> bool:
	# Godot accepts trailing commas and some non-JSON literals. Check their spelling here.
	var tokenizer := RegEx.create_from_string(JSON_TOKEN)
	var previous := ""
	var previous_scalar := false
	var offset := 0
	for token in tokenizer.search_all(text):
		if token.get_start() != offset:
			return false
		offset = token.get_end()
		var first := token.get_string()[0]
		if first in [" ", "\t", "\r", "\n"]:
			continue
		var scalar := first not in ["{", "}", "[", "]", ",", ":"]
		if (previous == "," and first in ["}", "]"]) or (previous_scalar and scalar):
			return false
		previous = first
		previous_scalar = scalar
	return offset == text.length()


static func input_error(document: Dictionary) -> String:
	if not document.get("frames") is Array:
		return "frames must be an array"
	var previous_tick := -1
	for frame: Variant in document.frames:
		if not frame is Dictionary or not _nonnegative_integer(frame.get("tick")):
			return "each input frame needs a non-negative integer tick"
		var frame_tick := int(frame.tick)
		if frame_tick <= previous_tick:
			return "frame ticks must be strictly increasing"
		previous_tick = frame_tick
		if frame.has("move"):
			if not _vector(frame.move, 2) or absf(frame.move[0]) > 1.0 or absf(frame.move[1]) > 1.0:
				return "frame %d move must contain two numbers in [-1, 1]" % frame_tick
		if frame.has("cam_yaw_deg") and not _number(frame.cam_yaw_deg):
			return "frame %d cam_yaw_deg must be a number" % frame_tick
		for action: String in ACTIONS:
			if frame.has(action) and not frame[action] is bool:
				return "frame %d %s must be a boolean" % [frame_tick, action]
	return ""


static func scenario_error(document: Dictionary, night_number: int) -> String:
	for flag in ["random_motes", "random_shades", "random_drifters", "wind_enabled"]:
		if document.has(flag) and not document[flag] is bool:
			return "%s must be a boolean" % flag
	if document.has("time_left_s"):
		if not _number(document.time_left_s) or float(document.time_left_s) < 0.0:
			return "time_left_s must be a non-negative number"
	if document.has("player"):
		if not document.player is Dictionary:
			return "player must be an object"
		var error := _entity_error(document.player, false,
			["carried", "flames", "invuln_ticks", "dash_cd_ticks", "pulse_cd_ticks", "charm_ticks"])
		if not error.is_empty():
			return "player: " + error
		if document.player.has("vel") and not _vector(document.player.vel, 3):
			return "player: vel must be a three-component vector"
	if document.has("motes"):
		if not document.motes is Array:
			return "motes must be an array"
		for point: Variant in document.motes:
			if point is Dictionary:
				if point.get("kind", "random") not in ["random", "dropped"] or not _entity_error(point, true, ["ttl_ticks"]).is_empty():
					return "each mote needs a position, a valid kind and an optional ttl_ticks"
			elif not _vector(point, 3):
				return "each mote must be an [x, y, z] position"
	for name in ["shades", "lanterns", "drifters", "charms"]:
		if document.has(name):
			var error := _list_error(document[name], name, night_number)
			if not error.is_empty():
				return name + ": " + error
	return ""


static func _list_error(value: Variant, name: String, night_number: int) -> String:
	if not value is Array:
		return "must be an array"
	var ids := {}
	for entity: Variant in value:
		if not entity is Dictionary:
			return "each entry must be an object"
		if entity.has("id"):
			if not entity.id is String or entity.id.is_empty() or ids.has(entity.id):
				return "ids must be non-empty, unique strings"
			ids[entity.id] = true
		var integer_fields := []
		match name:
			"lanterns":
				var count: int = Map.LANTERNS[night_number - 1].size()
				var id: String = entity.get("id", "")
				var index := id.substr(1).to_int()
				if id != "L%d" % index or index < 1 or index > count:
					return "each lantern needs an id for the selected night"
				if entity.has("lit") and not entity.lit is bool:
					return "lit must be a boolean"
				integer_fields = ["deposited"]
			"charms":
				if entity.has("available") and not entity.available is bool:
					return "available must be a boolean"
				integer_fields = ["respawn_ticks", "respawn_ticks_left"]
			"shades", "drifters":
				var states := Night.SHADE_STATES if name == "shades" else Night.DRIFTER_STATES
				if entity.has("state") and entity.state not in states:
					return "unrecognized state"
				integer_fields = ["state_ticks_left"] if name == "shades" else ["state_ticks_left", "stolen"]
		var error := _entity_error(entity, name in ["shades", "drifters"], integer_fields)
		if not error.is_empty():
			return error
	return ""


static func _entity_error(entity: Dictionary, requires_position: bool, integer_fields: Array) -> String:
	if (requires_position or entity.has("pos")) and not _vector(entity.get("pos"), 3):
		return "pos must be an [x, y, z] position"
	for field: String in integer_fields:
		if entity.has(field) and not _nonnegative_integer(entity[field]):
			return "%s must be a non-negative integer" % field
	return ""


static func _vector(value: Variant, size: int) -> bool:
	if not value is Array or value.size() != size:
		return false
	for component: Variant in value:
		if not _number(component) or absf(float(component)) > 1.0e30:
			return false
	return true


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _nonnegative_integer(value: Variant) -> bool:
	return _number(value) and value >= 0 and value < 9.223372036854776e18 and floorf(value) == value

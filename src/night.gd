extends RefCounted

const TICKS_PER_SECOND := 60
const STEP := 1.0 / TICKS_PER_SECOND
const ISLAND_RADIUS := 34.0
const JUMP_SPEED := 7.4
const GRAVITY := 22.0
const BUTTONS := ["jump", "interact", "pulse"]
const LANTERN_POSITIONS := [
	Vector3(0, 0, 8), Vector3(14, 0, 5), Vector3(10, 0, -15),
	Vector3(-11, 0, -13), Vector3(-17, 0, 7),
]
const SHADE_SPAWN_TICKS := [300, 780, 1440, 2400]

var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game.contract.json"))["tuning"]
var tick := 0
var state := "playing"
var score := 0
var player_pos := Vector3.ZERO
var carried := 0
var flames := 0
var lanterns: Array[Dictionary] = []
var motes: Array[Dictionary] = []
var shades: Array[Dictionary] = []

var _duration: float
var _vertical_speed := 0.0
var _invulnerable_until := 0
var _pulse_ready_at := 0
var _held_buttons := {}
var _mote_rng := RandomNumberGenerator.new()
var _shade_rng := RandomNumberGenerator.new()
var _spawn_random_shades: bool
var _replenish_motes: bool
var _shade_ids := {}
var _mote_serial := 0
var _shade_serial := 0


func _init(seed_value: int, scenario: Dictionary = {}) -> void:
	_mote_rng.seed = seed_value
	_shade_rng.seed = seed_value ^ 456791
	_duration = float(scenario.get("time_left_s", tuning.night1_duration_s))
	var player: Dictionary = scenario.get("player", {})
	player_pos = _vector(player.get("pos", [0, 0, 0]))
	carried = int(player.get("carried", 0))
	flames = int(player.get("flames", tuning.flames))
	_setup_lanterns(scenario.get("lanterns", []))
	if scenario.has("motes"):
		for point: Array in scenario.motes:
			_add_mote(_vector(point))
	elif scenario.get("random_motes", true):
		_scatter_motes()
	_replenish_motes = scenario.get("random_motes", true) and not scenario.has("motes")
	_spawn_random_shades = scenario.get("random_shades", not scenario.has("shades"))
	for shade: Dictionary in scenario.get("shades", []):
		if shade.has("id"):
			_shade_ids[shade.id] = true
	for shade: Dictionary in scenario.get("shades", []):
		_add_shade(_vector(shade.pos), shade.get("id", ""))


func time_left() -> float:
	return maxf(0.0, _duration - tick / float(TICKS_PER_SECOND))


func lit_count() -> int:
	var count := 0
	for lantern in lanterns:
		count += int(lantern.lit)
	return count


func step(input: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if state != "playing":
		return events
	var already_out_of_time := time_left() == 0.0
	tick += 1
	if already_out_of_time or flames == 0 or lit_count() == lanterns.size():
		_finish_if_needed(events)
		return events

	var pressed := {}
	for button: String in BUTTONS:
		var held: bool = input.get(button, false)
		pressed[button] = held and not _held_buttons.get(button, false)
		_held_buttons[button] = held

	_move_player(input.get("move", Vector2.ZERO), input.get("cam_yaw_deg", 0.0), pressed.jump)
	_pick_up_motes(events)
	if pressed.interact:
		_deposit(events)
	if pressed.pulse:
		_pulse(events)
	if lit_count() == lanterns.size():
		_finish_if_needed(events)
		return events
	if _replenish_motes and tick % 240 == 0 and motes.size() < 32:
		for index in range(6):
			_add_mote(_random_point(_mote_rng, 5.0, 29.0))
	if _spawn_random_shades and tick in SHADE_SPAWN_TICKS:
		_spawn_shade(events)
	_update_shades(events)
	_finish_if_needed(events)
	return events


func nearest_lantern() -> Dictionary:
	var nearest := {}
	var distance_limit := float(tuning.interact_radius) ** 2
	for lantern in lanterns:
		var distance := _horizontal_squared(player_pos, lantern.pos)
		if not lantern.lit and distance <= distance_limit + 0.00001:
			if nearest.is_empty() or distance < distance_limit:
				nearest = lantern
				distance_limit = distance
	return nearest


func player_is_protected() -> bool:
	return tick < _invulnerable_until


func pulse_ready() -> bool:
	return tick >= _pulse_ready_at and carried >= int(tuning.pulse_cost)


func snapshot() -> Dictionary:
	var lamps: Array[Dictionary] = []
	var enemies: Array[Dictionary] = []
	var lights: Array[Dictionary] = []
	for lantern in lanterns:
		lamps.append({"id": lantern.id, "pos": _coordinates(lantern.pos),
			"lit": lantern.lit, "deposited": lantern.deposited})
	for shade in shades:
		enemies.append({"id": shade.id, "pos": _coordinates(shade.pos), "state": shade.state})
	for mote in motes:
		lights.append({"id": mote.id, "pos": _coordinates(mote.pos)})
	return {
		"type": "snapshot", "tick": tick, "sim_tick": tick, "state": state,
		"time_left_s": time_left(), "score": score,
		"player": {"pos": _coordinates(player_pos), "flames": flames, "carried": carried},
		"lanterns": lamps, "shades": enemies, "motes_active": lights.size(), "motes": lights,
	}


func _setup_lanterns(overrides: Array) -> void:
	var cost := int(tuning.lantern_cost)
	for index in range(LANTERN_POSITIONS.size()):
		lanterns.append({"id": "L%d" % (index + 1), "pos": LANTERN_POSITIONS[index],
			"lit": false, "deposited": 0})
	for change: Dictionary in overrides:
		var index := int(String(change.id).substr(1)) - 1
		var lantern := lanterns[index]
		if change.has("pos"):
			lantern.pos = _vector(change.pos)
		var amount := int(change.get("deposited", cost if change.get("lit", false) else 0))
		lantern.deposited = amount
		lantern.lit = change.get("lit", amount >= cost)


func _scatter_motes() -> void:
	for lantern in lanterns:
		var approach: Vector3 = lantern.pos.normalized()
		var side := Vector3(approach.z, 0.0, -approach.x)
		for index in range(7):
			var offset := side * _mote_rng.randf_range(-1.6, 1.6)
			_add_mote(lantern.pos - approach * (1.5 + index * 0.85) + offset)
	for index in range(25):
		_add_mote(_random_point(_mote_rng, 5.0, 29.0))


func _random_point(rng: RandomNumberGenerator, minimum: float, maximum: float) -> Vector3:
	var angle := rng.randf_range(0.0, TAU)
	var radius := rng.randf_range(minimum, maximum)
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _add_mote(pos: Vector3) -> void:
	_mote_serial += 1
	motes.append({"id": "M%d" % _mote_serial, "pos": pos})


func _add_shade(pos: Vector3, id: String = "") -> String:
	if id.is_empty():
		while id.is_empty() or _shade_ids.has(id):
			_shade_serial += 1
			id = "S%d" % _shade_serial
	_shade_ids[id] = true
	shades.append({"id": id, "pos": pos, "state": "chase", "stunned_until": 0})
	return id


func _spawn_shade(events: Array[Dictionary]) -> void:
	var point := _random_point(_shade_rng, 23.0, 30.0)
	if _horizontal_squared(point, player_pos) < 81.0:
		point = -point
	point.y = 0.65
	_emit(events, "shade_spawned", {"id": _add_shade(point)})


func _move_player(move: Vector2, yaw_deg: float, jump: bool) -> void:
	var movement := move.limit_length()
	var direction := Vector3(movement.x, 0, movement.y).rotated(Vector3.UP, deg_to_rad(fposmod(yaw_deg, 360.0)))
	var position := player_pos + direction * float(tuning.player_speed) * STEP
	# The rim is a guard boundary. A scenario outside it may still walk toward the island.
	var limit := maxf(ISLAND_RADIUS - 0.65, Vector2(player_pos.x, player_pos.z).length())
	var horizontal := Vector2(position.x, position.z).limit_length(limit)
	position.x = horizontal.x
	position.z = horizontal.y
	position.y = maxf(0.0, position.y)
	if jump and position.y == 0.0:
		_vertical_speed = JUMP_SPEED
	if position.y > 0.0 or _vertical_speed > 0.0:
		position.y = maxf(0.0, position.y + _vertical_speed * STEP)
		_vertical_speed -= GRAVITY * STEP
		if position.y == 0.0:
			_vertical_speed = 0.0
	player_pos = position


func _pick_up_motes(events: Array[Dictionary]) -> void:
	var radius := float(tuning.pickup_radius)
	var index := 0
	while index < motes.size() and carried < int(tuning.carry_capacity):
		if _within(player_pos, motes[index].pos, radius):
			motes.remove_at(index)
			carried += 1
			score += int(tuning.score.per_mote)
			_emit(events, "mote_picked", {"carried": carried})
		else:
			index += 1


func _deposit(events: Array[Dictionary]) -> void:
	var lantern := nearest_lantern()
	if lantern.is_empty() or carried == 0:
		return
	var cost := int(tuning.lantern_cost)
	var amount := mini(carried, maxi(0, cost - int(lantern.deposited)))
	if amount > 0:
		carried -= amount
		lantern.deposited += amount
		_emit(events, "deposit", {"lantern_id": lantern.id, "amount": amount,
			"deposited": lantern.deposited})
	if int(lantern.deposited) >= cost:
		lantern.lit = true
		score += int(tuning.score.per_lantern)
		_emit(events, "lantern_lit", {"lantern_id": lantern.id})


func _pulse(events: Array[Dictionary]) -> void:
	if not pulse_ready():
		return
	carried -= int(tuning.pulse_cost)
	_pulse_ready_at = tick + _ticks_for(tuning.pulse_cooldown_s)
	var ids: Array[String] = []
	for shade in shades:
		var position: Vector3 = shade.pos
		if _within(player_pos, position, float(tuning.pulse_radius)):
			var direction := _away_from(position, player_pos)
			shade.pos = position + direction * float(tuning.pulse_push_m)
			shade.stunned_until = tick + _ticks_for(tuning.pulse_stun_s)
			shade.state = "stunned"
			ids.append(shade.id)
			score += int(tuning.score.per_stun)
	_emit(events, "pulse", {"stunned_ids": ids})


func _update_shades(events: Array[Dictionary]) -> void:
	var player_safe := _in_lit_radius(player_pos)
	for shade in shades:
		var position: Vector3 = shade.pos
		if tick >= int(shade.stunned_until):
			shade.state = "chase"
			var target := Vector3(player_pos.x, position.y, player_pos.z)
			position = position.move_toward(target, float(tuning.shade_speed) * STEP)
		shade.pos = _outside_lit_radii(position, shade.pos, player_safe)
		if shade.state == "chase" and not player_safe and not player_is_protected():
			if _within(player_pos, shade.pos, float(tuning.shade_hit_radius)):
				_take_hit(events)


func _outside_lit_radii(position: Vector3, previous: Vector3, player_safe: bool) -> Vector3:
	var radius := float(tuning.safe_radius)
	# Project out of overlapping circles as well. A normal move may graze a zone.
	for pass_index in range(lanterns.size()):
		var adjusted := false
		for lantern in lanterns:
			if not lantern.lit or not _within(position, lantern.pos, radius):
				continue
			var center: Vector3 = lantern.pos
			var normal := _away_from(position, center)
			if not player_safe and not _within(previous, center, radius):
				var tangent := Vector3(-normal.z, 0.0, normal.x)
				var sign_toward_player := 1.0 if tangent.dot(player_pos - position) >= 0.0 else -1.0
				normal = (normal * radius + tangent * sign_toward_player * float(tuning.shade_speed) * STEP).normalized()
			position = Vector3(center.x, position.y, center.z) + normal * (radius + 0.002)
			adjusted = true
		if not adjusted:
			break
	return position


func _in_lit_radius(pos: Vector3) -> bool:
	for lantern in lanterns:
		if lantern.lit and _within(pos, lantern.pos, float(tuning.safe_radius)):
			return true
	return false


func _take_hit(events: Array[Dictionary]) -> void:
	flames -= 1
	var dropped := floori(carried * float(tuning.hit_drop_ratio))
	carried -= dropped
	_invulnerable_until = tick + _ticks_for(tuning.invuln_s)
	_emit(events, "player_hit", {"by": "shade", "flames": flames, "dropped": dropped})


func _finish_if_needed(events: Array[Dictionary]) -> void:
	var reason := ""
	if lit_count() == lanterns.size():
		state = "won"
		reason = "all_lit"
		score += floori(time_left()) * int(tuning.score.per_second_left)
		score += flames * int(tuning.score.per_flame_left)
	elif flames <= 0:
		state = "lost"
		reason = "no_flames"
	elif time_left() == 0.0:
		state = "lost"
		reason = "dawn"
	if not reason.is_empty():
		_emit(events, "game_over", {"result": state, "reason": reason})


func _emit(events: Array[Dictionary], name: String, data: Dictionary) -> void:
	events.append({"type": "event", "tick": tick, "name": name, "data": data})


static func _away_from(point: Vector3, center: Vector3) -> Vector3:
	var difference := Vector3(point.x - center.x, 0.0, point.z - center.z)
	return Vector3.RIGHT if difference.length_squared() < 0.00000001 else difference.normalized()


static func _within(a: Vector3, b: Vector3, radius: float) -> bool:
	return _horizontal_squared(a, b) <= radius * radius + 0.00001


static func _horizontal_squared(a: Vector3, b: Vector3) -> float:
	return (a.x - b.x) ** 2 + (a.z - b.z) ** 2


static func _ticks_for(seconds: float) -> int:
	return roundi(seconds * TICKS_PER_SECOND)


static func _vector(point: Array) -> Vector3:
	return Vector3(point[0], point[1], point[2])


static func _coordinates(point: Vector3) -> Array[float]:
	return [roundf(point.x * 1000.0) / 1000.0, roundf(point.y * 1000.0) / 1000.0,
		roundf(point.z * 1000.0) / 1000.0]

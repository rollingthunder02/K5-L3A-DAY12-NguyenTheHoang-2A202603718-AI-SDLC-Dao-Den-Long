extends RefCounted

const Map := preload("res://src/island_map.gd")
const TICKS_PER_SECOND := 60
const STEP := 1.0 / TICKS_PER_SECOND
const BUTTONS := ["jump", "interact", "pulse", "dash", "pause"]
const HEIGHT_RANGE := 1.5
const SPAWN_PERIODS := [480, 420, 360]
const SHADE_CAPS := [6, 8, 10]
const SHADE_STATES := ["spawning", "wander", "chase", "recoil", "stunned"]
const DRIFTER_STATES := ["idle", "chase", "flee", "removed"]

var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game.contract.json"))["tuning"]
var number: int
var tick := 0
var sim_tick := 0
var state := "playing"
var score := 0
var player_pos := Vector3.ZERO
var velocity := Vector3.ZERO
var facing := Vector3(0, 0, 1)
var grounded := true
var carried := 0
var flames := 0
var lanterns: Array[Dictionary] = []
var motes: Array[Dictionary] = []
var shades: Array[Dictionary] = []
var drifters: Array[Dictionary] = []
var charms: Array[Dictionary] = []
var wind_active := false
var wind_warning := false
var wind_dir_deg := 0.0
var dash_direction := Vector3.ZERO
var respawn_at := 0

var _duration: float
var _vy := 0.0
var _launch := Vector3.ZERO
var _pad_contact := -1
var _invulnerable_until := 0
var _pulse_ready_at := 0
var _dash_ready_at := 0
var _dash_until := 0
var _charm_until := 0
var _held := {}
var _mote_rng := RandomNumberGenerator.new()
var _shade_rng := RandomNumberGenerator.new()
var _drifter_rng := RandomNumberGenerator.new()
var _wind_rng := RandomNumberGenerator.new()
var _random_shades: bool
var _random_motes: bool
var _random_drifters: bool
var _wind_enabled: bool
var _mote_points: Array[Vector3]
var _shade_points: Array[Vector3]
var _occupied := {}
var _used_ids := {}
var _serials := {}


func _init(seed_value: int, scenario: Dictionary = {}, night_number: int = 1) -> void:
	number = night_number
	_mote_rng.seed = seed_value
	_shade_rng.seed = seed_value ^ 456791
	_drifter_rng.seed = seed_value ^ 179281
	_wind_rng.seed = seed_value ^ 100571
	_mote_points = Map.mote_points(number)
	_shade_points = Map.shade_points(number)
	_duration = float(scenario.get("time_left_s", tuning["night%d_duration_s" % number]))
	_random_motes = scenario.get("random_motes", not scenario.has("motes"))
	_random_shades = scenario.get("random_shades", not scenario.has("shades"))
	_random_drifters = number > 1 and scenario.get("random_drifters", not scenario.has("drifters"))
	_wind_enabled = number == 3 and scenario.get("wind_enabled", true)
	var player: Dictionary = scenario.get("player", {})
	player_pos = _vector(player.get("pos", [0, 0, 0]))
	velocity = _vector(player.get("vel", [0, 0, 0]))
	_vy = velocity.y
	grounded = absf(Map.floor_below(number, player_pos, player_pos.y) - player_pos.y) <= Map.EPS and _vy <= 0.0
	carried = int(player.get("carried", 0))
	flames = int(player.get("flames", tuning.flames))
	_invulnerable_until = int(player.get("invuln_ticks", 0))
	_dash_ready_at = int(player.get("dash_cd_ticks", 0))
	_pulse_ready_at = int(player.get("pulse_cd_ticks", 0))
	_charm_until = int(player.get("charm_ticks", 0))
	_setup_lanterns(scenario.get("lanterns", []))
	if scenario.has("motes"):
		for entry: Variant in scenario.motes:
			if entry is Array:
				var position := _vector(entry)
				_add_mote(position, 0, _point_index(position))
			else:
				var position := _vector(entry.pos)
				var dropped: bool = entry.get("kind", "random") == "dropped"
				_add_mote(position, int(entry.get("ttl_ticks", 480)) if dropped else 0,
					_point_index(position) if not dropped else -1)
	elif _random_motes:
		for index in range(20):
			_spawn_mote()
	_reserve_ids(scenario.get("shades", []))
	_reserve_ids(scenario.get("drifters", []))
	_reserve_ids(scenario.get("charms", []))
	for shade: Dictionary in scenario.get("shades", []):
		_add_shade(_vector(shade.pos), shade.get("id", ""), shade.get("state", "chase"), int(shade.get("state_ticks_left", -1)))
	for drifter: Dictionary in scenario.get("drifters", []):
		_add_drifter(_vector(drifter.pos), drifter.get("id", ""), drifter.get("state", "idle"),
			int(drifter.get("stolen", 0)), int(drifter.get("state_ticks_left", -1)))
	if scenario.has("charms"):
		for entry: Dictionary in scenario.charms:
			var id: String = entry.get("id", "")
			var index := int(id.substr(1)) - 1 if id.begins_with("C") else charms.size()
			var positions: Array = Map.CHARMS[number - 1]
			var default_pos: Vector3 = positions[index] if index >= 0 and index < positions.size() else Vector3.ZERO
			var pos := _vector(entry.pos) if entry.has("pos") else default_pos
			var cooldown := int(entry.get("respawn_ticks", entry.get("respawn_ticks_left", 2700)))
			_add_charm(pos, id, 0 if entry.get("available", cooldown == 2700 and not entry.has("respawn_ticks") and not entry.has("respawn_ticks_left")) else maxi(1, cooldown))
	else:
		for point: Vector3 in Map.CHARMS[number - 1]:
			_add_charm(point)


func step(input: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if finished():
		return events
	tick += 1
	var pressed := {}
	for button: String in BUTTONS:
		var held: bool = input.get(button, false)
		pressed[button] = held and not _held.get(button, false)
		_held[button] = held
	if pressed.pause:
		state = "playing" if state == "paused" else "paused"
		_emit(events, "paused" if state == "paused" else "resumed", {})
	if state == "paused":
		return events
	sim_tick += 1
	_advance_timers()
	var can_interact := respawn_at == 0 and flames > 0
	if can_interact:
		_move_player(input.get("move", Vector2.ZERO), input.get("cam_yaw_deg", 0.0), pressed, events)
		if player_pos.y < -10.0:
			_take_fall(events)
			can_interact = false
	elif respawn_at > 0 and sim_tick >= respawn_at and flames > 0:
		_respawn()
	if can_interact:
		_pick_up(events)
		if pressed.interact:
			_deposit(events)
	_update_safe_zones()
	if can_interact and pressed.pulse:
		_pulse(events)
	_move_shades(can_interact)
	_move_drifters(can_interact)
	if can_interact:
		_drifter_contacts(events)
		_shade_contacts(events)
	_scheduled_spawns(events)
	_finish_if_needed(events)
	return events


func finished() -> bool:
	return state == "won" or state == "lost"


func resume_from_menu() -> void:
	if state == "paused":
		state = "playing"


func time_left() -> float:
	return maxf(0.0, _duration - float(sim_tick) / TICKS_PER_SECOND)


func lit_count() -> int:
	var count := 0
	for lantern in lanterns:
		count += int(lantern.lit)
	return count


func nearest_lantern(in_reach: bool = true) -> Dictionary:
	var nearest := {}
	var distance_limit := float(tuning.interact_radius) ** 2 if in_reach else INF
	for lamp in lanterns:
		var distance := Map.planar_sq(player_pos, lamp.pos)
		if not lamp.lit and distance <= distance_limit + Map.EPS:
			if nearest.is_empty() or distance < distance_limit - Map.EPS:
				nearest = lamp
				distance_limit = distance
	return nearest


func player_is_protected() -> bool:
	return sim_tick < _invulnerable_until


func dash_cooldown() -> float:
	return _seconds_until(_dash_ready_at)


func pulse_cooldown() -> float:
	return _seconds_until(_pulse_ready_at)


func charm_left() -> float:
	return _seconds_until(_charm_until)


func snapshot() -> Dictionary:
	var lamps: Array[Dictionary] = []
	var enemies: Array[Dictionary] = []
	var lights: Array[Dictionary] = []
	var thieves: Array[Dictionary] = []
	var tokens: Array[Dictionary] = []
	for lamp in lanterns:
		lamps.append({"id": lamp.id, "pos": _coordinates(lamp.pos), "lit": lamp.lit, "deposited": lamp.deposited})
	for shade in shades:
		enemies.append({"id": shade.id, "pos": _coordinates(shade.pos), "state": shade.state})
	for mote in motes:
		lights.append({"id": mote.id, "pos": _coordinates(mote.pos), "kind": mote.kind,
			"ttl_s": _seconds_until(mote.expires) if mote.kind == "dropped" else null})
	for drifter in drifters:
		thieves.append({"id": drifter.id, "pos": _coordinates(drifter.pos), "state": drifter.state, "stolen": drifter.stolen})
	for charm in charms:
		tokens.append({"id": charm.id, "pos": _coordinates(charm.pos), "available": sim_tick >= int(charm.ready),
			"respawn_s": _seconds_until(charm.ready)})
	return {
		"type": "snapshot", "tick": tick, "sim_tick": sim_tick, "state": state, "night": number,
		"time_left_s": time_left(), "score": score, "wind": {"active": wind_active, "dir_deg": wind_dir_deg},
		"player": {"pos": _coordinates(player_pos), "vel": _coordinates(velocity), "grounded": grounded,
			"flames": flames, "carried": carried, "invuln": player_is_protected(), "dash_cd_s": dash_cooldown(),
			"pulse_cd_s": pulse_cooldown(), "charm_s": charm_left()},
		"lanterns": lamps, "shades": enemies, "drifters": thieves, "charms": tokens,
		"motes_active": lights.size(), "motes": lights,
	}


func _advance_timers() -> void:
	for index in range(motes.size() - 1, -1, -1):
		if motes[index].kind == "dropped" and sim_tick >= int(motes[index].expires):
			motes.remove_at(index)
	if _wind_enabled:
		var phase := sim_tick % 1800
		if phase == 1680:
			wind_dir_deg = _wind_rng.randf_range(0.0, 360.0)
		wind_warning = phase >= 1680
		wind_active = sim_tick >= 1800 and phase < 300


func _move_player(move: Vector2, yaw_deg: float, pressed: Dictionary, events: Array[Dictionary]) -> void:
	var stick := move.limit_length()
	var direction := Vector3(stick.x, 0, stick.y).rotated(Vector3.UP, deg_to_rad(fposmod(yaw_deg, 360.0)))
	if direction.length_squared() > Map.EPS ** 2 and sim_tick >= _dash_until and _launch == Vector3.ZERO:
		facing = direction.normalized()
	_maybe_launch()
	if pressed.jump and grounded:
		_vy = float(tuning.jump_speed)
		grounded = false
		_emit(events, "jump", {})
	if pressed.dash and sim_tick >= _dash_until and (sim_tick >= _dash_ready_at or charm_left() > 0.0):
		dash_direction = facing
		if _launch != Vector3.ZERO:
			dash_direction = _launch.normalized()
		elif direction.length_squared() > Map.EPS ** 2:
			dash_direction = direction.normalized()
		facing = dash_direction
		_dash_until = sim_tick + _ticks_for(tuning.dash_duration_s)
		_dash_ready_at = sim_tick + _ticks_for(tuning.dash_cooldown_s) if charm_left() == 0.0 else sim_tick
		_emit(events, "dash", {})
	var dashing := sim_tick < _dash_until
	var flat := dash_direction * float(tuning.dash_speed) if dashing else _launch
	if not dashing and _launch == Vector3.ZERO:
		flat = direction * (7.2 if charm_left() > 0.0 else float(tuning.player_speed))
	if wind_active:
		var angle := deg_to_rad(wind_dir_deg)
		flat += Vector3(cos(angle), 0, sin(angle)) * 2.0
	var previous := player_pos
	var target := player_pos + flat * STEP
	if not Map.allow_player_step(number, previous, target, grounded):
		target = previous
	var support := Map.floor_below(number, target, previous.y)
	var follows_ramp := false
	if grounded and number == 3:
		var ramp_from := Map.ramp_height(previous)
		var ramp := Map.ramp_height(target)
		var ramp_step := sqrt(Map.planar_sq(previous, target)) * 0.5 + Map.EPS
		var on_ramp := absf(ramp_from - previous.y) <= Map.EPS
		follows_ramp = (on_ramp and (ramp != Map.VOID or previous.y <= ramp_step)) \
			or (Map.on_terrace(previous) and previous.y == 3.0 and ramp >= 3.0 - ramp_step)
		if ramp != Map.VOID and (follows_ramp or ramp >= previous.y - Map.EPS):
			support = maxf(support, ramp)
		# Walking over the upper lip of a ramp can land on the terrace.
		if previous.y >= 2.9 and on_ramp and Map.on_terrace(target):
			support = maxf(support, 3.0)
	if grounded and support != Map.VOID and (follows_ramp or support >= previous.y - Map.EPS):
		target.y = support
	elif dashing:
		grounded = false
	else:
		var gravity := float(tuning.gravity)
		target.y = previous.y + _vy * STEP + 0.5 * gravity * STEP * STEP
		_vy += gravity * STEP
		grounded = false
		if _vy <= 0.0 and support != Map.VOID and target.y <= support + Map.EPS:
			target.y = support
			grounded = true
			_vy = 0.0
			_launch = Vector3.ZERO
	player_pos = target
	velocity = Vector3((target.x - previous.x) / STEP, 0.0 if dashing else _vy, (target.z - previous.z) / STEP)
	_maybe_launch()


func _maybe_launch() -> void:
	var pads: Array = Map.PADS[number - 1]
	var pad_index := -1
	for index in range(pads.size()):
		var pad: Vector3 = pads[index]
		if absf(player_pos.y - pad.y) <= 0.04 and Map.in_xz(player_pos, pad, 1.0):
			pad_index = index
			break
	if not grounded:
		if pad_index < 0:
			_pad_contact = -1
		return
	if pad_index >= 0 and pad_index != _pad_contact:
		if number == 2:
			var center := Map.EAST if pad_index == 0 else Vector3.ZERO
			_launch = Map.away(center, player_pos) * 24.0
			_vy = 14.0
		else:
			_launch = Vector3(0, 0, -8)
			_vy = 12.0
		facing = _launch.normalized()
		grounded = false
		velocity = _launch + Vector3.UP * _vy
	_pad_contact = pad_index


func _take_fall(events: Array[Dictionary]) -> void:
	var lost := carried
	carried = 0
	flames -= 1
	velocity = Vector3.ZERO
	_vy = 0.0
	_launch = Vector3.ZERO
	grounded = false
	_dash_until = sim_tick
	respawn_at = sim_tick + 60
	_emit(events, "player_hit", {"by": "fall", "flames": flames, "dropped": 0, "lost": lost})


func _respawn() -> void:
	respawn_at = 0
	player_pos = Vector3.ZERO
	velocity = Vector3.ZERO
	facing = Vector3(0, 0, 1)
	grounded = true
	_invulnerable_until = sim_tick + _ticks_for(tuning.invuln_s)
	_pad_contact = -1


func _pick_up(events: Array[Dictionary]) -> void:
	var index := 0
	while index < motes.size() and carried < int(tuning.carry_capacity):
		var mote := motes[index]
		if sim_tick >= int(mote.pickable) and _touches(mote.pos, float(tuning.pickup_radius)):
			if mote.point >= 0:
				_occupied.erase(mote.point)
			motes.remove_at(index)
			carried += 1
			_emit(events, "mote_picked", {"carried": carried})
		else:
			index += 1
	for charm in charms:
		if sim_tick >= int(charm.ready) and _touches(charm.pos, float(tuning.pickup_radius)):
			charm.ready = sim_tick + 2700
			_charm_until = sim_tick + 600
			_dash_ready_at = sim_tick
			_emit(events, "charm_picked", {"charm_id": charm.id, "charm_ticks": 600})


func _deposit(events: Array[Dictionary]) -> void:
	var lamp := nearest_lantern()
	if lamp.is_empty() or carried == 0:
		return
	var needed := int(tuning.lantern_cost)
	var amount := mini(carried, maxi(0, needed - int(lamp.deposited)))
	if amount > 0:
		carried -= amount
		lamp.deposited += amount
		score += amount * int(tuning.score.per_mote)
		_emit(events, "deposit", {"lantern_id": lamp.id, "amount": amount, "deposited": lamp.deposited})
	if int(lamp.deposited) >= needed:
		lamp.lit = true
		lamp.lit_at = sim_tick
		score += int(tuning.score.per_lantern)
		_emit(events, "lantern_lit", {"lantern_id": lamp.id})


func _update_safe_zones() -> void:
	for shade in shades:
		var zone := _safe_lamp(shade.pos)
		if zone.is_empty() or int(shade.evict_at) > 0:
			continue
		var direction := Map.away(shade.pos, zone.pos)
		var target: Vector3 = zone.pos + direction * (float(tuning.safe_radius) + 0.002)
		target.y = shade.pos.y
		if int(zone.lit_at) == sim_tick:
			shade.evict_at = sim_tick + 29
			shade.evict_target = target
		else:
			shade.pos = _outside_light(target)


func _pulse(events: Array[Dictionary]) -> void:
	if sim_tick < _pulse_ready_at or carried < int(tuning.pulse_cost):
		return
	carried -= int(tuning.pulse_cost)
	_pulse_ready_at = sim_tick + _ticks_for(tuning.pulse_cooldown_s)
	var ids: Array[String] = []
	var center := player_pos + Vector3.UP * 0.8
	var radius_sq := float(tuning.pulse_radius) ** 2
	for shade in shades:
		if center.distance_squared_to(shade.pos) > radius_sq + Map.EPS:
			continue
		shade.state = "stunned"
		shade.until = sim_tick + _ticks_for(tuning.pulse_stun_s)
		shade.push = Map.away(shade.pos, player_pos) * (float(tuning.pulse_push_m) / 15.0)
		shade.push_left = 15
		ids.append(shade.id)
		score += int(tuning.score.per_stun)
	for drifter in drifters:
		if center.distance_squared_to(drifter.pos) > radius_sq + Map.EPS:
			continue
		if drifter.state == "chase":
			_set_flee(drifter, 240)
		elif drifter.state == "flee" and int(drifter.stolen) > 0:
			var amount := int(drifter.stolen)
			for index in range(amount):
				_drop_mote(drifter.pos)
			drifter.stolen = 0
			_set_flee(drifter, 120)
			_emit(events, "drifter_drop", {"drifter_id": drifter.id, "amount": amount})
	_emit(events, "pulse", {"stunned_ids": ids})


func _move_shades(player_present: bool) -> void:
	var speed := float(tuning.shade_speed_night3 if number == 3 else tuning.shade_speed)
	for shade in shades:
		if shade.state in ["spawning", "recoil", "stunned"] and sim_tick >= int(shade.until):
			shade.state = "wander"
		var position: Vector3 = shade.pos
		if int(shade.evict_at) > 0:
			shade.push_left = 0
			shade.pos = position.lerp(shade.evict_target, 1.0 / maxf(1.0, float(int(shade.evict_at) - sim_tick + 1)))
			if sim_tick >= int(shade.evict_at):
				shade.pos = _outside_light(shade.pos)
				shade.evict_at = 0
			continue
		match shade.state:
			"spawning":
				continue
			"stunned", "recoil":
				if int(shade.push_left) > 0:
					shade.push_left -= 1
					var target: Vector3 = position + shade.push
					if not _shade_step_allowed(position, target):
						shade.push_left = 0
						shade.pos = _shade_grounded_move(position, _shade_stop_at_edge(position, target))
					else:
						shade.pos = _shade_grounded_move(position, target)
				continue
		var distance := Map.planar_sq(position, player_pos)
		if shade.state == "chase" and (not player_present or distance > 324.0 + Map.EPS):
			shade.state = "wander"
		elif shade.state == "wander" and player_present and distance <= 144.0 + Map.EPS:
			shade.state = "chase"
		var goal: Vector3 = shade.wander_goal
		if shade.state == "chase":
			goal = player_pos
		elif Map.in_xz(position, goal, 0.8) or sim_tick >= int(shade.wander_at):
			goal = _wander_goal(position)
			shade.wander_goal = goal
			shade.wander_at = sim_tick + 180
		goal.y = position.y
		var target := position.move_toward(goal, speed * STEP)
		if _shade_step_allowed(position, target):
			shade.pos = _shade_grounded_move(position, target)
		else:
			shade.pos = _shade_slide(position, target, goal, speed)


func _wander_goal(position: Vector3) -> Vector3:
	if number == 2 and position.x >= 35.0:
		return Map.EAST + Vector3(_shade_rng.randf_range(-18, 18), 0, _shade_rng.randf_range(-18, 18))
	return Vector3(_shade_rng.randf_range(-18, 18), 0, _shade_rng.randf_range(-18, 18))


func _shade_grounded_move(from: Vector3, target: Vector3) -> Vector3:
	# Shades hover above the surface and keep the scenario's local center height.
	var old_surface := Map.floor_below(number, from, from.y)
	var next_surface := Map.floor_below(number, target, from.y)
	if number == 3 and old_surface != Map.VOID:
		var ramp := Map.ramp_height(target)
		if ramp != Map.VOID and ramp - old_surface <= 0.2:
			next_surface = maxf(next_surface, ramp)
	if next_surface != Map.VOID and old_surface != Map.VOID:
		target.y = next_surface + (from.y - old_surface)
	return target


func _shade_step_allowed(from: Vector3, target: Vector3) -> bool:
	if not _safe_lamp(target).is_empty():
		return false
	if Map.is_base(number, from) and not Map.is_base(number, target):
		return false
	return Map.allow_player_step(number, from, target, false)


func _shade_stop_at_edge(from: Vector3, target: Vector3) -> Vector3:
	var low := 0.0
	var high := 1.0
	for index in range(9):
		var middle := (low + high) * 0.5
		if _shade_step_allowed(from, from.lerp(target, middle)):
			low = middle
		else:
			high = middle
	return from.lerp(target, low)


func _shade_slide(from: Vector3, target: Vector3, goal: Vector3, speed: float) -> Vector3:
	var zone := _safe_lamp(target)
	if zone.is_empty():
		return from
	var normal := Map.away(from, zone.pos)
	var tangent := Vector3(-normal.z, 0, normal.x)
	if tangent.dot(goal - from) < 0.0:
		tangent = -tangent
	var alternate := from + tangent * speed * STEP
	return _shade_grounded_move(from, alternate) if _shade_step_allowed(from, alternate) else from


func _move_drifters(player_present: bool) -> void:
	for index in range(drifters.size() - 1, -1, -1):
		var drifter := drifters[index]
		if drifter.state == "removed" or (drifter.state == "flee" and sim_tick >= int(drifter.until)):
			drifters.remove_at(index)
			continue
		if drifter.state == "flee":
			drifter.pos += drifter.direction * 7.0 * STEP
			continue
		var can_chase := player_present and carried >= 5 and Map.in_xz(drifter.pos, player_pos, 15.0)
		drifter.state = "chase" if can_chase else "idle"
		var position: Vector3 = drifter.pos
		var goal := Vector3(player_pos.x, position.y, player_pos.z)
		if not can_chase:
			goal = drifter.home + Vector3(cos(sim_tick / 120.0), 0, sin(sim_tick / 120.0)) * 3.0
		drifter.pos = position.move_toward(goal, (7.0 if can_chase else 2.0) * STEP)


func _set_flee(drifter: Dictionary, duration: int) -> void:
	drifter.state = "flee"
	drifter.until = sim_tick + duration
	drifter.direction = Map.away(drifter.pos, player_pos)


func _drifter_contacts(events: Array[Dictionary]) -> void:
	for drifter in drifters:
		if drifter.state != "chase" or not Map.in_xz(drifter.pos, player_pos, 1.2):
			continue
		var amount := mini(3, carried)
		carried -= amount
		drifter.stolen = amount
		_set_flee(drifter, 240)
		_emit(events, "drifter_steal", {"drifter_id": drifter.id, "amount": amount, "carried": carried})


func _shade_contacts(events: Array[Dictionary]) -> void:
	if player_is_protected() or not _safe_lamp(player_pos).is_empty():
		return
	for shade in shades:
		if shade.state not in ["wander", "chase"] or int(shade.evict_at) > 0:
			continue
		if not _touches(shade.pos, float(tuning.shade_hit_radius)):
			continue
		flames -= 1
		var dropped := floori(carried * float(tuning.hit_drop_ratio))
		carried -= dropped
		for index in range(dropped):
			var angle := _mote_rng.randf_range(0.0, TAU)
			var point := player_pos + Vector3(cos(angle), 0, sin(angle)) * _mote_rng.randf_range(1.5, 2.5)
			_drop_mote(point)
		_invulnerable_until = sim_tick + _ticks_for(tuning.invuln_s)
		shade.state = "recoil"
		shade.until = sim_tick + 61
		shade.push_left = 60
		shade.push = Map.away(shade.pos, player_pos) * (2.0 / 60.0)
		_emit(events, "player_hit", {"by": "shade", "flames": flames, "dropped": dropped})
		return


func _safe_lamp(position: Vector3) -> Dictionary:
	for lamp in lanterns:
		if lamp.lit and Map.in_xz(position, lamp.pos, float(tuning.safe_radius)):
			return lamp
	return {}


func _outside_light(position: Vector3) -> Vector3:
	if _safe_lamp(position).is_empty():
		return position
	var result := position
	var shortest := INF
	var radius := float(tuning.safe_radius) + 0.001
	# Test rays through the union so overlapping lamp circles cannot trap a shade.
	for index in range(16):
		var angle := TAU * index / 16.0
		var direction := Vector3(cos(angle), 0, sin(angle))
		var distance := 0.0
		for pass_index in range(lanterns.size()):
			var before := distance
			for lamp in lanterns:
				if not lamp.lit:
					continue
				var offset: Vector3 = position - lamp.pos
				offset.y = 0.0
				var projection := offset.dot(direction)
				var discriminant := radius ** 2 - offset.length_squared() + projection ** 2
				if discriminant < 0:
					continue
				var root := sqrt(discriminant)
				if -projection - root <= distance and -projection + root >= distance:
					distance = -projection + root + 0.002
			if before == distance:
				break
		if distance < shortest:
			shortest = distance
			result = position + direction * distance
	return result


func _scheduled_spawns(events: Array[Dictionary]) -> void:
	if _random_motes and sim_tick % 240 == 0 and motes.size() < 30:
		_spawn_mote()
	if _random_shades and sim_tick >= 300 and (sim_tick - 300) % int(SPAWN_PERIODS[number - 1]) == 0:
		for index in range(2 if sim_tick == 300 else 1):
			if shades.size() >= int(SHADE_CAPS[number - 1]):
				break
			var valid: Array[Vector3] = []
			for point in _shade_points:
				if Map.planar_sq(point, player_pos) >= 225.0 - Map.EPS and _shade_point_free(point):
					valid.append(point)
			if not valid.is_empty():
				var point := valid[_shade_rng.randi_range(0, valid.size() - 1)] + Vector3.UP * 0.65
				_emit(events, "shade_spawned", {"id": _add_shade(point, "", "spawning", 30)})
	if _random_drifters and sim_tick % 1200 == 0 and drifters.size() < 2:
		var point := _shade_points[_drifter_rng.randi_range(0, _shade_points.size() - 1)] + Vector3.UP * 1.3
		_add_drifter(point)


func _shade_point_free(point: Vector3) -> bool:
	if not _safe_lamp(point).is_empty():
		return false
	for shade in shades:
		if Map.in_xz(shade.pos, point, 1.0):
			return false
	return true


func _spawn_mote() -> void:
	var free: Array[int] = []
	for index in range(_mote_points.size()):
		if not _occupied.has(index):
			free.append(index)
	if not free.is_empty():
		var point := free[_mote_rng.randi_range(0, free.size() - 1)]
		_add_mote(_mote_points[point], 0, point)


func _drop_mote(point: Vector3) -> void:
	var ground := Map.floor_below(number, point, point.y)
	if ground != Map.VOID:
		point.y = ground
	_add_mote(point, 480)


func _add_mote(position: Vector3, ttl: int, point: int = -1) -> void:
	if point >= 0:
		_occupied[point] = true
	motes.append({"id": _make_id("M"), "pos": position, "point": point, "kind": "dropped" if ttl > 0 else "random",
		"expires": sim_tick + ttl if ttl > 0 else 0, "pickable": sim_tick + 1})


func _point_index(position: Vector3) -> int:
	for index in range(_mote_points.size()):
		if _mote_points[index].distance_squared_to(position) < 0.01 ** 2:
			return index
	return -1


func _add_shade(position: Vector3, id: String, mode: String, duration: int) -> String:
	id = _make_id("S", id)
	var default_duration: int = {"spawning": 30, "stunned": 120, "recoil": 60}.get(mode, 0)
	shades.append({"id": id, "pos": position, "state": mode, "until": sim_tick + (duration if duration >= 0 else default_duration),
		"push": Vector3.ZERO, "push_left": 0, "wander_goal": Vector3.ZERO, "wander_at": 0,
		"evict_at": 0, "evict_target": Vector3.ZERO})
	shades.sort_custom(_id_before)
	return id


func _add_drifter(position: Vector3, id: String = "", mode: String = "idle", stolen: int = 0, duration: int = -1) -> void:
	id = _make_id("D", id)
	drifters.append({"id": id, "pos": position, "home": position, "state": mode, "stolen": stolen,
		"until": sim_tick + (duration if duration >= 0 else 240), "direction": Map.away(position, player_pos)})
	drifters.sort_custom(_id_before)


func _add_charm(position: Vector3, id: String = "", ready: int = 0) -> void:
	charms.append({"id": _make_id("C", id), "pos": position, "ready": ready})


func _setup_lanterns(overrides: Array) -> void:
	var positions: Array = Map.LANTERNS[number - 1]
	var cost := int(tuning.lantern_cost)
	for index in range(positions.size()):
		lanterns.append({"id": "L%d" % (index + 1), "pos": positions[index], "lit": false, "deposited": 0, "lit_at": -1})
	for change: Dictionary in overrides:
		var lamp := lanterns[int(String(change.id).substr(1)) - 1]
		if change.has("pos"):
			lamp.pos = _vector(change.pos)
		var amount := int(change.get("deposited", cost if change.get("lit", false) else 0))
		lamp.deposited = amount
		lamp.lit = change.get("lit", amount >= cost)


func _reserve_ids(entries: Array) -> void:
	for entry: Dictionary in entries:
		if entry.has("id"):
			_used_ids[entry.id] = true


func _make_id(prefix: String, requested: String = "") -> String:
	var id := requested
	if id.is_empty():
		while id.is_empty() or _used_ids.has(id):
			_serials[prefix] = int(_serials.get(prefix, 0)) + 1
			id = "%s%d" % [prefix, _serials[prefix]]
	_used_ids[id] = true
	return id


func _finish_if_needed(events: Array[Dictionary]) -> void:
	var reason := ""
	if flames <= 0:
		state = "lost"
		reason = "no_flames"
	elif lit_count() == lanterns.size():
		state = "won"
		reason = "all_lit"
		score += floori(time_left()) * int(tuning.score.per_second_left)
		score += flames * int(tuning.score.per_flame_left)
	elif time_left() == 0.0:
		state = "lost"
		reason = "dawn"
	if not reason.is_empty():
		_emit(events, "game_over", {"result": state, "reason": reason})


func _touches(target: Vector3, radius: float) -> bool:
	return absf(player_pos.y - target.y) <= HEIGHT_RANGE + Map.EPS and Map.in_xz(player_pos, target, radius)


func _seconds_until(until: int) -> float:
	return maxi(0, until - sim_tick) / float(TICKS_PER_SECOND)


func _emit(events: Array[Dictionary], name: String, data: Dictionary) -> void:
	events.append({"type": "event", "tick": tick, "name": name, "data": data})


static func _id_before(a: Dictionary, b: Dictionary) -> bool:
	return String(a.id).naturalnocasecmp_to(b.id) < 0


static func _ticks_for(seconds: float) -> int:
	return roundi(seconds * TICKS_PER_SECOND)


static func _vector(point: Array) -> Vector3:
	return Vector3(point[0], point[1], point[2])


static func _coordinates(point: Vector3) -> Array[float]:
	return [roundf(point.x * 1000.0) / 1000.0, roundf(point.y * 1000.0) / 1000.0,
		roundf(point.z * 1000.0) / 1000.0]

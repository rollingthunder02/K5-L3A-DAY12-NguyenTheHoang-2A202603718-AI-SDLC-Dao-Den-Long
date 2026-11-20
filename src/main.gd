extends Node3D

const Night := preload("res://src/night.gd")
const IslandArt := preload("res://src/island_art.gd")
const NightHUD := preload("res://src/hud.gd")
const KEYS := {
	"walk_left": [KEY_A, KEY_LEFT], "walk_right": [KEY_D, KEY_RIGHT],
	"walk_forward": [KEY_W, KEY_UP], "walk_back": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE], "interact": [KEY_E], "pulse": [KEY_Q], "restart": [KEY_R],
}
const SOUND_NOTES := {
	"mote_picked": [720.0, 980.0, 0.12], "lantern_lit": [392.0, 660.0, 0.46],
	"pulse": [320.0, 125.0, 0.34], "player_hit": [144.0, 70.0, 0.23],
}

var night: Night
var seed_value := randi()
var _art: IslandArt
var _hud: NightHUD
var _camera: Camera3D
var _player: Node3D
var _body: Node3D
var _pulse_ring: MeshInstance3D
var _audio: AudioStreamPlayer
var _sounds := {}
var _lantern_nodes := {}
var _mote_nodes := {}
var _shade_nodes := {}
var _yaw := 0.0
var _camera_height := 5.15
var _paused_for_mouse := false
var _last_player_pos := Vector3.ZERO
var _toast := ""
var _toast_until := 0
var _pulse_at := -100


func _ready() -> void:
	_setup_actions()
	_art = IslandArt.new()
	add_child(_art)
	_player = _art.make_player()
	add_child(_player)
	_body = _player.get_node("Body")
	_pulse_ring = _art.make_ring(1.0, 0.032, Color("ffc46f"), 0.78)
	_pulse_ring.hide()
	add_child(_pulse_ring)
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.far = 240.0
	add_child(_camera)
	_camera.make_current()
	var overlay := CanvasLayer.new()
	add_child(overlay)
	_hud = NightHUD.new()
	overlay.add_child(_hud)
	_hud.restart_requested.connect(start_night)
	_setup_audio()
	start_night()


func start_night() -> void:
	if _audio != null:
		_audio.stop()
	night = Night.new(seed_value)
	_paused_for_mouse = false
	_yaw = 0.0
	_camera_height = 5.15
	_toast = "Gom đom đóm để thắp lại 5 Đèn Lồng Lớn"
	_toast_until = 270
	_pulse_at = -100
	_pulse_ring.hide()
	_last_player_pos = night.player_pos
	_player.rotation.y = 0.0
	for collection in [_lantern_nodes, _mote_nodes, _shade_nodes]:
		for node: Node3D in collection.values():
			node.queue_free()
		collection.clear()
	for lantern in night.lanterns:
		var lamp := _art.make_lantern()
		lamp.position = lantern.pos
		add_child(lamp)
		_lantern_nodes[lantern.id] = lamp
	_sync_lanterns()
	_sync_world()
	_update_camera(1.0)
	_hud.hide_result()
	_hud.update_night(night, _yaw, _toast)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if night == null or night.state != "playing":
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_paused_for_mouse = not _paused_for_mouse
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _paused_for_mouse else Input.MOUSE_MODE_CAPTURED
		_hud.update_night(night, _yaw, "Tạm dừng  ·  Nhấp để tiếp tục" if _paused_for_mouse else "")
	elif _paused_for_mouse and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_paused_for_mouse = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif not _paused_for_mouse and event is InputEventMouseMotion and night.tick > 3:
		_yaw = fposmod(_yaw - event.relative.x * 0.0037, TAU)
		_camera_height = clampf(_camera_height + event.relative.y * 0.033, 3.6, 12.2)


func _physics_process(_delta: float) -> void:
	if night.state != "playing":
		if Input.is_action_just_pressed("restart"):
			start_night()
		return
	if _paused_for_mouse:
		return
	var walk := Input.get_vector("walk_right", "walk_left", "walk_back", "walk_forward", 0.0)
	var input := {"move": walk, "cam_yaw_deg": rad_to_deg(_yaw)}
	for action: String in Night.BUTTONS:
		input[action] = Input.is_action_pressed(action)
	var events := night.step(input)
	for event in events:
		_on_game_event(event)
	_sync_world()
	_hud.update_night(night, _yaw, _toast if night.tick < _toast_until else "")


func _process(delta: float) -> void:
	_update_camera(1.0 - exp(-delta * 12.0))


func _on_game_event(event: Dictionary) -> void:
	if _sounds.has(event.name):
		_audio.stream = _sounds[event.name]
		_audio.play()
	match event.name:
		"deposit":
			_sync_lanterns()
		"lantern_lit":
			_sync_lanterns()
			_show_toast("Đèn %s đã sáng  ·  Vùng an toàn" % event.data.lantern_id)
		"pulse":
			_pulse_ring.position = Vector3(night.player_pos.x, 0.06, night.player_pos.z)
			_pulse_at = night.tick
			_show_toast("Mây tỏa sáng  ·  −%d đom đóm" % int(night.tuning.pulse_cost))
		"player_hit":
			var dropped: int = event.data.dropped
			_show_toast("Mất một ngọn lửa  ·  Rơi %d đom đóm" % dropped if dropped > 0 else "Mất một ngọn lửa")
		"game_over":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_hud.show_result(night, event.data.reason)


func _show_toast(message: String) -> void:
	_toast = message
	_toast_until = night.tick + 100


func _sync_lanterns() -> void:
	for lamp in night.lanterns:
		var fraction := float(lamp.deposited) / float(night.tuning.lantern_cost)
		_art.update_lantern(_lantern_nodes[lamp.id], lamp.lit, fraction, float(night.tuning.safe_radius))
	_art.set_restored_light(float(night.lit_count()) / night.lanterns.size())


func _sync_world() -> void:
	var seconds := float(night.tick) / Night.TICKS_PER_SECOND
	_player.position = night.player_pos
	var velocity := night.player_pos - _last_player_pos
	velocity.y = 0.0
	if velocity.length_squared() > 0.00001:
		_player.rotation.y = lerp_angle(_player.rotation.y, atan2(velocity.x, velocity.z), 0.28)
	_body.position.y = sin(seconds * 16.0) * 0.033 if velocity.length_squared() > 0.00001 else 0.0
	_body.visible = not night.player_is_protected() or night.tick % 10 < 7 or night.state != "playing"
	_last_player_pos = night.player_pos
	var active_motes := {}
	for mote in night.motes:
		if not _mote_nodes.has(mote.id):
			var node := _art.make_mote()
			add_child(node)
			_mote_nodes[mote.id] = node
		var node: Node3D = _mote_nodes[mote.id]
		var phase := float(String(mote.id).substr(1).to_int()) * 0.78
		node.position = Vector3(mote.pos.x, mote.pos.y + 0.48 + sin(seconds * 3.6 + phase) * 0.17, mote.pos.z)
		node.scale = Vector3.ONE * (0.96 + sin(seconds * 5.1 + phase) * 0.15)
		active_motes[mote.id] = true
	for id: String in _mote_nodes.keys():
		if not active_motes.has(id):
			_mote_nodes[id].queue_free()
			_mote_nodes.erase(id)
	for shade in night.shades:
		if not _shade_nodes.has(shade.id):
			var node := _art.make_shade()
			add_child(node)
			_shade_nodes[shade.id] = node
		var node: Node3D = _shade_nodes[shade.id]
		node.position = shade.pos + Vector3.UP * sin(seconds * 4.0) * 0.09
		var target := night.player_pos - node.position
		if Vector2(target.x, target.z).length_squared() > 0.001:
			node.rotation.y = atan2(target.x, target.z)
		_art.update_shade(node, shade.state == "stunned")
	var pulse_progress := float(night.tick - _pulse_at) / 24.0
	_pulse_ring.visible = pulse_progress < 1.0
	if _pulse_ring.visible:
		var radius := lerpf(0.20, float(night.tuning.pulse_radius), pulse_progress)
		_pulse_ring.scale = Vector3(radius, 1, radius)


func _update_camera(weight: float) -> void:
	var forward := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, _yaw)
	var at := Vector3(night.player_pos.x, night.player_pos.y * 0.56, night.player_pos.z)
	var destination := at - forward * 9.6 + Vector3.UP * _camera_height
	_camera.position = _camera.position.lerp(destination, weight)
	_camera.look_at(at + forward * 3.2 + Vector3.UP * 1.65, Vector3.UP)


func _setup_actions() -> void:
	for action: String in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in KEYS[action]:
			var binding := InputEventKey.new()
			binding.physical_keycode = key
			InputMap.action_add_event(action, binding)


func _setup_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -11.0
	add_child(_audio)
	for event: String in SOUND_NOTES:
		var notes: Array = SOUND_NOTES[event]
		var sample := AudioStreamWAV.new()
		sample.mix_rate = 22050
		sample.format = AudioStreamWAV.FORMAT_16_BITS
		var size := roundi(notes[2] * sample.mix_rate)
		var bytes := PackedByteArray()
		bytes.resize(size * 2)
		var phase := 0.0
		for index in range(size):
			var fraction := float(index) / size
			phase += TAU * lerpf(notes[0], notes[1], fraction) / sample.mix_rate
			var envelope := minf(1.0, fraction * 26.0) * (1.0 - fraction) ** 2
			var value := (sin(phase) + 0.24 * sin(phase * 2.0)) * envelope * 16000.0
			bytes.encode_s16(index * 2, roundi(value))
		sample.data = bytes
		_sounds[event] = sample

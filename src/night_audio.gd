extends Node

const RATE := 22050
const EFFECTS := {
	"mote_picked": [720.0, 980.0, 0.14], "lantern_lit": [392.0, 660.0, 0.56],
	"pulse": [320.0, 125.0, 0.37], "player_hit": [144.0, 70.0, 0.23],
	"jump": [285.0, 440.0, 0.18], "dash": [545.0, 142.0, 0.26],
	"won": [262.0, 784.0, 0.76], "lost": [245.0, 98.0, 0.72],
	"shade_spawned": [125.0, 212.0, 0.34], "countdown": [810.0, 810.0, 0.085],
	"wind": [95.0, 215.0, 0.70], "charm_picked": [590.0, 1100.0, 0.32],
}

var _sfx: AudioStreamPlayer
var _music: AudioStreamPlayer
var _samples := {}


func _ready() -> void:
	if DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy":
		return
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -10.0
	add_child(_sfx)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -18.0
	_music.stream = _make_music()
	add_child(_music)
	for name: String in EFFECTS:
		_samples[name] = _make_effect(EFFECTS[name])


func _exit_tree() -> void:
	for player in [_sfx, _music]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


func play_effect(effect: String) -> void:
	if _samples.has(effect):
		_sfx.stream = _samples[effect]
		_sfx.play()


func play_music() -> void:
	if _music != null:
		_music.stream_paused = false
		if not _music.playing:
			_music.play()


func pause_music(value: bool) -> void:
	if _music != null:
		_music.stream_paused = value


func set_volume(value: float) -> void:
	if _music != null:
		AudioServer.set_bus_mute(0, value == 0.0)
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, value)))


func _make_effect(notes: Array) -> AudioStreamWAV:
	var count := roundi(notes[2] * RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	for index in range(count):
		var fraction := float(index) / count
		phase += TAU * lerpf(notes[0], notes[1], fraction) / RATE
		var envelope := minf(1.0, fraction * 26.0) * (1.0 - fraction) ** 2
		bytes.encode_s16(index * 2, roundi((sin(phase) + 0.24 * sin(phase * 2.0)) * envelope * 16000.0))
	return _wav(bytes)


func _make_music() -> AudioStreamWAV:
	var melody := [261.63, 329.63, 392.0, 440.0, 392.0, 329.63, 293.66, 196.0,
		220.0, 261.63, 329.63, 392.0, 293.66, 261.63, 220.0, 196.0]
	var beat := roundi(RATE * 0.72)
	var bytes := PackedByteArray()
	bytes.resize(beat * melody.size() * 2)
	for index in range(melody.size()):
		for frame in range(beat):
			var t := float(frame) / RATE
			var envelope := sin(PI * frame / beat) * exp(-t * 2.2)
			var phase := TAU * float(melody[index]) * t
			var value := (sin(phase) * 0.65 + sin(phase * 2.0) * 0.13 + sin(phase * 0.5) * 0.32) * envelope
			bytes.encode_s16((index * beat + frame) * 2, roundi(value * 15200.0))
	var sample := _wav(bytes)
	sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sample.loop_end = beat * melody.size()
	return sample


func _wav(bytes: PackedByteArray) -> AudioStreamWAV:
	var sample := AudioStreamWAV.new()
	sample.mix_rate = RATE
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.data = bytes
	return sample

extends Node
## Original local sound design. Streams read canonical PCM WAV bytes directly,
## so a fresh project runs without waiting for Godot's audio importer.
## Items use 0 = radio, 1 = clock, 2 = lantern.

const AUDIO_PATH := "res://assets/audio/"
const ACTION_KINDS := ["screw", "brush", "solder", "test", "success", "error"]
const ITEM_NAMES := ["radio", "clock", "lantern"]
const ITEM_VOLUMES := [-20.0, -13.0, -26.0]

var _muted := false
var _ambience: AudioStreamPlayer
var _item_player: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _actions: Dictionary = {}
var _items: Array[AudioStreamWAV] = []
var _next_voice := 0
var _playing_kind := -1


func _ready() -> void:
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "RainAmbience"
	_ambience.volume_db = -21.0
	_ambience.stream = _read_wave("rain", true)
	add_child(_ambience)
	_ambience.play()
	_ambience.stream_paused = _muted

	_item_player = AudioStreamPlayer.new()
	_item_player.name = "RepairedItem"
	add_child(_item_player)
	for item_name in ITEM_NAMES:
		_items.append(_read_wave(item_name, true))
	for kind in ACTION_KINDS:
		_actions[kind] = _read_wave(kind)
	for index in range(6):
		var voice := AudioStreamPlayer.new()
		voice.name = "ToolSound%d" % index
		voice.volume_db = -9.0
		add_child(voice)
		_voices.append(voice)


func set_muted(value: bool) -> void:
	_muted = value
	if is_instance_valid(_ambience):
		_ambience.stream_paused = value
	if is_instance_valid(_item_player):
		_item_player.stream_paused = value
	if value:
		for voice in _voices:
			voice.stop()


func play_action(kind: String) -> void:
	if _muted or _voices.is_empty() or not _actions.has(kind):
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stop()
	voice.stream = _actions[kind]
	voice.pitch_scale = 1.0
	voice.volume_db = -9.0
	if kind == "screw" or kind == "brush" or kind == "solder":
		voice.pitch_scale = randf_range(0.93, 1.07)
	elif kind == "success":
		voice.volume_db = -10.0
	voice.play()


func set_item_playing(kind: int, enabled: bool) -> void:
	if not is_instance_valid(_item_player):
		return
	if not enabled:
		_item_player.stop()
		_playing_kind = -1
		return
	if kind < 0 or kind >= _items.size():
		return
	if kind == _playing_kind and _item_player.playing:
		return
	_item_player.stop()
	_playing_kind = kind
	_item_player.stream = _items[kind]
	_item_player.volume_db = ITEM_VOLUMES[kind]
	_item_player.play()
	_item_player.stream_paused = _muted


func _read_wave(sound_name: String, looping: bool = false) -> AudioStreamWAV:
	var path := AUDIO_PATH + sound_name + ".wav"
	var stream: AudioStreamWAV
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.size() >= 44:
			stream = AudioStreamWAV.new()
			stream.format = AudioStreamWAV.FORMAT_16_BITS
			stream.stereo = bytes.decode_u16(22) == 2
			stream.mix_rate = bytes.decode_u32(24)
			stream.data = bytes.slice(44)
	elif ResourceLoader.exists(path):
		# Exported PCKs may contain the imported resource instead of source PCM.
		var imported := load(path) as AudioStreamWAV
		if imported != null:
			stream = imported.duplicate() as AudioStreamWAV
	if stream == null:
		push_warning("Sound file is unavailable: " + sound_name)
		return null
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.data.size() / (4 if stream.stereo else 2))
	return stream

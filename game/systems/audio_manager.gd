class_name OEAudioManager
extends Node

var tracks: Dictionary = {}
var voices: Dictionary = {}
var muted: bool = false

func _ready() -> void:
	tracks = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio.json"))

func play_midi(bytes: PackedByteArray, loops: int) -> void:
	var key: String = bytes.hex_encode().sha256_text()
	if not tracks.has(key): return
	stop_midi(bytes)
	var player := AudioStreamPlayer.new()
	player.stream = load("res://assets/audio/"+str(tracks[key])+".wav")
	player.volume_db = -80.0 if muted else -8.0
	add_child(player)
	voices[key] = {"player":player,"loops":loops}
	player.finished.connect(func():
		if not voices.has(key): return
		var voice: Dictionary = voices[key]
		if int(voice.loops)<0 or int(voice.loops)>1:
			if int(voice.loops)>1: voice.loops-=1
			player.play()
		else:
			voices.erase(key)
			player.queue_free()
	)
	player.play()

func stop_midi(bytes: PackedByteArray) -> void:
	var key: String = bytes.hex_encode().sha256_text()
	if voices.has(key):
		voices[key].player.stop()
		voices[key].player.queue_free()
		voices.erase(key)

func stop_music() -> void:
	for voice: Dictionary in voices.values(): voice.player.stop(); voice.player.queue_free()
	voices.clear()

func set_muted(value: bool) -> void:
	muted = value
	for voice: Dictionary in voices.values(): voice.player.volume_db = -80.0 if muted else -8.0

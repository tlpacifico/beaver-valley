extends Node
## Plays short local sound effects on a channel separate from provisional voice.

const EFFECTS: Dictionary = {
	"collect": preload("res://audio/effects/collect.wav"),
	"gnaw": preload("res://audio/effects/gnaw.wav"),
	"place": preload("res://audio/effects/place.wav"),
	"complete": preload("res://audio/effects/complete.wav"),
}

var player := AudioStreamPlayer.new()
var active_event: String = ""


func _ready() -> void:
	player.name = "SoundEffectPlayer"
	player.volume_db = -10.0
	add_child(player)
	player.finished.connect(_on_finished)


func _on_finished() -> void:
	active_event = ""


func play_event(event_id: String) -> void:
	if not EFFECTS.has(event_id):
		return
	player.stop()
	active_event = event_id
	player.stream = EFFECTS[event_id]
	if DisplayServer.get_name() != "headless":
		player.play()

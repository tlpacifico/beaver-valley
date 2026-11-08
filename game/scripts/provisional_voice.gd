extends Node
## Plays replaceable local voice clips and serializes events through one player.

const LINES: Dictionary = {
	"dam_start": preload("res://audio/voice/dam_start.wav"),
	"help_collect": preload("res://audio/voice/help_collect.wav"),
	"help_place": preload("res://audio/voice/help_place.wav"),
	"first_placement": preload("res://audio/voice/first_placement.wav"),
	"dam_completed": preload("res://audio/voice/dam_completed.wav"),
}

var player := AudioStreamPlayer.new()
var active_event: String = ""


func _ready() -> void:
	player.name = "VoicePlayer"
	add_child(player)
	player.finished.connect(_on_finished)


func _on_finished() -> void:
	active_event = ""


func play_event(event_id: String) -> void:
	if not LINES.has(event_id) or active_event == event_id:
		return
	player.stop()
	active_event = event_id
	player.stream = LINES[event_id]
	if DisplayServer.get_name() != "headless":
		player.play()


func cancel() -> void:
	player.stop()
	active_event = ""

extends Node
## Plays replaceable local voice clips and serializes events through one player.
## The player never advances gameplay: it only reports a finished event, and the
## world decides whether that event is still valid for the current stage.

signal event_finished(event_id: String)

const LINES: Dictionary = {
	"dam_start": preload("res://audio/voice/dam_start.wav"),
	"help_collect": preload("res://audio/voice/help_collect.wav"),
	"help_place": preload("res://audio/voice/help_place.wav"),
	"first_placement": preload("res://audio/voice/first_placement.wav"),
	"dam_completed": preload("res://audio/voice/dam_completed.wav"),
	"thick_branch": preload("res://audio/voice/thick_branch.wav"),
	"rotten_branch": preload("res://audio/voice/rotten_branch.wav"),
	"help_compatible": preload("res://audio/voice/help_compatible.wav"),
	"home_invite": preload("res://audio/voice/home_invite.wav"),
	"help_home_collect": preload("res://audio/voice/help_home_collect.wav"),
	"help_home_place": preload("res://audio/voice/help_home_place.wav"),
	"food_invite": preload("res://audio/voice/food_invite.wav"),
	"help_food_collect": preload("res://audio/voice/help_food_collect.wav"),
	"help_food_place": preload("res://audio/voice/help_food_place.wav"),
	"food_unsuitable": preload("res://audio/voice/food_unsuitable.wav"),
	"food_complete": preload("res://audio/voice/food_complete.wav"),
	"winter_arrived": preload("res://audio/voice/winter_arrived.wav"),
}

var player := AudioStreamPlayer.new()
var active_event: String = ""


func _ready() -> void:
	player.name = "VoicePlayer"
	add_child(player)
	player.finished.connect(_on_finished)


func _on_finished() -> void:
	# `active_event` is the pending event token: cancel() clears it, so a late
	# callback after cancellation is ignored instead of replaying old guidance.
	var completed_event := active_event
	if completed_event.is_empty():
		return
	active_event = ""
	event_finished.emit(completed_event)


func play_event(event_id: String) -> void:
	if not LINES.has(event_id) or active_event == event_id:
		return
	player.stop()
	active_event = event_id
	player.stream = LINES[event_id]
	if DisplayServer.get_name() != "headless":
		player.play()


## Stops the current line and invalidates its pending completion.
func cancel() -> void:
	player.stop()
	active_event = ""

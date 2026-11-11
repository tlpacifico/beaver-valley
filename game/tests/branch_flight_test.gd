extends SceneTree
## Focused check that a thrown branch reaches the dam with the placement
## orientation, not the beaver's inherited facing.

const BranchScene = preload("res://scenes/collectible_branch.tscn")
const VISUAL_SIGNAL := "placement_visual_finished"
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _record_signal(slot_index: int, events: Array) -> void:
	events.append(slot_index)


func _run() -> void:
	var parent := Node3D.new()
	root.add_child(parent)

	var branch: CollectibleBranch = BranchScene.instantiate()
	parent.add_child(branch)
	await process_frame
	branch.configure_branch(CollectibleBranch.Kind.NORMAL, "branch_normal_01")
	branch.position = Vector3(3.0, 0.6, 0.0)
	branch.rotation = Vector3(0.2, 0.7, 0.35)
	var target := Vector3(0.5, 0.3, -0.4)
	var start_basis := branch.global_transform.basis
	var visual_events: Array = []
	_expect(branch.has_signal(VISUAL_SIGNAL), "The branch has no placement_visual_finished signal.")
	if branch.has_signal(VISUAL_SIGNAL):
		branch.connect(VISUAL_SIGNAL, _record_signal.bind(visual_events))
	branch.place(parent, target, 1, true)
	_expect(branch.state == CollectibleBranch.State.PLACED, "A thrown branch did not enter the placed state.")
	_expect(branch.placed_slot == 1, "A thrown branch did not record its slot index.")
	await create_timer(0.6).timeout
	var expected_position := target + Vector3(0.0, 0.18, 0.0)
	_expect(branch.position.distance_to(expected_position) <= 0.01, "A thrown branch did not finish at its slot position.")
	_expect(absf(branch.rotation.z - deg_to_rad(-15.0)) <= 0.01, "A thrown branch kept the beaver's roll instead of the placement orientation.")
	_expect(absf(branch.rotation.x) <= 0.01 and absf(branch.rotation.y) <= 0.01, "A thrown branch kept an inherited pitch or yaw.")
	_expect(not branch.global_transform.basis.is_equal_approx(start_basis), "A thrown branch ended with the inherited start orientation.")
	_expect(visual_events == [1], "The animated placement did not report its visual completion once with slot 1: %s." % str(visual_events))
	await create_timer(0.2).timeout
	_expect(visual_events == [1], "The animated placement reported its visual completion more than once.")

	var instant: CollectibleBranch = BranchScene.instantiate()
	parent.add_child(instant)
	await process_frame
	instant.configure_branch(CollectibleBranch.Kind.NORMAL, "branch_normal_02")
	var instant_events: Array = []
	if instant.has_signal(VISUAL_SIGNAL):
		instant.connect(VISUAL_SIGNAL, _record_signal.bind(instant_events))
	instant.place(parent, target, 0, false)
	_expect(instant.position.distance_to(target + Vector3(-0.48, 0.18, 0.0)) <= 0.01, "Instant placement did not use the slot position.")
	_expect(absf(instant.rotation.z - deg_to_rad(-15.0)) <= 0.01, "Instant placement did not use the placement orientation.")
	_expect(instant.placed_slot == 0, "Instant placement did not record its slot index.")
	await process_frame
	_expect(instant_events.is_empty(), "Instant placement or restore emitted a visual-completion signal.")
	instant.return_to_origin(parent)
	_expect(instant.state == CollectibleBranch.State.FREE and instant.placed_slot == -1, "Returning a branch did not clear its slot index.")

	var freed: CollectibleBranch = BranchScene.instantiate()
	parent.add_child(freed)
	await process_frame
	freed.configure_branch(CollectibleBranch.Kind.NORMAL, "branch_normal_03")
	var freed_events: Array = []
	if freed.has_signal(VISUAL_SIGNAL):
		freed.connect(VISUAL_SIGNAL, _record_signal.bind(freed_events))
	freed.place(parent, target, 2, true)
	await process_frame
	freed.queue_free()
	await process_frame
	await create_timer(0.6).timeout
	_expect(freed_events.is_empty(), "A branch freed mid-flight still reported visual completion.")

	if failures == 0:
		print("CASTOR_BRANCH_FLIGHT_OK orientation slot_index instant_return visual_signal_once free_guard")
	quit(0 if failures == 0 else 1)

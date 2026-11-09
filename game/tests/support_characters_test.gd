extends SceneTree
## Focused integration check for support-character visibility, timing and physics isolation.

const SupportCharacters = preload("res://scripts/support_characters.gd")
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _contains_collision_node(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D:
		return true
	for child in node.get_children():
		if _contains_collision_node(child):
			return true
	return false


func _run() -> void:
	var support := SupportCharacters.new()
	support.hint_duration = 0.16
	support.celebration_duration = 0.2
	root.add_child(support)
	await process_frame

	_expect(not support._owl.visible, "Owl should start hidden.")
	support.show_hint()
	_expect(support._owl.visible, "show_hint() did not show the owl.")
	await create_timer(0.09).timeout
	support.show_hint()
	await create_timer(0.09).timeout
	_expect(support._owl.visible, "Repeated show_hint() did not renew the visibility interval.")
	await create_timer(0.1).timeout
	_expect(not support._owl.visible, "Owl did not hide after the renewed hint interval.")

	support.set_hint(true)
	_expect(support._owl.visible, "set_hint(true) did not show the owl.")
	support.set_hint(false)
	_expect(not support._owl.visible, "set_hint(false) did not hide the owl.")

	support.celebrate()
	_expect(support._otter.visible, "celebrate() did not show the otter.")
	_expect(not _contains_collision_node(support), "Support characters contain collision nodes.")
	await create_timer(0.25).timeout
	_expect(not support._otter.visible, "Otter did not hide after the celebration.")

	if failures == 0:
		print("SUPPORT_CHARACTERS_OK timed_hint_renewal_celebration_no_collisions")
	quit(1 if failures > 0 else 0)

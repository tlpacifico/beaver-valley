extends SceneTree
## Focused checks for progressive dam scenery and finish selection.

const EnvironmentScript = preload("res://scripts/visual_environment.gd")
const TerrainScript = preload("res://scripts/valley_terrain.gd")
const LayoutScript = preload("res://scripts/valley_layout.gd")
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _run() -> void:
	var terrain = TerrainScript.new()
	terrain.configure(&"wide_bank")
	var layout = LayoutScript.new()
	layout.configure(terrain)
	var environment := EnvironmentScript.new() as VisualEnvironment
	environment.configure(terrain, layout)
	root.add_child(environment)
	await process_frame

	for count in range(4):
		environment.set_dam_state(count, "")
		_expect(environment.get_visible_dam_log_count() == count, "Dam scenery should show %d structural logs." % count)
		for index in range(3):
			var log := environment.get_node("DamProgressLog%d" % index) as MeshInstance3D
			_expect(log.visible == (index < count), "Dam log %d visibility should match state %d." % [index, count])

	environment.set_dam_state(3, "finish_golden")
	var final_log := environment.get_node("DamProgressLog2") as MeshInstance3D
	var finish_material := (final_log.mesh as CylinderMesh).material as StandardMaterial3D
	_expect(finish_material.albedo_color.is_equal_approx(Color("d6a83e")), "Golden finish should color the final structural log.")
	environment.set_dam_state(3, "finish_moss")
	finish_material = (final_log.mesh as CylinderMesh).material as StandardMaterial3D
	_expect(finish_material.albedo_color.is_equal_approx(Color("668b59")), "Moss finish should color the final structural log.")
	environment.set_dam_state(3, "unknown")
	finish_material = (final_log.mesh as CylinderMesh).material as StandardMaterial3D
	_expect(finish_material.albedo_color.is_equal_approx(Color("93663f")), "Unknown finish should retain natural timber color.")
	_expect(environment.find_children("*", "CollisionObject3D", true, false).is_empty(), "Visual environment must not introduce collision bodies.")
	_expect(environment.get_node_or_null("GoldenTree") != null, "Grounded scenery trees are missing.")
	for child in environment.get_children():
		if child.name != "GoldenTree":
			continue
		var tree_node := child as Node3D
		var expected: float = terrain.height_at(Vector2(tree_node.position.x, tree_node.position.z))
		_expect(absf(tree_node.position.y - expected) <= 0.05, "A scenery tree is not grounded (%.3f vs %.3f)." % [tree_node.position.y, expected])

	if failures == 0:
		print("CASTOR_VISUAL_ENVIRONMENT_OK")
	quit(0 if failures == 0 else 1)

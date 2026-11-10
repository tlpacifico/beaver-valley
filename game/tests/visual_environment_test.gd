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
	_expect(finish_material.albedo_color.is_equal_approx(Color("85603a")), "The finish choice should not repaint the full final log.")
	var first_log := environment.get_node("DamProgressLog0") as MeshInstance3D
	_expect((first_log.mesh as CylinderMesh).material.albedo_color.is_equal_approx(Color("93663f")), "A structural log lost its timber colour.")
	for index in range(3):
		var log := environment.get_node("DamProgressLog%d" % index) as MeshInstance3D
		_expect(log.position.y > terrain.full_water_level(), "Dam log %d is submerged below the full lake." % index)
	var brush := environment.get_node_or_null("DamBrush")
	_expect(brush != null and brush.visible, "The completed dam has no visible brush and stakes.")
	var mud_bank: MeshInstance3D = null
	if brush != null:
		mud_bank = brush.get_node_or_null("DamMudBank") as MeshInstance3D
	_expect(mud_bank != null, "The completed dam has no mud bank.")
	var spillway := environment.get_node_or_null("DamSpillway")
	_expect(spillway != null and not spillway.visible, "The spillway is visible before the lake rises.")
	environment.set_water_level(terrain.full_water_level())
	_expect(spillway != null and spillway.visible, "The spillway is not visible at the full lake level.")
	environment.set_dam_state(0, "")
	_expect(brush != null and not brush.visible, "The dam brush is visible before the first placement.")
	environment.set_dam_state(3, "finish_moss")
	finish_material = (final_log.mesh as CylinderMesh).material as StandardMaterial3D
	_expect(finish_material.albedo_color.is_equal_approx(Color("85603a")), "The moss finish should not repaint the full final log.")
	environment.set_dam_state(3, "unknown")
	finish_material = (final_log.mesh as CylinderMesh).material as StandardMaterial3D
	_expect(finish_material.albedo_color.is_equal_approx(Color("85603a")), "Unknown finish should retain the timber colour.")
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

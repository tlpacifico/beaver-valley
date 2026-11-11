extends SceneTree
## Focused checks for the N1 natural ground and scenery pass: bank stones,
## mud patches, clustered vegetation and outer rock formations on the authored
## wide-bank terrain. The scenery must stay visual, grounded, dry, outside the
## playable rectangle and deterministic, and it must reuse shared mesh and
## material resources, while the existing dam scenery keeps working.

const EnvironmentScript = preload("res://scripts/visual_environment.gd")
const TerrainScript = preload("res://scripts/valley_terrain.gd")
const LayoutScript = preload("res://scripts/valley_layout.gd")

const GROUND_TOLERANCE: float = 0.06
const SCALE_TOLERANCE: float = 0.01
const BAND_EPSILON: float = 0.001
const CLUSTER_CLEARANCE: float = 1.3
const DETAIL_CLEARANCE: float = 0.5
const CLUSTER_SPACING: float = 3.0
const MIN_STONES: int = 16
const MIN_MUD_PATCHES: int = 6
const MIN_CLUSTERS: int = 3
const MIN_FORMATIONS: int = 4
const MAX_MESH_INSTANCES: int = 90
const MIN_FORMATION_SLOPE: float = 8.0
const BOULDER_DRY_MARGIN: float = 0.03
const PLANT_RADIUS: float = 0.35
const MEMBER_RADIUS: float = 0.45
const REQUIRED_PLANTS: int = 3
const REQUIRED_MEMBERS: int = 6
const REQUIRED_BUSHES: int = 2
const REQUIRED_REEDS: int = 1
const GROUP_NAMES := [&"BankStones", &"MudPatches", &"VegetationClusters", &"OuterRocks"]
const TASK_POINTS := [
	Vector2(3.4, 3.9),
	Vector2(1.7, 1.9),
	Vector2(0.0, -0.2),
	Vector2(-0.7, -3.5),
	Vector2(2.5, -4.4),
	Vector2(3.2, 3.0),
	Vector2(0.8, 3.2),
	Vector2(2.6, 1.0),
	Vector2(0.2, 1.2),
	Vector2(4.5, 4.25),
]

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

	var natural := environment.get_node_or_null("NaturalScenery") as Node3D
	_expect(natural != null, "VisualEnvironment is missing the NaturalScenery child.")
	if natural == null:
		_finish()
		return
	_expect(natural.get_parent() == environment, "NaturalScenery is not a direct child of VisualEnvironment.")

	var golden_tree := environment.get_node_or_null("GoldenTree")
	if golden_tree != null:
		_expect(natural.get_index() > golden_tree.get_index(), "NaturalScenery is built before the existing vegetation instead of right after it.")
	var first_dam_log := environment.get_node_or_null("DamProgressLog0")
	if first_dam_log != null:
		_expect(natural.get_index() < first_dam_log.get_index(), "NaturalScenery is built after the dam structure instead of right after the vegetation.")

	var groups := {}
	var missing_group := false
	for group_name in GROUP_NAMES:
		var group := natural.get_node_or_null(String(group_name)) as Node3D
		_expect(group != null, "NaturalScenery is missing the direct group %s." % String(group_name))
		if group == null:
			missing_group = true
		else:
			_expect(group.get_parent() == natural, "Group %s is not a direct child of NaturalScenery." % String(group_name))
		groups[group_name] = group
	if missing_group:
		_finish()
		return

	var bank_stones: Node3D = groups[&"BankStones"]
	var mud_patches: Node3D = groups[&"MudPatches"]
	var vegetation_clusters: Node3D = groups[&"VegetationClusters"]
	var outer_rocks: Node3D = groups[&"OuterRocks"]
	var task_points := _task_points(layout)

	_check_stones(bank_stones, terrain, task_points)
	_check_mud_patches(mud_patches, terrain, task_points)
	_check_clusters(vegetation_clusters, terrain, task_points)
	_check_outer_rocks(outer_rocks, terrain, task_points)
	_check_mesh_reuse(bank_stones)
	_check_mesh_reuse(mud_patches)
	_check_mesh_reuse(outer_rocks)
	_check_shared_sphere_across_groups(bank_stones, outer_rocks)
	_check_no_collision(environment)
	_check_mesh_budget(natural)

	# A second instance in the same process must reproduce every authored
	# transform: placement may not use unseeded randomness or OS/time values.
	var second_environment := EnvironmentScript.new() as VisualEnvironment
	second_environment.configure(terrain, layout)
	root.add_child(second_environment)
	await process_frame
	var second_natural := second_environment.get_node_or_null("NaturalScenery") as Node3D
	_expect(second_natural != null, "The second VisualEnvironment is missing the NaturalScenery child.")
	if second_natural != null:
		_check_determinism(natural, second_natural)

	_check_existing_scenery(environment)

	_finish()


func _finish() -> void:
	if failures == 0:
		print("CASTOR_NATURAL_SCENERY_OK")
	quit(0 if failures == 0 else 1)


func _task_points(layout) -> Array:
	var points: Array = TASK_POINTS.duplicate()
	for id: StringName in LayoutScript.ANCHOR_IDS:
		var xz: Vector2 = layout.anchor_xz(id)
		if not points.has(xz):
			points.append(xz)
	return points


func _check_stones(group: Node3D, terrain, points: Array) -> void:
	var stones := _prefixed_meshes(group, "BankStone")
	_expect(stones.size() >= MIN_STONES, "%s has %d bank stones; at least %d are required." % [str(group.get_path()), stones.size(), MIN_STONES])
	_check_names_contiguous(group, stones, "BankStone")
	var full: float = terrain.full_water_level()
	for stone in stones:
		var label := str(stone.get_path())
		_check_grounded(stone, terrain, 0.05, "Bank stone")
		var xz := Vector2(stone.global_position.x, stone.global_position.z)
		var ground: float = terrain.height_at(xz)
		var offset: float = stone.global_position.y - ground
		_expect(offset >= 0.02 - BAND_EPSILON and offset <= 0.05 + BAND_EPSILON, "%s has a ground lift of %.3f m; bank stones need 0.02-0.05 m." % [label, offset])
		_expect(ground >= full + 0.05 - BAND_EPSILON, "%s sits at terrain height %.3f, below the dry stone band starting at %.3f." % [label, ground, full + 0.05])
		_expect(ground <= full + 0.75 + BAND_EPSILON, "%s sits at terrain height %.3f, above the stone band ending at %.3f." % [label, ground, full + 0.75])
		var sizes := {"x": stone.scale.x, "y": stone.scale.y, "z": stone.scale.z}
		for axis in sizes:
			var value: float = sizes[axis]
			_expect(value >= 0.10 - BAND_EPSILON and value <= 0.30 + BAND_EPSILON, "%s has a %s scale of %.3f; bank stones need 0.10-0.30 on every axis." % [label, axis, value])
		if stone.scale.x > 0.0:
			var ratio: float = stone.scale.y / stone.scale.x
			_expect(ratio >= 0.40 - BAND_EPSILON and ratio <= 0.65 + BAND_EPSILON, "%s has a y/x scale ratio of %.2f; bank stones need 0.40-0.65." % [label, ratio])
		_expect(stone.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s should have shadows disabled." % label)
		_check_clearance(stone, points, DETAIL_CLEARANCE, "Bank stone")


func _check_mud_patches(group: Node3D, terrain, points: Array) -> void:
	var patches := _prefixed_meshes(group, "MudPatch")
	_expect(patches.size() >= MIN_MUD_PATCHES, "%s has %d mud patches; at least %d are required." % [str(group.get_path()), patches.size(), MIN_MUD_PATCHES])
	_check_names_contiguous(group, patches, "MudPatch")
	var full: float = terrain.full_water_level()
	for patch in patches:
		var label := str(patch.get_path())
		_check_grounded(patch, terrain, 0.05, "Mud patch")
		var xz := Vector2(patch.global_position.x, patch.global_position.z)
		var ground: float = terrain.height_at(xz)
		var offset: float = patch.global_position.y - ground
		_expect(offset >= 0.005 - BAND_EPSILON and offset <= 0.02 + BAND_EPSILON, "%s has a ground lift of %.3f m; mud patches need 0.005-0.02 m." % [label, offset])
		_expect(ground >= full + 0.05 - BAND_EPSILON, "%s sits at terrain height %.3f, below the dry mud band starting at %.3f." % [label, ground, full + 0.05])
		_expect(ground <= full + 0.55 + BAND_EPSILON, "%s sits at terrain height %.3f, above the mud band ending at %.3f." % [label, ground, full + 0.55])
		_expect(patch.scale.y >= 0.03 - BAND_EPSILON and patch.scale.y <= 0.06 + BAND_EPSILON, "%s has a y scale of %.3f; mud patches need 0.03-0.06." % [label, patch.scale.y])
		for axis in ["x", "z"]:
			var value: float = patch.scale.x if axis == "x" else patch.scale.z
			_expect(value >= 0.35 - BAND_EPSILON and value <= 0.90 + BAND_EPSILON, "%s has a %s scale of %.3f; mud patches need 0.35-0.90." % [label, axis, value])
		var slope: float = terrain.slope_degrees(xz)
		_expect(slope <= 15.0 + BAND_EPSILON, "%s sits on a %.1f degree slope; mud patches need at most 15 degrees." % [label, slope])
		_expect(patch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s should have shadows disabled." % label)
		_check_clearance(patch, points, DETAIL_CLEARANCE, "Mud patch")


func _check_clusters(group: Node3D, terrain, points: Array) -> void:
	var clusters: Array = []
	for child in group.get_children():
		if child is Node3D and String(child.name).begins_with("Cluster"):
			clusters.append(child)
	_expect(clusters.size() >= MIN_CLUSTERS, "%s has %d vegetation clusters; at least %d are required." % [str(group.get_path()), clusters.size(), MIN_CLUSTERS])
	_check_names_contiguous(group, clusters, "Cluster")
	var centers: Array[Vector2] = []
	for cluster in clusters:
		var label := str(cluster.get_path())
		var members := _mesh_children(cluster)
		_expect(members.size() == REQUIRED_MEMBERS, "%s has %d MeshInstance3D members; clusters need exactly %d (two bushes and one reed)." % [label, members.size(), REQUIRED_MEMBERS])
		var plants := 0
		var bushes := 0
		var reeds := 0
		for member in members:
			var member_name := String(member.name)
			_expect(member.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s member %s should have shadows disabled." % [label, member_name])
			var offset := Vector2(member.global_position.x - cluster.global_position.x, member.global_position.z - cluster.global_position.z)
			_expect(offset.length() <= MEMBER_RADIUS + BAND_EPSILON, "%s member %s is %.2f m from the cluster centre; every part must stay within %.2f m." % [label, member_name, offset.length(), MEMBER_RADIUS])
			if member_name.begins_with("BushTrunk"):
				bushes += 1
			elif member_name.begins_with("ReedStalk"):
				reeds += 1
			else:
				continue
			plants += 1
			_expect(offset.length() <= PLANT_RADIUS + BAND_EPSILON, "%s plant %s root is %.2f m from the cluster centre; roots must stay within %.2f m." % [label, member_name, offset.length(), PLANT_RADIUS])
		_expect(plants == REQUIRED_PLANTS, "%s has %d plants (BushTrunk + ReedStalk); each cluster needs %d plants." % [label, plants, REQUIRED_PLANTS])
		_expect(bushes == REQUIRED_BUSHES, "%s has %d bush trunks; each cluster needs %d." % [label, bushes, REQUIRED_BUSHES])
		_expect(reeds == REQUIRED_REEDS, "%s has %d reed stalks; each cluster needs %d." % [label, reeds, REQUIRED_REEDS])
		_check_grounded(cluster, terrain, 0.03, "Vegetation cluster")
		_check_clearance(cluster, points, CLUSTER_CLEARANCE, "Vegetation cluster")
		centers.append(Vector2(cluster.global_position.x, cluster.global_position.z))
	for first in range(centers.size()):
		for second in range(first + 1, centers.size()):
			var gap := centers[first].distance_to(centers[second])
			_expect(gap >= CLUSTER_SPACING - BAND_EPSILON, "Vegetation clusters %d and %d are %.2f m apart; at least %.1f m are required." % [first, second, gap, CLUSTER_SPACING])


func _check_outer_rocks(group: Node3D, terrain, points: Array) -> void:
	var formations: Array = []
	for child in group.get_children():
		if child is Node3D and String(child.name).begins_with("OuterRock"):
			formations.append(child)
	_expect(formations.size() >= MIN_FORMATIONS, "%s has %d outer rock formations; at least %d are required." % [str(group.get_path()), formations.size(), MIN_FORMATIONS])
	_check_names_contiguous(group, formations, "OuterRock")
	var rect := ValleyTerrain.PLAYABLE_RECT
	var grown := rect.grow(0.2)
	var full: float = terrain.full_water_level()
	for formation in formations:
		var label := str(formation.get_path())
		var members := _mesh_children(formation)
		_expect(members.size() >= 2 and members.size() <= 4, "%s has %d boulder meshes; each formation needs 2-4." % [label, members.size()])
		var xz := Vector2(formation.global_position.x, formation.global_position.z)
		_expect(terrain.contains(xz), "%s sits outside the authored terrain oval." % label)
		var outside := xz.x < grown.position.x or xz.x > grown.end.x or xz.y < grown.position.y or xz.y > grown.end.y
		_expect(outside, "%s sits inside PLAYABLE_RECT grown by 0.2 m; outer rocks must frame the outer slopes." % label)
		var slope: float = terrain.slope_degrees(xz)
		_expect(slope >= MIN_FORMATION_SLOPE - BAND_EPSILON, "%s sits on a %.1f degree slope; outer rock formations need at least %.1f degrees on the enclosing slopes." % [label, slope, MIN_FORMATION_SLOPE])
		_check_grounded(formation, terrain, 0.03, "Outer rock formation")
		_check_clearance(formation, points, CLUSTER_CLEARANCE, "Outer rock formation")
		for boulder in members:
			_check_boulder_clearance(formation, boulder, terrain, rect, full)


## Every boulder must stay fully outside PLAYABLE_RECT: its horizontal circle
## may not intersect the rectangle. It must also stand on dry ground at the full
## lake level, so no boulder sits in the raised water.
func _check_boulder_clearance(formation: Node3D, boulder: MeshInstance3D, terrain, rect: Rect2, full: float) -> void:
	var centre := Vector2(formation.global_position.x + boulder.position.x, formation.global_position.z + boulder.position.z)
	var radius := 0.5 * maxf(boulder.scale.x, boulder.scale.z)
	var label := "%s boulder %s" % [str(formation.get_path()), str(boulder.name)]
	var clear_x := centre.x - radius >= rect.end.x or centre.x + radius <= rect.position.x
	var clear_z := centre.y - radius >= rect.end.y or centre.y + radius <= rect.position.y
	_expect(clear_x or clear_z, "%s reaches into PLAYABLE_RECT: centre %s, horizontal radius %.2f m; every boulder must stay fully outside the rectangle." % [label, str(centre), radius])
	var ground: float = terrain.height_at(centre)
	_expect(ground >= full + BOULDER_DRY_MARGIN - BAND_EPSILON, "%s stands at terrain height %.3f, below the dry boulder threshold %.3f." % [label, ground, full + BOULDER_DRY_MARGIN])
	# Each boulder is grounded on the terrain under its own footprint: its lower
	# surface rests just below the ground instead of floating over an uneven slope.
	var bottom := formation.global_position.y + boulder.position.y - boulder.scale.y * 0.5
	_expect(bottom <= ground + 0.02, "%s floats %.2f m above the ground under it (bottom %.3f, ground %.3f)." % [label, bottom - ground, bottom, ground])
	_expect(bottom >= ground - 0.35, "%s is buried %.2f m under the ground under it (bottom %.3f, ground %.3f)." % [label, ground - bottom, bottom, ground])


## The 46 stone, mud and boulder meshes must reuse one unit SphereMesh per
## (radial_segments, rings) pair, with the size applied through the instance
## scale, and one StandardMaterial3D per palette colour through material_override.
func _check_mesh_reuse(group: Node3D) -> void:
	var instances := group.find_children("*", "MeshInstance3D", true, false)
	_expect(not instances.is_empty(), "%s has no MeshInstance3D nodes to inspect for resource reuse." % str(group.get_path()))
	var distinct_meshes := {}
	var material_by_colour := {}
	for instance in instances:
		var label := str(instance.get_path())
		var sphere := instance.mesh as SphereMesh
		_expect(sphere != null, "%s does not use a SphereMesh." % label)
		if sphere != null:
			distinct_meshes[sphere.get_instance_id()] = sphere
		var material := instance.material_override as StandardMaterial3D
		_expect(material != null, "%s has no StandardMaterial3D material_override, so its colour cannot be shared." % label)
		if material == null:
			continue
		var colour_key := String(material.albedo_color.to_html(false))
		var shared: StandardMaterial3D = material_by_colour.get(colour_key)
		if shared == null:
			material_by_colour[colour_key] = material
		else:
			_expect(shared == material, "%s uses colour #%s but a different material resource than the other #%s nodes." % [label, colour_key, colour_key])
	_expect(distinct_meshes.size() == 1, "%s uses %d distinct SphereMesh resources; exactly 1 is shared." % [str(group.get_path()), distinct_meshes.size()])


## Bank stones and boulders use the same 7 × 4 unit sphere, so the shared
## resource must cross group boundaries instead of being cached per group.
func _check_shared_sphere_across_groups(stones: Node3D, rocks: Node3D) -> void:
	var stone_meshes := _prefixed_meshes(stones, "BankStone")
	if stone_meshes.is_empty():
		_expect(false, "BankStones has no meshes to compare with the outer boulders.")
		return
	var boulders := rocks.find_children("Boulder*", "MeshInstance3D", true, false)
	if boulders.is_empty():
		_expect(false, "OuterRocks has no boulders to compare with the bank stones.")
		return
	var stone := stone_meshes[0] as MeshInstance3D
	var boulder := boulders[0] as MeshInstance3D
	_expect(stone.mesh == boulder.mesh, "Bank stones and boulders must share the same unit SphereMesh resource across groups.")


func _check_no_collision(environment: Node3D) -> void:
	var collisions := environment.find_children("*", "CollisionObject3D", true, false)
	var description := "VisualEnvironment must not add CollisionObject3D nodes; found %d." % collisions.size()
	if not collisions.is_empty():
		description += " First offender: %s." % str(collisions[0].get_path())
	_expect(collisions.is_empty(), description)


func _check_mesh_budget(natural: Node3D) -> void:
	var mesh_count := natural.find_children("*", "MeshInstance3D", true, false).size()
	_expect(mesh_count <= MAX_MESH_INSTANCES, "NaturalScenery adds %d MeshInstance3D nodes; the limit is %d." % [mesh_count, MAX_MESH_INSTANCES])


func _check_determinism(first: Node3D, second: Node3D) -> void:
	var first_nodes := _collect_transform_nodes(first)
	var second_nodes := _collect_transform_nodes(second)
	_expect(first_nodes.size() == second_nodes.size(), "Determinism: the first NaturalScenery has %d transform nodes and the second has %d." % [first_nodes.size(), second_nodes.size()])
	for key in first_nodes:
		var other = second_nodes.get(key)
		if other == null:
			_expect(false, "Determinism: the second NaturalScenery is missing %s." % str(key))
			continue
		var a: Node3D = first_nodes[key]
		var b: Node3D = other
		_expect(a.position.distance_to(b.position) <= SCALE_TOLERANCE, "Determinism: %s has local position %s on the first instance and %s on the second." % [str(key), str(a.position), str(b.position)])
		_expect(a.scale.distance_to(b.scale) <= SCALE_TOLERANCE, "Determinism: %s has local scale %s on the first instance and %s on the second." % [str(key), str(a.scale), str(b.scale)])
		_expect(a.rotation.distance_to(b.rotation) <= SCALE_TOLERANCE, "Determinism: %s has local rotation %s on the first instance and %s on the second." % [str(key), str(a.rotation), str(b.rotation)])


func _check_existing_scenery(environment: Node3D) -> void:
	_expect(environment.get_node_or_null("GoldenTree") != null, "GoldenTree is missing after the natural scenery pass.")
	var logs: Array[MeshInstance3D] = []
	for index in range(3):
		var log := environment.get_node_or_null("DamProgressLog%d" % index) as MeshInstance3D
		_expect(log != null, "DamProgressLog%d is missing after the natural scenery pass." % index)
		if log != null:
			logs.append(log)
	_expect(environment.get_node_or_null("DamBrush") != null, "DamBrush is missing after the natural scenery pass.")
	_expect(environment.get_node_or_null("DamSpillway") != null, "DamSpillway is missing after the natural scenery pass.")
	environment.set_dam_state(2, "")
	_expect(environment.get_visible_dam_log_count() == 2, "set_dam_state(2) reports %d visible logs instead of 2." % environment.get_visible_dam_log_count())
	for index in range(logs.size()):
		_expect(logs[index].visible == (index < 2), "DamProgressLog%d visibility does not match dam state 2." % index)
	environment.set_dam_state(0, "")
	_expect(environment.get_visible_dam_log_count() == 0, "set_dam_state(0) reports %d visible logs instead of 0." % environment.get_visible_dam_log_count())
	for index in range(logs.size()):
		_expect(not logs[index].visible, "DamProgressLog%d is still visible after set_dam_state(0)." % index)


func _check_grounded(node: Node3D, terrain, minimum_above_full: float, kind: String) -> void:
	var xz := Vector2(node.global_position.x, node.global_position.z)
	var ground: float = terrain.height_at(xz)
	var offset: float = node.global_position.y - ground
	var label := "%s %s" % [kind, str(node.get_path())]
	_expect(absf(offset) <= GROUND_TOLERANCE, "%s is not grounded: its origin is %.3f m from the terrain (limit %.2f m)." % [label, offset, GROUND_TOLERANCE])
	_expect(ground >= terrain.full_water_level() + minimum_above_full - BAND_EPSILON, "%s sits on terrain height %.3f, below the dry threshold %.3f." % [label, ground, terrain.full_water_level() + minimum_above_full])


func _check_clearance(node: Node3D, points: Array, minimum: float, kind: String) -> void:
	var xz := Vector2(node.global_position.x, node.global_position.z)
	for point: Vector2 in points:
		var gap := xz.distance_to(point)
		_expect(gap >= minimum - BAND_EPSILON, "%s %s is %.2f m from task point %s; at least %.1f m are required." % [kind, str(node.get_path()), gap, str(point), minimum])


func _check_names_contiguous(group: Node3D, items: Array, prefix: String) -> void:
	for index in range(items.size()):
		var expected_name := "%s%d" % [prefix, index]
		_expect(group.get_node_or_null(expected_name) != null, "%s is missing the expected node %s." % [str(group.get_path()), expected_name])


func _prefixed_meshes(group: Node3D, prefix: String) -> Array:
	var result: Array = []
	for child in group.get_children():
		if child is MeshInstance3D and String(child.name).begins_with(prefix):
			result.append(child)
	return result


func _mesh_children(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child)
	return result


func _collect_transform_nodes(scenery: Node3D) -> Dictionary:
	var result := {}
	for child in scenery.get_children():
		_collect_transform_nodes_into(child, scenery, result)
	return result


func _collect_transform_nodes_into(node: Node, scenery: Node3D, result: Dictionary) -> void:
	if node is Node3D:
		result[String(scenery.get_path_to(node))] = node
	for child in node.get_children():
		_collect_transform_nodes_into(child, scenery, result)

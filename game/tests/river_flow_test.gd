extends SceneTree
## E1 visible river current: the downstream stream animates through the flow
## shader while the upstream lake stays calm, the prepared water meshes and
## materials stay cached, and the dam gains restrained, deterministic foam.
## Water levels, routes, saves and collision behaviour stay unchanged.

const TerrainScript = preload("res://scripts/valley_terrain.gd")
const LayoutScript = preload("res://scripts/valley_layout.gd")
const EnvironmentScript = preload("res://scripts/visual_environment.gd")
const DamSave = preload("res://scripts/dam_save.gd")
const DamRecipe = preload("res://scripts/dam_recipe.gd")
const SCENE_PATH := "res://scenes/movement.tscn"
const SHADER_PATH := "res://shaders/water_flow.gdshader"
const TEST_ROOT := "user://river_flow_test/"
const WORLD_DIRECTORY := TEST_ROOT + "world/"
const SUCCESS_MARKER := "CASTOR_RIVER_FLOW_OK shader_time cached_materials flow_curve clear_cache dam_foam foam_pulse world_wiring"
const TOLERANCE := 0.001
const UPSTREAM_SPEED := 0.10
const UPSTREAM_STRENGTH := 0.025
const DOWNSTREAM_SPEEDS: Array[float] = [0.62, 0.55, 0.48, 0.41]
const DOWNSTREAM_STRENGTHS: Array[float] = [0.16, 0.14, 0.12, 0.10]
const DAM_FOAM_INTENSITIES: Array[float] = [0.0, 0.5, 0.8, 1.0]
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _close(actual: float, expected: float) -> bool:
	return absf(actual - expected) <= TOLERANCE


func _within(actual: float, expected: float, tolerance: float) -> bool:
	return absf(actual - expected) <= tolerance


func _run() -> void:
	var terrain = TerrainScript.new()
	terrain.configure(&"wide_bank")
	var layout = LayoutScript.new()
	layout.configure(terrain)
	var initial: float = terrain.initial_water_level()
	var full: float = terrain.full_water_level()
	var cache: Vector2 = layout.food_cache_xz()

	# a) The shader loads and the two cached materials drive the reach meshes.
	var shader: Shader = load(SHADER_PATH) as Shader
	_expect(shader != null, "The water flow shader resource did not load.")
	if shader != null:
		_expect(shader.code.contains("TIME"), "The water flow shader does not animate with TIME.")

	var lake_mesh: ArrayMesh = terrain.water_mesh_reach(full, true, cache, 1.15)
	var stream_mesh: ArrayMesh = terrain.water_mesh_reach(initial, false)
	_expect(lake_mesh.get_surface_count() > 0, "The upstream lake mesh is empty.")
	_expect(stream_mesh.get_surface_count() > 0, "The downstream stream mesh is empty.")
	var lake_material := _surface_material(lake_mesh)
	var stream_material := _surface_material(stream_mesh)
	_expect(lake_material is ShaderMaterial, "The upstream lake mesh does not use a ShaderMaterial.")
	_expect(stream_material is ShaderMaterial, "The downstream stream mesh does not use a ShaderMaterial.")
	_expect(not is_same(lake_material, stream_material), "The upstream and downstream water share one material.")
	if shader != null and lake_material is ShaderMaterial:
		_expect((lake_material as ShaderMaterial).shader == shader, "The lake material was not created from the water flow shader.")
	if shader != null and stream_material is ShaderMaterial:
		_expect((stream_material as ShaderMaterial).shader == shader, "The stream material was not created from the water flow shader.")

	var cached_lake: Material = terrain.water_flow_material(true)
	var cached_stream: Material = terrain.water_flow_material(false)
	_expect(cached_lake is ShaderMaterial, "ValleyTerrain does not expose the cached upstream flow material.")
	_expect(cached_stream is ShaderMaterial, "ValleyTerrain does not expose the cached downstream flow material.")
	_expect(cached_lake != null and is_same(cached_lake, lake_material), "The lake mesh does not reuse the cached upstream material.")
	_expect(cached_stream != null and is_same(cached_stream, stream_material), "The stream mesh does not reuse the cached downstream material.")
	var repeated_lake: ArrayMesh = terrain.water_mesh_reach(full, true, cache, 1.15)
	var repeated_stream: ArrayMesh = terrain.water_mesh_reach(initial, false)
	_expect(is_same(lake_mesh, repeated_lake), "Repeated upstream mesh requests rebuilt the lake mesh.")
	_expect(is_same(stream_mesh, repeated_stream), "Repeated downstream mesh requests rebuilt the stream mesh.")
	_expect(is_same(_surface_material(repeated_lake), lake_material), "Repeated upstream requests created a new lake material.")
	_expect(is_same(_surface_material(repeated_stream), stream_material), "Repeated downstream requests created a new stream material.")
	var other_lake: ArrayMesh = terrain.water_mesh_reach(terrain.intermediate_water_level(), true)
	_expect(is_same(_surface_material(other_lake), lake_material), "A new lake level did not reuse the cached upstream material.")

	# b) Identical reach arguments return the identical mesh with its vertex alpha.
	var positions := _surface_positions(lake_mesh)
	var colors := _surface_colors(lake_mesh)
	_expect(not positions.is_empty(), "The cached lake mesh has no vertices.")
	_expect(colors.size() == positions.size() and not colors.is_empty(), "The cached lake mesh lost its vertex colours.")
	_expect(_minimum_alpha(colors) < 0.999, "The cached lake mesh lost its vertex alpha.")

	# c) Prepared flow values, calmer upstream and clamped inputs.
	var previous_speed := INF
	var previous_strength := INF
	for count in range(4):
		terrain.set_river_flow(count)
		var speed: float = terrain.river_flow_speed(false)
		var strength: float = terrain.river_flow_strength(false)
		_expect(_close(speed, DOWNSTREAM_SPEEDS[count]), "The downstream speed at %d placements is %.3f instead of %.3f." % [count, speed, DOWNSTREAM_SPEEDS[count]])
		_expect(_close(strength, DOWNSTREAM_STRENGTHS[count]), "The downstream strength at %d placements is %.3f instead of %.3f." % [count, strength, DOWNSTREAM_STRENGTHS[count]])
		_expect(_close(float(terrain.river_flow_speed(true)), UPSTREAM_SPEED), "The upstream speed changed at %d placements." % count)
		_expect(_close(float(terrain.river_flow_strength(true)), UPSTREAM_STRENGTH), "The upstream strength changed at %d placements." % count)
		_expect(float(terrain.river_flow_speed(true)) < speed, "The upstream lake is not calmer than the stream at %d placements." % count)
		_expect(float(terrain.river_flow_strength(true)) < strength, "The upstream lake foam is not quieter than the stream at %d placements." % count)
		if count > 0:
			_expect(speed <= previous_speed + TOLERANCE, "The downstream speed increased at %d placements." % count)
			_expect(strength <= previous_strength + TOLERANCE, "The downstream strength increased at %d placements." % count)
		# The cached materials are the only thing the shader reads, so the values
		# reported by the terrain must actually reach both of them. Deleting a
		# uniform write in set_river_flow now fails here.
		for upstream: bool in [true, false]:
			var reach_name := "upstream" if upstream else "downstream"
			var material := terrain.water_flow_material(upstream) as ShaderMaterial
			_expect(material != null, "The %s flow material is missing at %d placements." % [reach_name, count])
			if material == null:
				continue
			var material_speed: Variant = material.get_shader_parameter("flow_speed")
			var material_strength: Variant = material.get_shader_parameter("flow_strength")
			_expect(material_speed is float, "The %s material has no flow_speed at %d placements." % [reach_name, count])
			_expect(material_strength is float, "The %s material has no flow_strength at %d placements." % [reach_name, count])
			if material_speed is float:
				_expect(_close(float(material_speed), terrain.river_flow_speed(upstream)), "The %s material speed at %d placements is %.3f instead of %.3f." % [reach_name, count, float(material_speed), terrain.river_flow_speed(upstream)])
			if material_strength is float:
				_expect(_close(float(material_strength), terrain.river_flow_strength(upstream)), "The %s material strength at %d placements is %.3f instead of %.3f." % [reach_name, count, float(material_strength), terrain.river_flow_strength(upstream)])
		previous_speed = speed
		previous_strength = strength

	terrain.set_river_flow(-7)
	_expect(_close(float(terrain.river_flow_speed(false)), DOWNSTREAM_SPEEDS[0]), "A negative placement count did not clamp the downstream speed to zero.")
	_expect(_close(float(terrain.river_flow_strength(false)), DOWNSTREAM_STRENGTHS[0]), "A negative placement count did not clamp the downstream strength to zero.")
	terrain.set_river_flow(11)
	_expect(_close(float(terrain.river_flow_speed(false)), DOWNSTREAM_SPEEDS[3]), "A placement count above three did not clamp the downstream speed to three.")
	_expect(_close(float(terrain.river_flow_strength(false)), DOWNSTREAM_STRENGTHS[3]), "A placement count above three did not clamp the downstream strength to three.")
	terrain.set_river_flow(2)
	var idempotent_speed: float = terrain.river_flow_speed(false)
	var idempotent_strength: float = terrain.river_flow_strength(false)
	terrain.set_river_flow(2)
	_expect(_close(float(terrain.river_flow_speed(false)), idempotent_speed), "A repeated set_river_flow(2) changed the downstream speed.")
	_expect(_close(float(terrain.river_flow_strength(false)), idempotent_strength), "A repeated set_river_flow(2) changed the downstream strength.")
	for progress: float in [0.0, 0.1, 0.5, 1.0]:
		terrain.set_river_flow_progress(progress)
		var expected_speed := lerpf(DOWNSTREAM_SPEEDS[0], DOWNSTREAM_SPEEDS[3], progress)
		var expected_strength := lerpf(DOWNSTREAM_STRENGTHS[0], DOWNSTREAM_STRENGTHS[3], progress)
		_expect(_close(float(terrain.river_flow_speed(false)), expected_speed), "Normalized progress %.2f did not map to the prepared downstream speed." % progress)
		_expect(_close(float(terrain.river_flow_strength(false)), expected_strength), "Normalized progress %.2f did not map to the prepared downstream strength." % progress)
	terrain.set_river_flow_progress(-2.0)
	_expect(_close(float(terrain.river_flow_speed(false)), DOWNSTREAM_SPEEDS[0]), "Negative normalized progress did not clamp to the original flow minimum.")
	terrain.set_river_flow_progress(4.0)
	_expect(_close(float(terrain.river_flow_speed(false)), DOWNSTREAM_SPEEDS[3]), "Normalized progress above one exceeded the original flow maximum.")

	# d) Flow changes update the cached materials; prepared meshes stay cached.
	var all_mesh: ArrayMesh = terrain.water_mesh(full, cache, 1.15)
	for count in range(4):
		terrain.set_river_flow(count)
		_expect(is_same(terrain.water_mesh(full, cache, 1.15), all_mesh), "Setting the flow to %d rebuilt the combined water mesh." % count)
		_expect(is_same(terrain.water_mesh_reach(full, true, cache, 1.15), lake_mesh), "Setting the flow to %d rebuilt the lake mesh." % count)
		_expect(is_same(terrain.water_mesh_reach(initial, false), stream_mesh), "Setting the flow to %d rebuilt the stream mesh." % count)
		_expect(is_same(terrain.water_flow_material(true), cached_lake), "Setting the flow to %d replaced the upstream material." % count)
		_expect(is_same(terrain.water_flow_material(false), cached_stream), "Setting the flow to %d replaced the downstream material." % count)

	# e) The food-cache window keeps its clearer vertex alpha.
	var minimum_alpha := 1.0
	for index in range(positions.size()):
		if index >= colors.size():
			break
		var xz := Vector2(positions[index].x, positions[index].z)
		if xz.distance_to(cache) <= 0.65:
			minimum_alpha = minf(minimum_alpha, colors[index].a)
	_expect(minimum_alpha < 0.55, "The clear-water window above the food cache lost its lower alpha.")

	await _check_dam_foam(terrain, layout)
	await _check_world_wiring()

	_remove_directory(WORLD_DIRECTORY)
	_remove_directory(TEST_ROOT)
	if failures == 0:
		print(SUCCESS_MARKER)
	quit(0 if failures == 0 else 1)


## f) Four deterministic foam patches sit at the downstream dam base, appear
## with the first placement and grow with the prepared intensity.
func _check_dam_foam(terrain: ValleyTerrain, layout: ValleyLayout) -> void:
	var environment = EnvironmentScript.new()
	environment.configure(terrain, layout)
	root.add_child(environment)
	await process_frame

	var foam_group := environment.find_child("DamFoam", true, false) as Node3D
	_expect(foam_group != null, "VisualEnvironment has no DamFoam group.")
	var patches: Array[MeshInstance3D] = []
	for index in range(4):
		var patch := environment.find_child("DamFoam%d" % index, true, false) as MeshInstance3D
		patches.append(patch)
		_expect(patch != null, "The dam foam is missing patch DamFoam%d." % index)
		if patch == null:
			continue
		_expect(patch.mesh != null and patch.mesh.get_surface_count() > 0, "DamFoam%d has no flat mesh." % index)
		if foam_group != null:
			_expect(foam_group.is_ancestor_of(patch), "DamFoam%d is not part of the DamFoam group." % index)
		_expect(patch.global_position.z > terrain.dam_z(), "DamFoam%d is not downstream of the dam." % index)
		_expect(patch.global_position.y > terrain.initial_water_level(), "DamFoam%d is not above the initial stream level." % index)
		_expect(patch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "DamFoam%d casts a shadow." % index)
		# The foam must stay a tight collar on the downstream face instead of
		# drifting into the stream or spreading into a wide sheet.
		var downstream_distance := patch.global_position.z - terrain.dam_z()
		_expect(downstream_distance > 0.0 and downstream_distance <= 0.9 + TOLERANCE, "DamFoam%d sits %.2f m downstream of the dam face; the limit is 0.9 m." % [index, downstream_distance])
		var disc := patch.mesh as CylinderMesh
		_expect(disc != null, "DamFoam%d is not a flat cylinder patch." % index)
		if disc != null:
			var patch_scale := patch.global_transform.basis.get_scale()
			var horizontal_scale := maxf(absf(patch_scale.x), absf(patch_scale.z))
			var horizontal_radius := maxf(disc.top_radius, disc.bottom_radius) * horizontal_scale
			_expect(horizontal_radius <= 0.6 + TOLERANCE, "DamFoam%d has a %.2f m horizontal radius; the limit is 0.6 m." % [index, horizontal_radius])
	var foam_host: Node = foam_group
	if foam_host == null:
		foam_host = environment as Node
	_expect(foam_host.find_children("*", "CollisionObject3D", true, false).is_empty(), "The dam foam added collision bodies.")
	var pulse_pool: Array = environment.get("_dam_foam_pulse_pool")
	_expect(pulse_pool.size() == 6, "The dam foam did not prebuild its bounded six-ring pulse pool.")
	var pulse_pool_ids: Array[int] = []
	var pulse_pool_materials: Array[Material] = []
	for pulse: MeshInstance3D in pulse_pool:
		pulse_pool_ids.append(pulse.get_instance_id())
		pulse_pool_materials.append(pulse.material_override)

	environment.set_dam_state(0, "")
	_expect(_close(float(environment.dam_foam_intensity()), DAM_FOAM_INTENSITIES[0]), "The dam foam intensity at zero placements is not zero.")
	for index in range(4):
		if patches[index] != null:
			_expect(not patches[index].is_visible_in_tree(), "DamFoam%d is visible before the first placement." % index)

	var previous_scales: Array[float] = [-1.0, -1.0, -1.0, -1.0]
	var previous_opacities: Array[float] = [-1.0, -1.0, -1.0, -1.0]
	for count in range(1, 4):
		environment.set_dam_state(count, "")
		_expect(_close(float(environment.dam_foam_intensity()), DAM_FOAM_INTENSITIES[count]), "The dam foam intensity at %d placements is not %.1f." % [count, DAM_FOAM_INTENSITIES[count]])
		for index in range(4):
			var patch := patches[index]
			if patch == null:
				continue
			_expect(patch.is_visible_in_tree(), "DamFoam%d is invisible at %d placements." % [index, count])
			var scale_magnitude := patch.global_transform.basis.get_scale().length()
			var opacity := _foam_opacity(patch)
			_expect(opacity >= 0.0, "DamFoam%d has no readable opacity at %d placements." % [index, count])
			if count > 1:
				_expect(scale_magnitude > previous_scales[index] + TOLERANCE, "DamFoam%d scale did not grow from %d to %d placements." % [index, count - 1, count])
				_expect(opacity > previous_opacities[index] + TOLERANCE, "DamFoam%d opacity did not grow from %d to %d placements." % [index, count - 1, count])
			previous_scales[index] = scale_magnitude
			previous_opacities[index] = opacity

	# g) A short pulse ring appears at the downstream face and never accumulates.
	environment.pulse_dam_foam()
	await process_frame
	_expect(environment.find_child("DamFoamPulse0", true, false) != null, "pulse_dam_foam did not create DamFoamPulse0.")
	_expect(environment.find_child("DamFoamPulse1", true, false) != null, "pulse_dam_foam did not create DamFoamPulse1.")
	var pulses := _pulse_nodes(environment)
	_expect(pulses.size() >= 2, "pulse_dam_foam created %d pulse nodes instead of a ring pair." % pulses.size())
	_expect(_close(float(environment.last_foam_pulse_strength), 1.0), "The default dam foam pulse strength is not 1.0.")
	var pulse_start_scales: Dictionary = {}
	for pulse in pulses:
		_expect(pulse.global_position.z > terrain.dam_z(), "A dam foam pulse node is not at the downstream face.")
		pulse_start_scales[pulse.get_instance_id()] = pulse.scale.x
	await create_timer(0.25).timeout
	var expanded_pulses := 0
	for pulse in _pulse_nodes(environment):
		var start_scale: Variant = pulse_start_scales.get(pulse.get_instance_id())
		if start_scale == null:
			continue
		_expect(pulse.scale.x > float(start_scale) + TOLERANCE, "A dam foam pulse ring did not expand after about 0.25 s.")
		expanded_pulses += 1
	_expect(expanded_pulses >= 2, "Fewer than two dam foam pulse rings expanded after about 0.25 s.")
	_expect(await _wait_for(func() -> bool: return _pulse_nodes(environment).is_empty(), 1.6), "The dam foam pulse nodes did not free within about 1.6 s.")
	for _call in range(10):
		environment.pulse_dam_foam(1.0)
	await process_frame
	_expect((environment.get("_dam_foam_pulse_pool") as Array).size() == pulse_pool.size(), "Repeated foam responses allocated more cached pulse nodes.")
	for index in range(pulse_pool.size()):
		var cached_pulse := pulse_pool[index] as MeshInstance3D
		_expect(cached_pulse.get_instance_id() == pulse_pool_ids[index] and is_same(cached_pulse.material_override, pulse_pool_materials[index]), "A repeated foam response replaced a cached pulse mesh instance or material.")
	var live_pulses := _pulse_nodes(environment)
	_expect(live_pulses.size() <= 6, "Ten quick dam foam pulses left %d live pulse nodes; at most six are allowed." % live_pulses.size())
	_expect(await _wait_for(func() -> bool: return _pulse_nodes(environment).is_empty(), 1.6), "The repeated dam foam pulses did not free within about 1.6 s.")

	environment.queue_free()
	await process_frame


## h/i) The playable world applies the prepared flow and keeps the lake and
## stream meshes on cached ShaderMaterials without touching the save directory.
func _check_world_wiring() -> void:
	_expect(DamSave.clear_save(WORLD_DIRECTORY), "Could not clear the river flow world save directory.")
	_remove_directory(WORLD_DIRECTORY)
	_expect(not _directory_exists(WORLD_DIRECTORY), "The river flow test could not start from a clean save directory.")

	root.size = Vector2i(960, 600)
	var world: Node = load(SCENE_PATH).instantiate()
	world.save_directory = WORLD_DIRECTORY
	root.add_child(world)
	await physics_frame
	await physics_frame

	var world_terrain = world.terrain
	_expect(world_terrain != null, "The movement world has no ValleyTerrain for the river flow wiring.")
	if world_terrain != null:
		_expect(_close(float(world_terrain.river_flow_speed(true)), UPSTREAM_SPEED), "Entering the world did not apply the calm upstream speed.")
		_expect(_close(float(world_terrain.river_flow_strength(true)), UPSTREAM_STRENGTH), "Entering the world did not apply the calm upstream strength.")
		var initial_stream := world.stream_surface as MeshInstance3D
		_expect(initial_stream != null, "The world does not expose its initial stream surface.")
		if initial_stream != null:
			_expect(_active_material(initial_stream) is ShaderMaterial, "The initial stream material is not a ShaderMaterial.")
		_expect(not _directory_exists(WORLD_DIRECTORY), "Entering the world created the isolated save directory.")

		await _check_presentation_path(world, world_terrain)

		for count in range(1, 16):
			world.placed_count = count
			world._update_water(false)
			var progress := float(count) / 15.0
			var expected_speed := lerpf(DOWNSTREAM_SPEEDS[0], DOWNSTREAM_SPEEDS[3], progress)
			var expected_strength := lerpf(DOWNSTREAM_STRENGTHS[0], DOWNSTREAM_STRENGTHS[3], progress)
			var expected_level := lerpf(float(world_terrain.initial_water_level()), float(world_terrain.full_water_level()), progress)
			_expect(_close(float(world_terrain.river_flow_speed(false)), expected_speed), "The world did not map mixed progress %.2f to the downstream speed." % progress)
			_expect(_close(float(world_terrain.river_flow_strength(false)), expected_strength), "The world did not map mixed progress %.2f to the downstream strength." % progress)
			_expect(_close(float(world.water_level), expected_level), "The mixed water level at %d placements does not follow the prepared range." % count)
			_expect(not _directory_exists(WORLD_DIRECTORY), "A water update at %d placements created the save directory." % count)

	var lake := world.get_node_or_null("ValleyLake") as MeshInstance3D
	var stream := world.get_node_or_null("ValleyStream") as MeshInstance3D
	_check_world_water_mesh(lake, "ValleyLake")
	_check_world_water_mesh(stream, "ValleyStream")

	world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(WORLD_DIRECTORY), "Could not clean the river flow world save directory.")
	_remove_directory(WORLD_DIRECTORY)


## The committed presentation path: each arrived placement re-applies the flow
## curve and pulses the foam. The first placement pulses at strength 1.0 and the
## final mixed placement at 1.4, so the last arrival reads as the stronger response.
func _check_presentation_path(world: Node, terrain: ValleyTerrain) -> void:
	var ripple_pool: Array = world.get("_water_ripple_nodes")
	var ripple_pool_ids: Array[int] = []
	var ripple_pool_materials: Array[Material] = []
	for ripple: MeshInstance3D in ripple_pool:
		ripple_pool_ids.append(ripple.get_instance_id())
		ripple_pool_materials.append(ripple.material_override)
	world.placed_count = 1
	world._presented_dam_count = 0
	world._present_dam_arrival()
	var environment := world.visual_environment as VisualEnvironment
	_expect(environment != null, "The world has no VisualEnvironment for the presentation path.")
	if environment == null:
		return
	var first_pair := _pulse_nodes(environment)
	_expect(first_pair.size() == 2, "The first presentation created %d dam foam pulse rings instead of two." % first_pair.size())
	_expect(_close(float(environment.last_foam_pulse_strength), 1.0), "The first presentation pulsed the foam at strength %.2f instead of 1.0." % environment.last_foam_pulse_strength)
	var first_scales: Dictionary = {}
	for pulse in first_pair:
		first_scales[pulse.get_instance_id()] = pulse.scale.x
		# The authored creation scale is 0.22 * strength; allow the tween's first
		# frame of growth but keep the 1.4-strength scale clearly out of range.
		_expect(_within(pulse.scale.x, 0.22, 0.03), "A first-presentation pulse ring starts at scale %.3f instead of the 1.0-strength scale 0.220." % pulse.scale.x)
	_expect(_close(float(terrain.river_flow_speed(false)), lerpf(DOWNSTREAM_SPEEDS[0], DOWNSTREAM_SPEEDS[3], 1.0 / 15.0)), "The first mixed presentation did not apply normalized downstream speed.")
	_expect(_close(float(terrain.river_flow_strength(false)), lerpf(DOWNSTREAM_STRENGTHS[0], DOWNSTREAM_STRENGTHS[3], 1.0 / 15.0)), "The first mixed presentation did not apply normalized downstream strength.")
	_expect(ripple_pool.size() == 3, "The world did not prebuild its three cached water ripple rings.")
	await process_frame
	_expect(_pulse_nodes(environment).size() == 2, "Waiting a frame did not keep exactly two first-presentation pulse rings alive.")

	world._dam_progress.configure(DamSave.MIXED_RECIPE_ID)
	for material_id: String in DamRecipe.for_id(DamSave.MIXED_RECIPE_ID).material_ids:
		world._dam_progress.place(material_id)
	world.placed_count = 15
	world._presented_dam_count = 1
	world._present_dam_arrival()
	var new_pulses: Array[Node3D] = []
	for pulse in _pulse_nodes(environment):
		if not first_scales.has(pulse.get_instance_id()):
			new_pulses.append(pulse)
	_expect(new_pulses.size() == 2, "The final mixed presentation created %d new pulse rings instead of two." % new_pulses.size())
	_expect(_close(float(environment.last_foam_pulse_strength), 1.4), "The final mixed presentation pulsed the foam at strength %.2f instead of 1.4." % environment.last_foam_pulse_strength)
	for pulse in new_pulses:
		var smallest_first_scale := 1.0
		for value in first_scales.values():
			smallest_first_scale = minf(smallest_first_scale, float(value))
		_expect(pulse.scale.x > smallest_first_scale + 0.04, "A final-presentation pulse ring (scale %.3f) is not larger than the first pair (scale %.3f)." % [pulse.scale.x, smallest_first_scale])
		_expect(_within(pulse.scale.x, 0.22 * 1.4, 0.03), "A final-presentation pulse ring starts at scale %.3f instead of the 1.4-strength scale 0.308." % pulse.scale.x)
	_expect(_close(float(terrain.river_flow_speed(false)), DOWNSTREAM_SPEEDS[3]), "The final mixed presentation did not apply the prepared downstream speed.")
	_expect(_close(float(terrain.river_flow_strength(false)), DOWNSTREAM_STRENGTHS[3]), "The final mixed presentation did not apply the prepared downstream strength.")
	_expect((world.get("_water_ripple_nodes") as Array).size() == ripple_pool.size(), "Repeated dam deliveries allocated extra water ripple nodes.")
	for index in range(ripple_pool.size()):
		var cached_ripple := ripple_pool[index] as MeshInstance3D
		_expect(cached_ripple.get_instance_id() == ripple_pool_ids[index] and is_same(cached_ripple.material_override, ripple_pool_materials[index]), "A dam delivery replaced a cached water ripple instance or material.")
	await process_frame
	_expect(_pulse_nodes(environment).size() == 4, "Waiting a frame did not keep both pulse pairs alive.")


func _check_world_water_mesh(instance: MeshInstance3D, node_name: String) -> void:
	_expect(instance != null, "The world does not expose the %s mesh." % node_name)
	if instance == null:
		return
	var mesh := instance.mesh as ArrayMesh
	_expect(mesh != null and mesh.get_surface_count() > 0 and mesh.surface_get_array_len(0) > 0, "The %s mesh is empty." % node_name)
	_expect(_active_material(instance) is ShaderMaterial, "The %s mesh does not use a ShaderMaterial." % node_name)


func _surface_material(mesh: ArrayMesh, surface_index: int = 0) -> Material:
	if mesh.get_surface_count() <= surface_index:
		return null
	return mesh.surface_get_material(surface_index)


func _surface_positions(mesh: ArrayMesh, surface_index: int = 0) -> PackedVector3Array:
	if mesh.get_surface_count() <= surface_index:
		return PackedVector3Array()
	var arrays := mesh.surface_get_arrays(surface_index)
	var value: Variant = arrays[Mesh.ARRAY_VERTEX]
	if value is PackedVector3Array:
		var typed: PackedVector3Array = value
		return typed
	return PackedVector3Array()


func _surface_colors(mesh: ArrayMesh, surface_index: int = 0) -> PackedColorArray:
	if mesh.get_surface_count() <= surface_index:
		return PackedColorArray()
	var arrays := mesh.surface_get_arrays(surface_index)
	var value: Variant = arrays[Mesh.ARRAY_COLOR]
	if value is PackedColorArray:
		var typed: PackedColorArray = value
		return typed
	return PackedColorArray()


func _minimum_alpha(colors: PackedColorArray) -> float:
	var minimum := 1.0
	for color in colors:
		minimum = minf(minimum, color.a)
	return minimum


func _mesh_material(instance: MeshInstance3D) -> Material:
	if instance == null:
		return null
	if instance.material_override != null:
		return instance.material_override
	var mesh := instance.mesh
	if mesh == null:
		return null
	if mesh.get_surface_count() > 0:
		var surface_material := mesh.surface_get_material(0)
		if surface_material != null:
			return surface_material
	var primitive := mesh as PrimitiveMesh
	if primitive != null:
		return primitive.material
	return null


func _active_material(instance: MeshInstance3D) -> Material:
	if instance == null:
		return null
	var active := instance.get_active_material(0)
	if active != null:
		return active
	return _mesh_material(instance)


## Opacity is read from the patch material, or from the instance transparency
## when the implementation fades the node instead of its material colour.
func _foam_opacity(patch: MeshInstance3D) -> float:
	var material := _mesh_material(patch)
	var opacity := 1.0
	var readable := false
	if material is StandardMaterial3D:
		opacity = (material as StandardMaterial3D).albedo_color.a
		readable = true
	elif material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		for parameter: String in ["foam_color", "foam_tint", "foam_tint_color", "foam", "tint", "tint_color", "albedo_color", "color", "base_color"]:
			var value: Variant = shader_material.get_shader_parameter(parameter)
			if value is Color:
				opacity = (value as Color).a
				readable = true
				break
		if not readable:
			for parameter: String in ["foam_opacity", "foam_alpha", "foam_strength", "opacity", "alpha", "flow_strength", "strength", "intensity"]:
				var float_value: Variant = shader_material.get_shader_parameter(parameter)
				if float_value is float or float_value is int:
					opacity = float(float_value)
					readable = true
					break
	if patch.transparency > 0.0001:
		opacity *= 1.0 - patch.transparency
		readable = true
	return opacity if readable else -1.0


## The environment tracks every live pulse in `_dam_foam_pulses`; Godot renames
## a duplicate sibling to a generic @MeshInstance3D name, so a name scan alone
## would miss a second ring pair. Prefer the tracked list and fall back to names.
func _pulse_nodes(environment: Node) -> Array[Node3D]:
	var tracked: Variant = environment.get("_dam_foam_pulses")
	if tracked is Array:
		var live: Array[Node3D] = []
		for candidate in tracked:
			var node := candidate as Node3D
			if node != null and is_instance_valid(node):
				live.append(node)
		return live
	var nodes: Array[Node3D] = []
	for candidate in environment.find_children("*", "Node3D", true, false):
		var node := candidate as Node3D
		if not String(node.name).contains("DamFoamPulse"):
			continue
		if not _has_pulse_ancestor(node, environment):
			nodes.append(node)
	return nodes


func _has_pulse_ancestor(node: Node3D, environment: Node) -> bool:
	var ancestor := node.get_parent()
	while ancestor != null and ancestor != environment:
		if String(ancestor.name).contains("DamFoamPulse"):
			return true
		ancestor = ancestor.get_parent()
	return false


func _wait_for(condition: Callable, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if condition.call():
			return true
	return condition.call()


func _directory_exists(directory: String) -> bool:
	return DirAccess.dir_exists_absolute(_absolute_path(directory))


func _remove_directory(directory: String) -> void:
	var absolute := _absolute_path(directory)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute(absolute)


func _absolute_path(directory: String) -> String:
	return ProjectSettings.globalize_path(directory).trim_suffix("/")

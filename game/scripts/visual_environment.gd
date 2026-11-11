extends Node3D
class_name VisualEnvironment
## Code-authored scenery grounded on the authored terrain. Attach as a child of
## the world. This node creates no physics bodies.

const Shapes = preload("res://scripts/prototype_shapes.gd")
const GoldenTreeScene = preload("res://assets/environment/meshy_tree/golden_tree.glb")
const GOLDEN_TREE_SCALE: float = 0.68

## Authored placement for the natural scenery pass. Every entry is plain constant
## data grounded on the terrain grid, so two environments always build the same
## bank, clearing and outer slopes. The bank stones follow the east waterline in
## wide_bank, the layout the playable chapter uses. Loose pairs and uneven gaps
## keep the shore from reading as a dotted line.
const BANK_STONE_XZ: Array[Vector2] = [
	Vector2(-2.64, -4.78), Vector2(-2.52, -4.62), Vector2(-2.42, -4.34),
	Vector2(-2.44, -3.80), Vector2(-2.36, -3.30), Vector2(-2.28, -3.16),
	Vector2(-2.26, -2.82), Vector2(-2.18, -2.38), Vector2(-2.10, -2.20),
	Vector2(-2.06, -1.82), Vector2(-1.98, -1.30), Vector2(-1.90, -0.82),
	Vector2(-1.84, -0.70), Vector2(-1.84, -0.28), Vector2(-1.82, 0.22),
	Vector2(-1.80, 0.70), Vector2(-1.80, 1.18), Vector2(-1.76, 1.66),
	Vector2(-1.78, 2.16), Vector2(-1.80, 2.66), Vector2(-1.84, 2.80),
	Vector2(-1.86, 3.18), Vector2(-1.95, 3.70), Vector2(-1.55, 0.95),
]
const BANK_STONE_SCALE: Array[Vector3] = [
	Vector3(0.22, 0.13, 0.20), Vector3(0.26, 0.15, 0.23), Vector3(0.17, 0.10, 0.16),
	Vector3(0.24, 0.14, 0.21), Vector3(0.19, 0.11, 0.17), Vector3(0.28, 0.16, 0.24),
	Vector3(0.16, 0.10, 0.14), Vector3(0.21, 0.12, 0.19), Vector3(0.25, 0.13, 0.22),
	Vector3(0.18, 0.11, 0.16), Vector3(0.23, 0.12, 0.20), Vector3(0.16, 0.10, 0.14),
	Vector3(0.27, 0.14, 0.22), Vector3(0.20, 0.12, 0.18), Vector3(0.17, 0.10, 0.15),
	Vector3(0.29, 0.15, 0.25), Vector3(0.22, 0.12, 0.19), Vector3(0.19, 0.10, 0.16),
	Vector3(0.25, 0.14, 0.21), Vector3(0.18, 0.10, 0.16), Vector3(0.21, 0.12, 0.18),
	Vector3(0.24, 0.13, 0.20), Vector3(0.16, 0.10, 0.15), Vector3(0.27, 0.15, 0.23),
]
const BANK_STONE_YAW: Array[float] = [
	0.4, 1.2, 2.1, 0.7, 1.6, 2.6, 0.2, 1.0, 1.9, 2.9, 0.6, 1.4, 2.3, 0.3, 1.1, 2.0, 2.7, 0.9,
	1.8, 2.5, 0.5, 1.3, 2.8, 1.7,
]
const STONE_COLORS: Array[Color] = [
	Color("6f7d78"), Color("748079"), Color("78847d"), Color("7b8780"), Color("7f8b84"),
]

## Two or three loose mud groups on the damp bank: one below the lodge approach,
## one beside the dam approach and one on the northern bank. Neighbouring lenses
## overlap, so a group reads as one soft mud area instead of separate pies.
const MUD_PATCH_XZ: Array[Vector2] = [
	Vector2(-1.54, -5.18), Vector2(-1.66, -4.98), Vector2(-1.58, -4.76),
	Vector2(-1.48, -1.34), Vector2(-1.34, -1.18), Vector2(-1.26, -0.94),
	Vector2(-1.08, 2.26), Vector2(-0.94, 2.44), Vector2(-0.90, 2.66),
]
const MUD_PATCH_SCALE: Array[Vector3] = [
	Vector3(0.74, 0.050, 0.62), Vector3(0.86, 0.045, 0.72), Vector3(0.62, 0.050, 0.54),
	Vector3(0.78, 0.055, 0.66), Vector3(0.60, 0.045, 0.56), Vector3(0.70, 0.050, 0.58),
	Vector3(0.82, 0.050, 0.68), Vector3(0.58, 0.040, 0.50), Vector3(0.66, 0.050, 0.58),
]
const MUD_COLORS: Array[Color] = [
	Color("6b4a2f"), Color("745436"), Color("7a5a3a"),
]

## Planted clusters hug the clearing edges. Their centres passed clearance and
## spacing checks, so only the member composition changed with the N1 review.
const CLUSTER_CENTRES: Array[Vector2] = [
	Vector2(-1.60, 5.00), Vector2(6.00, 2.40), Vector2(6.00, -3.00), Vector2(2.00, 5.00),
]
## Two bushes and one reed keep each cluster reading as one planted clump. Every
## plant stays inside 0.35 m of the cluster centre; the wider spread replaces
## the old isolated pair without closing the clearing.
const CLUSTER_BUSH_OFFSETS: Array[Vector2] = [
	Vector2(-0.16, 0.10), Vector2(0.16, 0.12), Vector2(-0.15, -0.12), Vector2(0.17, 0.09),
	Vector2(0.12, -0.15), Vector2(-0.17, 0.11), Vector2(0.15, 0.13), Vector2(-0.16, -0.10),
]
const CLUSTER_REED_OFFSET: Array[Vector2] = [
	Vector2(0.02, -0.20), Vector2(-0.14, 0.14), Vector2(0.16, 0.12), Vector2(0.02, 0.20),
]
const CLUSTER_SCALE: Array[float] = [0.92, 1.00, 0.96, 0.94]

## Boulder groups frame the enclosing north and west slopes, where the wide-bank
## terrain actually rises. Every formation origin sits at least 8 degrees off
## flat, and every boulder stays fully outside the playable rectangle.
const OUTER_ROCK_XZ: Array[Vector2] = [
	Vector2(-10.00, 2.50), Vector2(-10.50, -2.50), Vector2(-10.50, -8.50), Vector2(2.50, -8.00),
]
## Offsets are local to the grounded formation origin. Colours come from
## BOULDER_COLORS so boulders share material resources instead of owning one each.
const OUTER_ROCK_BOULDERS: Array[Dictionary] = [
	{"formation": 0, "offset": Vector3(-0.30, 0.26, 0.10), "size": Vector3(1.10, 0.74, 1.24), "yaw": 0.25},
	{"formation": 0, "offset": Vector3(0.42, 0.18, 0.34), "size": Vector3(0.70, 0.46, 0.64), "yaw": -0.50},
	{"formation": 0, "offset": Vector3(0.10, 0.16, -0.46), "size": Vector3(0.62, 0.40, 0.72), "yaw": 0.90},
	{"formation": 1, "offset": Vector3(-0.24, 0.28, -0.16), "size": Vector3(1.20, 0.80, 1.10), "yaw": -0.20},
	{"formation": 1, "offset": Vector3(0.36, 0.20, 0.30), "size": Vector3(0.78, 0.50, 0.72), "yaw": 0.60},
	{"formation": 1, "offset": Vector3(0.20, 0.15, -0.42), "size": Vector3(0.58, 0.38, 0.60), "yaw": 1.30},
	{"formation": 2, "offset": Vector3(-0.34, 0.30, 0.06), "size": Vector3(1.26, 0.86, 1.16), "yaw": 0.35},
	{"formation": 2, "offset": Vector3(0.30, 0.22, 0.34), "size": Vector3(0.88, 0.58, 0.80), "yaw": -0.70},
	{"formation": 2, "offset": Vector3(0.34, 0.17, -0.38), "size": Vector3(0.66, 0.44, 0.68), "yaw": 0.95},
	{"formation": 2, "offset": Vector3(-0.10, 0.14, 0.62), "size": Vector3(0.52, 0.34, 0.54), "yaw": 1.70},
	{"formation": 3, "offset": Vector3(-0.28, 0.24, 0.12), "size": Vector3(1.02, 0.70, 1.08), "yaw": -0.35},
	{"formation": 3, "offset": Vector3(0.34, 0.18, -0.24), "size": Vector3(0.72, 0.48, 0.66), "yaw": 0.75},
	{"formation": 3, "offset": Vector3(0.06, 0.15, 0.46), "size": Vector3(0.60, 0.40, 0.62), "yaw": 1.45},
]
## Darkened boulder palette: the previous light stone greys read almost white
## under the authored lighting.
const BOULDER_COLORS: Array[Color] = [
	Color("64736c"), Color("6a7972"), Color("6f7e77"), Color("75827a"), Color("6c7b74"),
]

## E1 visible current: restrained foam at the downstream base of the dam. The
## patches are flat, unshaded and collider-free, and both their size and their
## opacity follow the authored dam count. Positions derive only from the authored
## dam span and crest, so two environments always build the same foam.
const DAM_FOAM_NAMES: Array[String] = ["DamFoam0", "DamFoam1", "DamFoam2", "DamFoam3"]
const DAM_FOAM_INTENSITY: Array[float] = [0.0, 0.5, 0.8, 1.0]
const DAM_FOAM_PATCH_SCALE: Array[Vector3] = [
	Vector3(0.98, 1.0, 0.62), Vector3(0.72, 1.0, 0.48),
	Vector3(0.84, 1.0, 0.54), Vector3(0.64, 1.0, 0.44),
]
const DAM_FOAM_COLORS: Array[Color] = [
	Color(0.90, 0.96, 0.94, 0.68), Color(0.86, 0.94, 0.93, 0.64),
	Color(0.92, 0.97, 0.95, 0.66), Color(0.84, 0.93, 0.92, 0.62),
]
const DAM_FOAM_DOWNSTREAM_OFFSET: float = 0.42
const DAM_FOAM_PULSE_LIMIT: int = 6
const DAM_FOAM_PULSE_LIFETIME: float = 1.1
const DAM_FOAM_PULSE_COLOR := Color(0.88, 0.95, 0.93, 0.55)

var _terrain: ValleyTerrain
var _layout: ValleyLayout
## Read-only for callers: the strength used by the most recent foam pulse, so a
## presentation test can tell the 1.0 first-placement pulse from the 1.4 final.
var last_foam_pulse_strength: float = 0.0
var _dam_logs: Array[MeshInstance3D] = []
var _dam_extra_nodes: Array[Node3D] = []
var _dam_count: int = 0
var _dam_log_materials: Dictionary = {}
var _water_level: float = 0.0
var _spillway: Node3D
var _spillway_strips: Array[MeshInstance3D] = []
var _spill_foam: MeshInstance3D
var _dam_foam: Node3D
var _dam_foam_patches: Array[MeshInstance3D] = []
var _dam_foam_pulses: Array[MeshInstance3D] = []
var _dam_foam_pulse_tweens: Dictionary = {}
var _dam_foam_pulse_pool: Array[MeshInstance3D] = []
## Natural-scenery meshes and materials are shared resources: the unit sphere is
## keyed by (radial_segments, rings) and scaled per instance, while the material
## is keyed by colour. The dam logs, shore rocks and backdrop hills keep their
## per-mesh materials through _ellipsoid/_cylinder.
var _sphere_meshes: Dictionary = {}
var _scenery_materials: Dictionary = {}


func configure(terrain: ValleyTerrain, layout: ValleyLayout) -> void:
	_terrain = terrain
	_layout = layout
	_water_level = terrain.initial_water_level()


func _ready() -> void:
	_build_backdrop_hills()
	_build_vegetation()
	_build_natural_scenery()
	_build_grove()
	_build_dam_structure()
	_build_dam_foam_pulse_pool()


## Distant, non-playable hills behind the authored boundary. They continue the
## valley silhouette past the terrain edge, so the far ridge does not end in a
## hard cut against the background.
func _build_backdrop_hills() -> void:
	var hills := Node3D.new()
	hills.name = "BackdropHills"
	add_child(hills)
	var specs: Array[Dictionary] = [
		{"position": Vector3(-24, -1.5, -10), "scale": Vector3(18, 5.0, 14), "color": Color("5b785b")},
		{"position": Vector3(-10, -1.0, -26), "scale": Vector3(20, 4.5, 15), "color": Color("557056")},
		{"position": Vector3(-30, -1.0, 4), "scale": Vector3(14, 6.0, 16), "color": Color("506b52")},
		{"position": Vector3(8, -1.2, -28), "scale": Vector3(18, 4.0, 12), "color": Color("5d7a5b")},
		{"position": Vector3(24, -1.5, -12), "scale": Vector3(15, 5.0, 14), "color": Color("587358")},
		{"position": Vector3(-18, -1.0, -22), "scale": Vector3(16, 6.0, 12), "color": Color("516c55")},
		# Nearer, lower ridges break the silhouette of the distant hills.
		{"position": Vector3(-26, -1.8, -4), "scale": Vector3(12, 3.4, 10), "color": Color("62805b")},
		{"position": Vector3(-17, -1.8, -14), "scale": Vector3(10, 2.8, 8), "color": Color("69875f")},
		{"position": Vector3(14, -1.8, -20), "scale": Vector3(11, 3.0, 8), "color": Color("5d7a57")},
	]
	for spec in specs:
		var hill := _ellipsoid(spec["scale"], spec["color"], 14, 7)
		hill.position = spec["position"]
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hills.add_child(hill)


## Kept so older callers do not need to change while the chapter is integrated.
func bind_water_surface(_surface: MeshInstance3D) -> void:
	pass


## Water-state visuals are owned by the terrain water meshes; the structural dam
## stays fixed at its crest. The spillway follows the lake surface so the dam
## visibly holds water back and lets it fall downstream.
func set_water_level(level: float) -> void:
	_water_level = level
	_apply_spillway()


func set_dam_state(count: int, _finish: String, recipe_id: String = "legacy_three") -> void:
	var is_mixed := recipe_id == "mixed_fifteen"
	var normalized_progress := clampf(float(count) / 15.0, 0.0, 1.0) if is_mixed else clampf(float(count) / 3.0, 0.0, 1.0)
	_dam_count = clampi(roundi(normalized_progress * 3.0), 0, _dam_logs.size())
	for index in range(_dam_logs.size()):
		_dam_logs[index].visible = not is_mixed and index < _dam_count
		_set_dam_log_material(_dam_logs[index], index == _dam_count - 1 and _dam_count == _dam_logs.size())
	for node in _dam_extra_nodes:
		node.visible = count > 0
	_apply_spillway()
	_apply_dam_foam()


## Authored foam strength for the visible dam: none before the first placement,
## then a restrained 0.5, 0.8 and 1.0 as the structure grows.
func dam_foam_intensity() -> float:
	if _dam_count <= 0:
		return 0.0
	return DAM_FOAM_INTENSITY[mini(_dam_count, DAM_FOAM_INTENSITY.size() - 1)]


## A short expanding foam ring at the downstream face of the dam. Each placement
## presentation owns two rings; older rings are retired first, so repeated calls
## never keep more than six live pulse nodes. Deterministic from the dam span.
func pulse_dam_foam(strength: float = 1.0) -> void:
	if _terrain == null or _layout == null or not is_inside_tree():
		return
	_prune_dam_foam_pulses()
	while _dam_foam_pulses.size() > DAM_FOAM_PULSE_LIMIT - 2:
		_retire_dam_foam_pulse(_dam_foam_pulses[0])
	var span := _layout.dam_span()
	if span.size() < 2:
		return
	var center := _layout.dam_center()
	var spread := clampf(span[0].distance_to(span[1]) * 0.13, 0.30, 0.55)
	var pulse_strength := clampf(strength, 0.1, 2.0)
	last_foam_pulse_strength = pulse_strength
	for _index in range(2):
		var pulse := _available_dam_foam_pulse()
		if pulse == null:
			return
		var pool_index := _dam_foam_pulse_pool.find(pulse)
		var material := pulse.material_override as StandardMaterial3D
		pulse.position = Vector3(
			center.x + (float(pool_index % 2) - 0.5) * spread,
			_terrain.initial_water_level() + 0.03,
			_terrain.dam_z() + 0.36 + 0.06 * float(pool_index % 2)
		)
		pulse.scale = Vector3.ONE * 0.22 * pulse_strength
		material.albedo_color = DAM_FOAM_PULSE_COLOR
		pulse.visible = true
		_dam_foam_pulses.append(pulse)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(pulse, "scale", Vector3.ONE * 1.5 * pulse_strength, DAM_FOAM_PULSE_LIFETIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(pulse, "position:y", pulse.position.y + 0.015, DAM_FOAM_PULSE_LIFETIME)
		tween.tween_property(material, "albedo_color:a", 0.0, DAM_FOAM_PULSE_LIFETIME).set_trans(Tween.TRANS_SINE)
		tween.chain().tween_callback(_finish_dam_foam_pulse.bind(pulse))
		_dam_foam_pulse_tweens[pulse.get_instance_id()] = tween


func _build_dam_foam_pulse_pool() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.20
	torus.outer_radius = 0.30
	for index in range(DAM_FOAM_PULSE_LIMIT):
		var pulse := MeshInstance3D.new()
		pulse.name = "DamFoamPulse%d" % index
		pulse.mesh = torus
		var material := StandardMaterial3D.new()
		material.albedo_color = DAM_FOAM_PULSE_COLOR
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		pulse.material_override = material
		pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pulse.visible = false
		add_child(pulse)
		_dam_foam_pulse_pool.append(pulse)


func _available_dam_foam_pulse() -> MeshInstance3D:
	for pulse in _dam_foam_pulse_pool:
		if not _dam_foam_pulses.has(pulse):
			return pulse
	return null


func _finish_dam_foam_pulse(pulse: MeshInstance3D) -> void:
	_dam_foam_pulses.erase(pulse)
	_dam_foam_pulse_tweens.erase(pulse.get_instance_id())
	_release_dam_foam_pulse(pulse)


## Hide and reset the cached ring for a later placement response.
func _release_dam_foam_pulse(pulse: MeshInstance3D) -> void:
	if not is_instance_valid(pulse):
		return
	pulse.visible = false
	pulse.scale = Vector3.ONE * 0.22
	var material := pulse.material_override as StandardMaterial3D
	material.albedo_color = DAM_FOAM_PULSE_COLOR


func _prune_dam_foam_pulses() -> void:
	var live_pulses: Array[MeshInstance3D] = []
	for pulse in _dam_foam_pulses:
		if is_instance_valid(pulse):
			live_pulses.append(pulse)
	_dam_foam_pulses = live_pulses
	for pulse_id: int in _dam_foam_pulse_tweens.keys():
		if instance_from_id(pulse_id) == null:
			_dam_foam_pulse_tweens.erase(pulse_id)


## Drops an older ring before a newer presentation needs its slot. The running
## tween is killed first so its completion callback cannot act on a freed node.
func _retire_dam_foam_pulse(pulse: MeshInstance3D) -> void:
	_dam_foam_pulses.erase(pulse)
	var pulse_id := pulse.get_instance_id()
	var pulse_tween: Tween = _dam_foam_pulse_tweens.get(pulse_id)
	if pulse_tween != null and pulse_tween.is_valid():
		pulse_tween.kill()
	_dam_foam_pulse_tweens.erase(pulse_id)
	_release_dam_foam_pulse(pulse)


func get_visible_dam_log_count() -> int:
	var visible_count := 0
	for log in _dam_logs:
		if log.visible:
			visible_count += 1
	return visible_count


## Add an original, faceted rock silhouette over an existing obstacle collider.
func add_rock_obstacle(at: Vector3) -> Node3D:
	var rock := Node3D.new()
	rock.name = "RockObstacleVisual"
	rock.position = at
	add_child(rock)
	var boulders: Array[Dictionary] = [
		{"position": Vector3(-0.02, 0.37, -1.9), "size": Vector3(0.88, 0.74, 1.16), "color": Color("798782"), "rotation": Vector3(0.03, 0.08, -0.06)},
		{"position": Vector3(0.03, 0.39, -0.94), "size": Vector3(0.91, 0.78, 1.14), "color": Color("697773"), "rotation": Vector3(-0.04, -0.11, 0.05)},
		{"position": Vector3(-0.04, 0.4, 0.02), "size": Vector3(0.92, 0.8, 1.2), "color": Color("89938b"), "rotation": Vector3(0.02, 0.04, -0.03)},
		{"position": Vector3(0.02, 0.38, 0.98), "size": Vector3(0.9, 0.76, 1.12), "color": Color("727f7b"), "rotation": Vector3(-0.03, 0.1, 0.04)},
		{"position": Vector3(-0.01, 0.36, 1.92), "size": Vector3(0.88, 0.72, 1.12), "color": Color("818c84"), "rotation": Vector3(0.04, -0.06, -0.05)},
	]
	for boulder_spec in boulders:
		var boulder := _ellipsoid(boulder_spec["size"], boulder_spec["color"], 7, 4)
		boulder.position = boulder_spec["position"]
		boulder.rotation = boulder_spec["rotation"]
		boulder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		rock.add_child(boulder)
	return rock


func _build_vegetation() -> void:
	if _terrain == null:
		return
	for spot in [Vector2(-7.5, -3.0), Vector2(-3.5, -8.0)]:
		_add_golden_tree(Vector3(spot.x, _terrain.height_at(spot), spot.y))
	_add_bush(Vector3(5.6, _terrain.height_at(Vector2(5.6, 2.6)), 2.6), 0.9)
	_add_bush(Vector3(5.2, _terrain.height_at(Vector2(5.2, -2.4)), -2.4), 0.82)
	# A sparse line of darker bushes on the far ridge breaks the hard
	# terrain/backdrop join without closing the playable view.
	for spot in [Vector2(-11.0, -13.0), Vector2(-7.0, -14.4), Vector2(1.0, -15.0), Vector2(5.0, -14.0), Vector2(9.0, -12.4)]:
		if _terrain.contains(spot) and _terrain.slope_degrees(spot) < 34.0:
			_add_bush(Vector3(spot.x, _terrain.height_at(spot), spot.y), 1.15)
	# Reeds follow the near lake shore so the water edge reads as a bank rather
	# than a colour boundary. They are decorative and have no collision.
	for spot in [Vector2(-1.9, -4.0), Vector2(-2.4, -5.0), Vector2(-2.9, -2.2), Vector2(-2.7, -5.8), Vector2(-2.2, -1.4), Vector2(-3.0, -6.4)]:
		_add_reeds(Vector3(spot.x, _terrain.height_at(spot), spot.y), 4 if spot.y < -3.0 else 3)
	for spot in [Vector2(-3.1, -2.6), Vector2(-2.5, -6.2), Vector2(-1.6, -5.5)]:
		_add_shore_rock(Vector3(spot.x, _terrain.height_at(spot), spot.y))


func _add_golden_tree(at: Vector3) -> void:
	var tree := GoldenTreeScene.instantiate() as Node3D
	tree.name = "GoldenTree"
	tree.position = at
	tree.scale = Vector3.ONE * GOLDEN_TREE_SCALE
	add_child(tree)


## A bush is one trunk plus up to three leaf clumps. `parent` lets a vegetation
## cluster own its parts; the environment stays the default host. A name prefix
## keeps cluster members addressable instead of relying on generated names, and
## `name_index` keeps two bushes in one cluster from sharing node names.
func _add_bush(center: Vector3, scale_factor: float, parent: Node3D = null, canopy_count: int = 3, name_prefix: String = "", name_index: int = -1) -> void:
	var host: Node3D = parent if parent != null else self
	var name_suffix := "" if name_index < 0 else str(name_index)
	var trunk := _cylinder(0.16 * scale_factor, 0.68 * scale_factor, Color("806044"), 7)
	if not name_prefix.is_empty():
		trunk.name = "%sTrunk%s" % [name_prefix, name_suffix]
	_attach_member(host, trunk, center + Vector3(0, 0.34 * scale_factor, 0))
	var canopies: Array[Vector3] = [Vector3(-0.2, 0.72, 0.03), Vector3(0.16, 0.77, 0.0), Vector3(0.0, 0.99, -0.06)]
	for index in range(clampi(canopy_count, 1, canopies.size())):
		var leaf := _ellipsoid(Vector3(0.42, 0.34, 0.38) * scale_factor, Color("5f9069"), 7, 4)
		if not name_prefix.is_empty():
			leaf.name = "%sLeaf%s%d" % [name_prefix, name_suffix, index]
		_attach_member(host, leaf, center + canopies[index] * scale_factor)


func _add_reeds(center: Vector3, count: int, parent: Node3D = null, name_prefix: String = "") -> void:
	var host: Node3D = parent if parent != null else self
	for index in range(count):
		var angle := float(index) * 2.4
		# A single reed is the authored plant itself; larger groups spread in a
		# loose arc so a shoreline clump reads as reeds instead of one stalk.
		var spread := 0.0 if count == 1 else 1.0
		var x := center.x + cos(angle) * 0.28 * spread
		var z := center.z + sin(angle) * 0.18 * spread
		var ground := _terrain.height_at(Vector2(x, z)) if _terrain != null else center.y
		var stalk := _cylinder(0.035, 0.48 + 0.07 * float(index % 2), Color("6c9b66"), 5)
		if not name_prefix.is_empty():
			stalk.name = "%sStalk%d" % [name_prefix, index]
		_attach_member(host, stalk, Vector3(x, ground + 0.24, z))
		stalk.rotation.z = -0.12 if index % 2 == 0 else 0.12
		var head := _ellipsoid(Vector3(0.07, 0.15, 0.07), Color("c89b58"), 6, 4)
		if not name_prefix.is_empty():
			head.name = "%sHead%d" % [name_prefix, index]
		_attach_member(host, head, Vector3(x, ground + 0.49, z))


## Parent a helper-built part and express its grounded position in the local
## space of the host group, so clusters stay self-contained and correct even if
## VisualEnvironment is ever offset or rotated.
func _attach_member(parent: Node3D, member: MeshInstance3D, at: Vector3) -> void:
	parent.add_child(member)
	member.position = parent.to_local(at)


func _add_shore_rock(at: Vector3) -> void:
	var rock := _ellipsoid(Vector3(0.58, 0.34, 0.48), Color("7d877d"), 8, 4)
	rock.name = "ShoreRock"
	rock.position = at + Vector3(0.0, 0.06, 0.0)
	add_child(rock)


## Rounded stones trace the near waterline, so the bank reads as a shoreline
## instead of only a colour change in the ground. The unit sphere and the
## materials are shared, which keeps 24 stones to one mesh resource.
func _build_bank_stones(parent: Node3D) -> void:
	var stones := Node3D.new()
	stones.name = "BankStones"
	parent.add_child(stones)
	for index in range(BANK_STONE_XZ.size()):
		var xz := BANK_STONE_XZ[index]
		var stone := _scenery_sphere(BANK_STONE_SCALE[index], STONE_COLORS[index % STONE_COLORS.size()], 7, 4)
		stone.name = "BankStone%d" % index
		stone.position = Vector3(xz.x, _terrain.height_at(xz) + 0.034, xz.y)
		stone.rotation.y = BANK_STONE_YAW[index]
		stones.add_child(stone)


## Flat mud lenses on the damp bank. Each one is tilted onto the local ground
## plane, so no edge lifts off the terrain as the bank falls toward the water.
func _build_mud_patches(parent: Node3D) -> void:
	var patches := Node3D.new()
	patches.name = "MudPatches"
	parent.add_child(patches)
	for index in range(MUD_PATCH_XZ.size()):
		var xz := MUD_PATCH_XZ[index]
		var patch := _scenery_sphere(MUD_PATCH_SCALE[index], MUD_COLORS[index % MUD_COLORS.size()], 10, 3)
		patch.name = "MudPatch%d" % index
		patch.basis = _terrain_basis(xz) * Basis.from_scale(MUD_PATCH_SCALE[index])
		patch.position = Vector3(xz.x, _terrain.height_at(xz) + 0.012, xz.y)
		patches.add_child(patch)


## Planted clusters sit on the clearing edges; the middle of the clearing and
## the ground around every task point stay open. Each cluster owns two bushes
## and one reed: every plant root stays within 0.35 m of the centre and every
## part, including the canopies, within 0.45 m.
func _build_vegetation_clusters(parent: Node3D) -> void:
	var clusters := Node3D.new()
	clusters.name = "VegetationClusters"
	parent.add_child(clusters)
	for index in range(CLUSTER_CENTRES.size()):
		var centre := CLUSTER_CENTRES[index]
		var cluster := Node3D.new()
		cluster.name = "Cluster%d" % index
		cluster.position = Vector3(centre.x, _terrain.height_at(centre), centre.y)
		clusters.add_child(cluster)
		var bushes := [
			centre + CLUSTER_BUSH_OFFSETS[index * 2],
			centre + CLUSTER_BUSH_OFFSETS[index * 2 + 1],
		]
		var reed_xz := centre + CLUSTER_REED_OFFSET[index]
		for bush_index in range(bushes.size()):
			var bush_xz: Vector2 = bushes[bush_index]
			_add_bush(Vector3(bush_xz.x, _terrain.height_at(bush_xz), bush_xz.y), CLUSTER_SCALE[index], cluster, 1, "Bush", bush_index)
		_add_reeds(Vector3(reed_xz.x, _terrain.height_at(reed_xz), reed_xz.y), 1, cluster, "Reed")


## Boulder groups frame the enclosing north and west slopes. Each boulder is
## grounded on the terrain under its own footprint, so uneven ground cannot lift
## one off the surface. Shared sphere geometry keeps the 13 boulders to one mesh
## resource.
func _build_outer_rocks(parent: Node3D) -> void:
	var rocks := Node3D.new()
	rocks.name = "OuterRocks"
	parent.add_child(rocks)
	var boulder_serial := 0
	for formation_index in range(OUTER_ROCK_XZ.size()):
		var xz := OUTER_ROCK_XZ[formation_index]
		var formation := Node3D.new()
		formation.name = "OuterRock%d" % formation_index
		formation.position = Vector3(xz.x, _terrain.height_at(xz), xz.y)
		rocks.add_child(formation)
		var boulder_index := 0
		for spec in OUTER_ROCK_BOULDERS:
			if int(spec["formation"]) != formation_index:
				continue
			var offset: Vector3 = spec["offset"]
			var color: Color = BOULDER_COLORS[boulder_serial % BOULDER_COLORS.size()]
			var boulder := _scenery_sphere(spec["size"], color, 7, 4)
			boulder.name = "Boulder%d" % boulder_index
			var boulder_xz := xz + Vector2(offset.x, offset.z)
			var local_ground := _terrain.height_at(boulder_xz) - formation.position.y
			boulder.position = Vector3(offset.x, local_ground + offset.y, offset.z)
			boulder.rotation.y = spec["yaw"]
			boulder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			formation.add_child(boulder)
			boulder_index += 1
			boulder_serial += 1


## Natural ground and scenery for the near bank and the clearing. Visual only:
## it adds no colliders, areas or navigation data.
func _build_natural_scenery() -> void:
	if _terrain == null:
		return
	var scenery := Node3D.new()
	scenery.name = "NaturalScenery"
	add_child(scenery)
	_build_bank_stones(scenery)
	_build_mud_patches(scenery)
	_build_vegetation_clusters(scenery)
	_build_outer_rocks(scenery)


## N2 authored grove. One grounded visual per authored obstacle, read from the
## same layout entry that feeds collision and navigation: boulder clusters for
## boulders, tall trunks with lifted canopies for trunks. The woodland opening
## beyond the grove is a small clearing landmark. All of this is scenery;
## VisualEnvironment adds no physics.
func _build_grove() -> void:
	if _terrain == null or _layout == null:
		return
	var boulder_index := 0
	var tree_index := 0
	for obstacle in _layout.grove_obstacles():
		var xz: Vector2 = obstacle["xz"]
		var visual := Node3D.new()
		visual.position = Vector3(xz.x, float(obstacle["y"]), xz.y)
		var radius := float(obstacle["radius"])
		if obstacle["kind"] == &"trunk":
			visual.name = "GroveTree%d" % tree_index
			tree_index += 1
			_add_grove_tree(visual, radius)
		else:
			visual.name = "GroveBoulder%d" % boulder_index
			boulder_index += 1
			_add_grove_boulder(visual, radius)
		add_child(visual)
	_build_woodland_opening()


## One large faceted stone with smaller chips around it. Sizes and offsets are
## fractions of the authored collision radius, so the group reads as a real rock
## cluster while its footprint stays inside the shape that blocks the actor.
func _add_grove_boulder(host: Node3D, radius: float) -> void:
	var boulders: Array[Dictionary] = [
		{"offset": Vector3(-0.10, 0.56, 0.04), "size": Vector3(1.78, 1.20, 1.90), "color": Color("8a978f"), "yaw": 0.35},
		{"offset": Vector3(0.48, 0.40, -0.30), "size": Vector3(1.02, 0.80, 0.96), "color": Color("96a29a"), "yaw": -0.55},
		{"offset": Vector3(-0.18, 0.29, 0.50), "size": Vector3(0.80, 0.60, 0.76), "color": Color("7d8b84"), "yaw": 1.10},
		{"offset": Vector3(0.28, 0.21, 0.38), "size": Vector3(0.56, 0.46, 0.52), "color": Color("a1aca2"), "yaw": 2.10},
	]
	for index in range(boulders.size()):
		var spec: Dictionary = boulders[index]
		var boulder := _scenery_sphere(spec["size"] * radius, spec["color"], 7, 4)
		boulder.name = "Boulder%d" % index
		boulder.position = spec["offset"] * radius
		boulder.rotation.y = spec["yaw"]
		boulder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		host.add_child(boulder)


## A tall woodland trunk with lifted canopy layers. The trunk rises from the
## authored ground and the lowest foliage stays above 1.8 m, so the boulder
## cluster at the grove's feet reads clearly instead of hiding under a canopy.
func _add_grove_tree(host: Node3D, radius: float) -> void:
	var bark := _scenery_material(Color("6f5138"))
	var trunk_height := 2.60
	var trunk_radius := maxf(radius * 0.42, 0.10)
	var trunk := _cylinder(trunk_radius, trunk_height, Color("6f5138"), 7)
	trunk.name = "Trunk"
	trunk.position = Vector3(0.0, trunk_height * 0.5, 0.0)
	(trunk.mesh as CylinderMesh).material = bark
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	host.add_child(trunk)
	# Two short forks break the single-pole silhouette and carry the crown.
	var forks: Array[Dictionary] = [
		{"from": Vector3(0.02, 1.62, 0.02), "to": Vector3(0.44, 2.44, -0.16)},
		{"from": Vector3(-0.02, 1.50, -0.02), "to": Vector3(-0.36, 2.26, 0.20)},
	]
	for index in range(forks.size()):
		var fork := _stick_between(forks[index]["from"], forks[index]["to"], trunk_radius * 0.55, Color("6f5138"))
		fork.name = "Fork%d" % index
		(fork.mesh as CylinderMesh).material = bark
		fork.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		host.add_child(fork)
	var canopies: Array[Dictionary] = [
		{"offset": Vector3(0.02, 2.62, 0.0), "size": Vector3(1.42, 1.00, 1.36), "color": Color("4f7a52")},
		{"offset": Vector3(0.42, 2.98, -0.14), "size": Vector3(0.96, 0.76, 0.92), "color": Color("5f9069")},
		{"offset": Vector3(-0.36, 2.40, 0.22), "size": Vector3(0.86, 0.68, 0.82), "color": Color("557f58")},
		{"offset": Vector3(0.04, 3.34, 0.06), "size": Vector3(0.66, 0.52, 0.62), "color": Color("6b9a63")},
	]
	for index in range(canopies.size()):
		var spec: Dictionary = canopies[index]
		var canopy := _scenery_sphere(spec["size"], spec["color"], 7, 4)
		canopy.name = "Canopy%d" % index
		canopy.position = spec["offset"]
		canopy.rotation.y = 0.6 * float(index)
		# The crown does not cast: its shadow would fall across the boulders and
		# the opening patch, hiding the very landmark this group exists for.
		canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(canopy)


## A small, collider-free clearing beyond the grove: a flat light-grass patch
## over the walking cell, ringed by ferns and bushes at the perimeter. The
## centre stays open and the plants read as one clearing edge.
func _build_woodland_opening() -> void:
	var opening := _layout.woodland_opening_xz()
	var host := Node3D.new()
	host.name = "WoodlandOpening"
	host.position = Vector3(opening.x, _terrain.height_at(opening), opening.y)
	add_child(host)
	# Soft, opaque light grass: a flattened ellipsoid tilted onto the local
	# ground plane and lifted 0.012 m so its thin edge never sinks into terrain.
	var grass_size := Vector3(1.72, 0.05, 1.64)
	var grass := _scenery_sphere(grass_size, Color("9ab86e"), 14, 3)
	grass.name = "OpeningGrass"
	grass.basis = _terrain_basis(opening) * Basis.from_scale(grass_size)
	grass.position = Vector3(0.0, 0.012, 0.0)
	host.add_child(grass)
	# Five plants sit on an even 0.90 m ring (about 72 degrees apart), so the
	# clearing edge reads as one broken ring with no wide silent gap.
	var ferns: Array[Dictionary] = [
		{"offset": Vector2(0.89, 0.13), "yaw": 0.35, "scale": 1.00},
		{"offset": Vector2(-0.73, 0.53), "yaw": 2.30, "scale": 0.95},
		{"offset": Vector2(0.22, -0.87), "yaw": 4.20, "scale": 1.05},
	]
	for index in range(ferns.size()):
		var spec: Dictionary = ferns[index]
		var offset: Vector2 = spec["offset"]
		var spot := opening + offset
		var at := Vector3(offset.x, _terrain.height_at(spot) - host.position.y, offset.y)
		_add_grove_fern(host, at, float(spec["yaw"]), float(spec["scale"]), "Fern%d" % index)
	var bushes: Array[Dictionary] = [
		{"offset": Vector2(0.22, 0.87), "yaw": 0.70, "scale": 0.64},
		{"offset": Vector2(-0.76, -0.48), "yaw": 2.90, "scale": 0.60},
	]
	for index in range(bushes.size()):
		var spec: Dictionary = bushes[index]
		var offset: Vector2 = spec["offset"]
		var spot := opening + offset
		var bush := Node3D.new()
		bush.name = "Bush%d" % index
		bush.position = Vector3(offset.x, _terrain.height_at(spot) - host.position.y, offset.y)
		bush.rotation.y = float(spec["yaw"])
		host.add_child(bush)
		_add_bush(Vector3(spot.x, _terrain.height_at(spot), spot.y), float(spec["scale"]), bush, 3, "Bush", index)


## One fern rosette: two tapered fronds per wedge, arched upward around a low
## centre tuft. The raised arch keeps the tuft reading as one plant at the
## clearing edge instead of a flat star lying on the grass.
func _add_grove_fern(host: Node3D, at: Vector3, yaw: float, scale_factor: float, node_name: String) -> void:
	var fern := Node3D.new()
	fern.name = node_name
	fern.position = at
	fern.rotation.y = yaw
	host.add_child(fern)
	for index in range(7):
		var angle := TAU * float(index) / 7.0 + 0.25
		for segment in range(2):
			var length := 0.24 + 0.11 * float(segment)
			var reach := 0.12 + 0.18 * float(segment)
			var lift := 0.13 + 0.15 * float(segment)
			var leaf := _scenery_sphere(
				Vector3(length, 0.05, 0.085 - 0.015 * float(segment)) * scale_factor,
				Color("5d8a5c") if index % 2 == 0 else Color("6b9a63"),
				7, 4
			)
			leaf.name = "Frond%d_%d" % [index, segment]
			leaf.position = Vector3(cos(angle) * reach, lift, sin(angle) * reach) * scale_factor
			leaf.rotation = Vector3(0.0, -angle, 0.78 - 0.33 * float(segment))
			fern.add_child(leaf)
	var tuft := _scenery_sphere(Vector3(0.34, 0.22, 0.34) * scale_factor, Color("4f7a52"), 7, 4)
	tuft.name = "Tuft"
	tuft.position = Vector3(0.0, 0.12 * scale_factor, 0.0)
	fern.add_child(tuft)


func _terrain_basis(xz: Vector2) -> Basis:
	return Basis(Quaternion(Vector3.UP, _terrain.normal_at(xz)))


func _build_dam_structure() -> void:
	if _terrain == null or _layout == null:
		return
	var span := _layout.dam_span()
	if span.size() < 2:
		return
	var start: Vector3 = span[0]
	var finish: Vector3 = span[1]
	var center: Vector3 = _layout.dam_center()
	var full_level := _terrain.full_water_level()
	var length := start.distance_to(finish)
	# Three structural cross-logs reach from bank to bank. The lowest sits at
	# the waterline, so the structure is visible before and after the lake fills.
	for index in range(3):
		var log := _cylinder(0.14, length * (1.0 - 0.04 * float(index)), Color("93663f"), 8)
		log.name = "DamProgressLog%d" % index
		log.rotation.z = PI * 0.5
		log.position = Vector3(center.x, full_level + 0.02 + float(index) * 0.13, center.z + 0.035 * float(index))
		log.visible = false
		add_child(log)
		_dam_logs.append(log)

	# Abutments and two inner posts give the dam a supported silhouette instead
	# of a log floating over the channel.
	for index in range(span.size()):
		var end_point: Vector3 = span[index]
		_add_dam_post("DamAbutment%d" % index, Vector3(end_point.x, end_point.y, end_point.z), 0.12, _layout.dam_crest_y() + 0.08)
		_add_dam_mud(Vector3(end_point.x, end_point.y + 0.06, end_point.z), 0.52)
	for side: float in [-1.0, 1.0]:
		var post_x := center.x + side * 2.05
		var post_ground := _terrain.height_at(Vector2(post_x, center.z))
		_add_dam_post("DamPost%s" % ("West" if side < 0.0 else "East"), Vector3(post_x, post_ground, center.z), 0.09, _layout.dam_crest_y() + 0.04)
	_build_dam_brush(center)
	_build_spillway(center)
	_build_dam_foam(center, span)


## Four flat patches at the base of the dam on the downstream side. They sit just
## above the fixed stream level, so they stay visible while the lake rises behind
## the structure, and they only appear once the first placement commits.
func _build_dam_foam(center: Vector3, span: PackedVector3Array) -> void:
	_dam_foam = Node3D.new()
	_dam_foam.name = "DamFoam"
	_dam_foam.visible = false
	add_child(_dam_foam)
	var stream_level := _terrain.initial_water_level() + 0.035
	var patch_spread := clampf(span[0].distance_to(span[1]) * 0.105, 0.45, 0.70)
	for index in range(DAM_FOAM_NAMES.size()):
		var patch := MeshInstance3D.new()
		patch.name = DAM_FOAM_NAMES[index]
		var disc := CylinderMesh.new()
		disc.top_radius = 0.5
		disc.bottom_radius = 0.5
		disc.height = 0.012
		disc.radial_segments = 18
		disc.rings = 1
		var material := StandardMaterial3D.new()
		material.albedo_color = DAM_FOAM_COLORS[index]
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		disc.material = material
		patch.mesh = disc
		patch.position = Vector3(
			center.x + (float(index) - 1.5) * patch_spread,
			stream_level,
			_terrain.dam_z() + DAM_FOAM_DOWNSTREAM_OFFSET + 0.06 * float(index % 2)
		)
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_dam_foam.add_child(patch)
		_dam_foam_patches.append(patch)
	_apply_dam_foam()


## Patch scale and opacity follow `dam_foam_intensity()`, so the foam thickens
## with each placement without adding collision or shadow casters.
func _apply_dam_foam() -> void:
	if _dam_foam == null:
		return
	var intensity := dam_foam_intensity()
	var is_visible := _dam_count > 0
	_dam_foam.visible = is_visible
	for index in range(_dam_foam_patches.size()):
		var patch := _dam_foam_patches[index]
		if patch == null:
			continue
		patch.visible = is_visible
		var base_scale := DAM_FOAM_PATCH_SCALE[index]
		var growth := 0.55 + 0.45 * intensity
		patch.scale = Vector3(base_scale.x * growth, 1.0, base_scale.z * growth)
		var disc := patch.mesh as CylinderMesh
		if disc == null or not disc.material is StandardMaterial3D:
			continue
		var material := disc.material as StandardMaterial3D
		var base_color := DAM_FOAM_COLORS[index]
		material.albedo_color = Color(base_color.r, base_color.g, base_color.b, base_color.a * intensity)


## Brush, stakes and mud turn the three cross-logs into a beaver dam rather
## than a fallen log. All of it appears with the first placement.
func _build_dam_brush(center: Vector3) -> void:
	var brush := Node3D.new()
	brush.name = "DamBrush"
	brush.visible = false
	add_child(brush)
	_dam_extra_nodes.append(brush)
	var crest := _layout.dam_crest_y()
	var span := _layout.dam_span()
	var span_length := span[0].distance_to(span[1]) if span.size() >= 2 else 5.0
	var mud_bank := _ellipsoid(Vector3(span_length * 0.88, 0.42, 0.52), Color("65472d"), 12, 5)
	mud_bank.name = "DamMudBank"
	mud_bank.position = Vector3(center.x, crest - 0.18, center.z + 0.10)
	brush.add_child(mud_bank)
	for index in range(9):
		var x := center.x + (float(index) - 4.0) * 0.62
		var z := center.z + 0.12 + float(index % 3) * 0.08
		var from := Vector3(x, crest + 0.03, z)
		var to := Vector3(x + 0.04 * float(index % 2), crest - 0.18, z + 0.30)
		var stick := _stick_between(from, to, 0.026, Color("8b5d36") if index % 2 == 0 else Color("6f4a2c"))
		brush.add_child(stick)
	for index in range(5):
		var x := center.x + (float(index) - 2.0) * 0.86
		var base := Vector3(x, _terrain.height_at(Vector2(x, center.z)) - 0.15, center.z + 0.02)
		var stake := _stick_between(base, Vector3(x, crest + 0.10, center.z), 0.045, Color("7a5433"))
		brush.add_child(stake)
	for index in range(6):
		var mud := _ellipsoid(Vector3(0.48, 0.18, 0.30), Color("6b4a2f"), 8, 4)
		mud.position = Vector3(center.x + (float(index) - 2.5) * 0.58, crest - 0.02, center.z + 0.16)
		mud.rotation.y = 0.2 * float(index)
		brush.add_child(mud)


func _stick_between(from: Vector3, to: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var stick := _cylinder(radius, from.distance_to(to), color, 6)
	stick.position = (from + to) * 0.5
	stick.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	return stick


func _add_dam_post(node_name: String, base: Vector3, radius: float, top_y: float) -> void:
	var height := maxf(top_y - base.y, 0.12)
	var post := _cylinder(radius, height, Color("7c5737"), 7)
	post.name = node_name
	post.position = Vector3(base.x, base.y + height * 0.5, base.z)
	post.visible = false
	add_child(post)
	_dam_extra_nodes.append(post)


func _add_dam_mud(at: Vector3, scale_factor: float) -> void:
	var mud := _ellipsoid(Vector3(scale_factor, scale_factor * 0.45, scale_factor * 0.85), Color("6b4a2f"), 8, 4)
	mud.name = "DamMud"
	mud.position = at
	mud.visible = false
	add_child(mud)
	_dam_extra_nodes.append(mud)


func _build_spillway(center: Vector3) -> void:
	_spillway = Node3D.new()
	_spillway.name = "DamSpillway"
	_spillway.position = Vector3(center.x, 0.0, center.z + 0.22)
	_spillway.visible = false
	add_child(_spillway)
	for index in range(4):
		var strip := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.09, 0.3, 0.035)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.74, 0.91, 0.97, 0.62 - 0.08 * float(index))
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material = material
		strip.mesh = mesh
		strip.position.x = (float(index) - 1.5) * 0.17
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_spillway.add_child(strip)
		_spillway_strips.append(strip)

	_spill_foam = MeshInstance3D.new()
	_spill_foam.name = "DamSpillFoam"
	var foam := TorusMesh.new()
	foam.inner_radius = 0.32
	foam.outer_radius = 0.46
	var foam_material := StandardMaterial3D.new()
	foam_material.albedo_color = Color(0.86, 0.94, 0.92, 0.65)
	foam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam.material = foam_material
	_spill_foam.mesh = foam
	_spill_foam.position = Vector3(center.x, _terrain.initial_water_level() + 0.04, center.z + 0.7)
	_spill_foam.scale = Vector3(1.0, 1.0, 0.7)
	_spill_foam.visible = false
	_spill_foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spill_foam)


func _apply_spillway() -> void:
	if _spillway == null or _terrain == null:
		return
	var rise := maxf(_water_level - _terrain.initial_water_level(), 0.0)
	var active := _dam_count > 0 and rise > 0.015
	_spillway.visible = active
	_spill_foam.visible = active
	if not active:
		return
	var height := rise + 0.16
	for strip in _spillway_strips:
		var mesh := strip.mesh as BoxMesh
		mesh.size = Vector3(0.09, height, 0.035)
		strip.position.y = _terrain.initial_water_level() + height * 0.5
	_spill_foam.position.y = _terrain.initial_water_level() + 0.04


## The finish is a short accent owned by the world's finish trim; the long
## structural log keeps its timber colour so the choice does not dominate.
func _set_dam_log_material(log: MeshInstance3D, is_final_log: bool) -> void:
	var color := Color("85603a") if is_final_log else Color("93663f")
	var key := "final" if is_final_log else "normal"
	var material: StandardMaterial3D = _dam_log_materials.get(key)
	if material == null:
		material = Shapes.material(color)
		_dam_log_materials[key] = material
	(log.mesh as CylinderMesh).material = material


## Natural-scenery variant of _ellipsoid: one unit SphereMesh per
## (radial_segments, rings) pair is shared by every stone, mud lens and boulder,
## with the authored size applied through the instance scale. Colour reuse goes
## through a material_override cache instead of a material per mesh.
func _scenery_sphere(size: Vector3, color: Color, radial_segments: int, rings: int) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh_key := "%d:%d" % [radial_segments, rings]
	var sphere: SphereMesh = _sphere_meshes.get(mesh_key)
	if sphere == null:
		sphere = SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = radial_segments
		sphere.rings = rings
		_sphere_meshes[mesh_key] = sphere
	mesh_instance.mesh = sphere
	mesh_instance.material_override = _scenery_material(color)
	mesh_instance.scale = size
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance


func _scenery_material(color: Color) -> StandardMaterial3D:
	var material_key := String(color.to_html(false))
	var material: StandardMaterial3D = _scenery_materials.get(material_key)
	if material == null:
		material = Shapes.material(color)
		_scenery_materials[material_key] = material
	return material


func _ellipsoid(size: Vector3, color: Color, radial_segments: int, rings: int) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = radial_segments
	sphere.rings = rings
	sphere.material = Shapes.material(color)
	mesh_instance.mesh = sphere
	mesh_instance.scale = size
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance


func _cylinder(radius: float, height: float, color: Color, segments: int) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * 0.82
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = segments
	cylinder.material = Shapes.material(color)
	mesh_instance.mesh = cylinder
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance

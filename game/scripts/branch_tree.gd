class_name BranchTree
extends Node3D
## E2 interactive tree: a standing GoldenTree that can be gnawed once and falls
## toward its landing. The fall is authored with a tween that pivots at the base;
## there is no rigid body and no physics collision. The tree owns only its
## presentation state: the world persists `tree_cut` and owns the branch.
##
## Standing: the imported GoldenTree is the visual; cream tooth marks sit on the
## work-spot side of the bark, a quiet ground ring advertises the interaction and
## an Area3D on the unique TREE_LAYER covers the trunk and the ring.
##
## Cut: the GoldenTree hides and an authored trunk-plus-crown presentation falls
## over FALL_DURATION. The trunk is a real 2.0 m cylinder that pivots at its cut
## base and finishes horizontal above the terrain; a separate cluster of
## flattened golden spheres travels from the standing canopy to rest on the
## ground beside the trunk, short of the landing. The stump carries the cream
## cut top. No geometry ever leaves the terrain surface.
##
## The world owns when the tree is interactive. `set_interactive()` hides the
## ring, the tooth marks (while standing) and the hit area whenever the dam stage
## cannot use the tree, so a shared query layer can never select it.

const GoldenTreeScene = preload("res://assets/environment/meshy_tree/golden_tree.glb")
## Shared collision-layer contract: 1 terrain, 2 actor, 4 branch, 8 dam target,
## 16 home part, 32 home slot, 64 interactive tree, 128 food target,
## 256 dam crest, 512 food bundle.
const TREE_LAYER: int = 64
const TREE_SCALE: float = 0.68
const FALL_DURATION: float = 1.0
const FALL_DEGREES: float = 90.0
const RING_RADIUS: float = 0.72
const RING_COLOR := Color("c79a62")
const SCAR_COLOR := Color("f0dfb4")
const STUMP_COLOR := Color("8a6238")
const STUMP_HEIGHT: float = 0.32
const STUMP_RADIUS: float = 0.18
const HIT_RADIUS: float = 0.95
const HIT_HEIGHT: float = 1.7
const TRUNK_RADIUS: float = 0.17
const TRUNK_LENGTH: float = 2.0
const TRUNK_COLOR := Color("7d5533")
## The horizontal trunk rests with its lowest bark this far above the ground
## plane at the tree base, which clears the gentle rise toward the landing.
const TRUNK_GROUND_CLEARANCE: float = 0.06
const CROWN_COLOR := Color("d7ab45")
## Largest horizontal reach of the crown cluster, used to stop it short of the
## landing branch instead of covering it.
const CROWN_REACH: float = 0.44
const CROWN_REST_HEIGHT: float = 0.42
const CROWN_STANDING_HEIGHT: float = 1.45
const CROWN_ARC_HEIGHT: float = 0.14
const CROWN_LATERAL_OFFSET: float = 0.32
const CROWN_LANDING_MARGIN: float = 0.30
const CROWN_SQUASH: float = 0.84

enum State { STANDING, CUT }

var state: State = State.STANDING
var stable_id: String = ""
var log_id: String = ""
## Horizontal unit direction the standing trunk falls along.
var fall_direction := Vector3(0.0, 0.0, 1.0)
var pivot: Node3D
var tree_model: Node3D
var ground_ring: MeshInstance3D
var gnaw_scars: Array[MeshInstance3D] = []
var fallen_trunk: MeshInstance3D
var crown: Node3D
var stump: MeshInstance3D
var stump_cut: MeshInstance3D
var hit_area: Area3D
var _fall_tween: Tween
## Authored gate set by the world. The visuals additionally require STANDING.
var _interactive: bool = true
var _fall_angle: float = 0.0
var _landing_distance: float = TRUNK_LENGTH
var _crown_standing_position := Vector3(0.0, CROWN_STANDING_HEIGHT, 0.0)
var _crown_rest_position := Vector3.ZERO


## Places the tree on its authored ground point and aims the fall at the landing.
## Safe to call before or after the node enters the tree.
func configure(at: Vector3, landing_xz: Vector2, tree_identifier: String = "", material_identifier: String = "", authored_fall_direction: Vector3 = Vector3.ZERO) -> void:
	position = at
	stable_id = tree_identifier
	log_id = material_identifier
	var fall := Vector3(landing_xz.x - at.x, 0.0, landing_xz.y - at.z)
	if fall.length_squared() > 0.000001:
		var direction := Vector3(authored_fall_direction.x, 0.0, authored_fall_direction.z)
		fall_direction = direction.normalized() if direction.length_squared() > 0.000001 else fall.normalized()
		_landing_distance = fall.length()


func _ready() -> void:
	_build_parts()
	hit_area = _build_hit_area()
	_compute_crown_pose()
	set_cut(state == State.CUT, false)


func is_cut() -> bool:
	return state == State.CUT


## World-owned interaction gate. The hit area only carries TREE_LAYER while the
## gate is open and the tree still stands.
func set_interactive(active: bool) -> void:
	if _interactive == active:
		return
	_interactive = active
	_apply_presentation()


func is_interactive() -> bool:
	return _interactive and state == State.STANDING


## Current authored fall angle: 0 while standing and 90 once fully fallen.
func fall_angle_degrees() -> float:
	return rad_to_deg(_fall_angle)


## Authored cut. Animated cuts fall over FALL_DURATION; the state and the
## interactive area change immediately, so repeated taps cannot start a second
## cut while the trunk is still moving.
func cut(animate: bool = true) -> void:
	if state == State.CUT:
		return
	set_cut(true, animate)


## Immediate apply path used by restore. Never emits a sound, never saves and
## never calls back into the world.
func set_cut(cut_now: bool, animate: bool = false) -> void:
	_stop_fall()
	if cut_now:
		state = State.CUT
		_apply_presentation()
		if animate and is_inside_tree():
			_apply_fall_progress(0.0)
			_fall_tween = create_tween()
			_fall_tween.tween_method(_apply_fall_progress, 0.0, 1.0, FALL_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_fall_tween.tween_callback(func() -> void: _apply_fall_progress(1.0))
		else:
			_apply_fall_progress(1.0)
		return
	state = State.STANDING
	_apply_fall_progress(0.0)
	_apply_presentation()


func _build_parts() -> void:
	pivot = Node3D.new()
	pivot.name = "FallPivot"
	add_child(pivot)
	tree_model = GoldenTreeScene.instantiate() as Node3D
	tree_model.name = "GoldenTree"
	tree_model.scale = Vector3.ONE * TREE_SCALE
	pivot.add_child(tree_model)
	fallen_trunk = _build_fallen_trunk()
	pivot.add_child(fallen_trunk)
	_add_gnaw_scars()
	crown = _build_crown()
	add_child(crown)
	ground_ring = _build_ground_ring()
	stump = _build_stump()
	stump_cut = _build_stump_cut()


func _build_ground_ring() -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = "TreeGroundRing"
	var torus := TorusMesh.new()
	torus.inner_radius = RING_RADIUS * 0.86
	torus.outer_radius = RING_RADIUS
	var material := StandardMaterial3D.new()
	material.albedo_color = RING_COLOR
	material.roughness = 0.9
	torus.material = material
	ring.mesh = torus
	ring.position.y = 0.035
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	return ring


## Three flattened cream wedges on the work-spot side of the bark. They pivot
## with the trunk, so after the fall they still sit on the fallen log.
func _add_gnaw_scars() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = SCAR_COLOR
	material.roughness = 0.6
	var marks: Array[Vector2] = [
		Vector2(-40.0, 0.24),
		Vector2(0.0, 0.35),
		Vector2(40.0, 0.46),
	]
	for mark_index in range(marks.size()):
		var mark := marks[mark_index]
		var angle := deg_to_rad(mark.x)
		var scar := MeshInstance3D.new()
		scar.name = "GnawMark"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.07, 0.09, 0.14)
		mesh.material = material
		scar.mesh = mesh
		scar.position = Vector3(cos(angle) * 0.165, mark.y, sin(angle) * 0.165)
		scar.rotation.y = -angle
		scar.rotation.z = deg_to_rad(-12.0 + 6.0 * float(mark_index))
		scar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(scar)
		gnaw_scars.append(scar)


## A real trunk that shares the fall pivot. Its base sits at the pivot, so the
## 90 degree rotation lays the whole 2.0 m log on the landing side.
func _build_fallen_trunk() -> MeshInstance3D:
	var trunk := MeshInstance3D.new()
	trunk.name = "TreeFallenTrunk"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = TRUNK_RADIUS * 0.86
	cylinder.bottom_radius = TRUNK_RADIUS
	cylinder.height = TRUNK_LENGTH
	var material := StandardMaterial3D.new()
	material.albedo_color = TRUNK_COLOR
	material.roughness = 0.95
	cylinder.material = material
	trunk.mesh = cylinder
	trunk.position.y = TRUNK_LENGTH * 0.5
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	trunk.visible = false
	return trunk


## Two or three flattened golden spheres make a readable stylised crown without
## importing a second canopy mesh. The vertical scale squashes slightly as it
## settles on the ground.
func _build_crown() -> Node3D:
	var node := Node3D.new()
	node.name = "TreeCrown"
	var material := StandardMaterial3D.new()
	material.albedo_color = CROWN_COLOR
	material.roughness = 0.8
	var parts: Array[Dictionary] = [
		{"name": "TreeCrownCore", "radius": 0.36, "height": 0.40, "offset": Vector3.ZERO},
		{"name": "TreeCrownLobeA", "radius": 0.27, "height": 0.32, "offset": Vector3(0.17, -0.02, 0.10)},
		{"name": "TreeCrownLobeB", "radius": 0.25, "height": 0.30, "offset": Vector3(-0.15, -0.01, -0.11)},
	]
	for part in parts:
		var lobe := MeshInstance3D.new()
		lobe.name = String(part["name"])
		var sphere := SphereMesh.new()
		sphere.radius = float(part["radius"])
		sphere.height = float(part["height"])
		sphere.material = material
		lobe.mesh = sphere
		lobe.position = part["offset"]
		lobe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(lobe)
	node.position = _crown_standing_position
	return node


func _build_stump() -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TreeStump"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = STUMP_RADIUS * 0.88
	cylinder.bottom_radius = STUMP_RADIUS
	cylinder.height = STUMP_HEIGHT
	var material := StandardMaterial3D.new()
	material.albedo_color = STUMP_COLOR
	material.roughness = 0.95
	cylinder.material = material
	mesh_instance.mesh = cylinder
	mesh_instance.position.y = STUMP_HEIGHT * 0.5
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)
	mesh_instance.visible = false
	return mesh_instance


func _build_stump_cut() -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TreeStumpCut"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = STUMP_RADIUS * 0.88
	cylinder.bottom_radius = STUMP_RADIUS * 0.88
	cylinder.height = 0.02
	var material := StandardMaterial3D.new()
	material.albedo_color = SCAR_COLOR
	material.roughness = 0.8
	cylinder.material = material
	mesh_instance.mesh = cylinder
	mesh_instance.position.y = STUMP_HEIGHT + 0.005
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	mesh_instance.visible = false
	return mesh_instance


## One area covers the trunk and the quiet ring, so the whole readable tree
## footprint is selectable without becoming a walking obstacle.
func _build_hit_area() -> Area3D:
	var area := Area3D.new()
	area.name = "TreeHitArea"
	area.collision_layer = TREE_LAYER if is_interactive() else 0
	area.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = HIT_RADIUS
	shape.height = HIT_HEIGHT
	collision.shape = shape
	collision.position.y = HIT_HEIGHT * 0.5
	area.add_child(collision)
	add_child(area)
	return area


## Single source of visible parts. The ring only exists while the tree is
## interactive; scars stay on the fallen log but never advertise a standing tree
## that the current stage cannot use.
func _apply_presentation() -> void:
	var standing := state == State.STANDING
	var selectable := _interactive and standing
	if tree_model != null:
		tree_model.visible = standing
	if ground_ring != null:
		ground_ring.visible = selectable
	for scar in gnaw_scars:
		scar.visible = selectable or not standing
	if fallen_trunk != null:
		fallen_trunk.visible = not standing
	if crown != null:
		crown.visible = not standing
	_stump_visible(not standing)
	if hit_area != null:
		hit_area.collision_layer = TREE_LAYER if selectable else 0


func _stump_visible(shown: bool) -> void:
	if stump != null:
		stump.visible = shown
	if stump_cut != null:
		stump_cut.visible = shown


## Resting crown and standing canopy positions derived from the authored fall
## distance. The cluster stops CROWN_LANDING_MARGIN before the landing and keeps
## its centre inside the authored 60-70 percent band.
func _compute_crown_pose() -> void:
	var lateral := Vector3.UP.cross(fall_direction)
	if lateral.length_squared() < 0.000001:
		lateral = Vector3.RIGHT
	lateral = lateral.normalized()
	var rest_distance := minf(0.65 * _landing_distance, _landing_distance - CROWN_LANDING_MARGIN - CROWN_REACH)
	rest_distance = maxf(rest_distance, 0.0)
	_crown_rest_position = fall_direction * rest_distance + lateral * CROWN_LATERAL_OFFSET + Vector3.UP * CROWN_REST_HEIGHT
	_crown_standing_position = Vector3(0.0, CROWN_STANDING_HEIGHT, 0.0)
	if crown != null:
		crown.position = _crown_standing_position


## One authored pose for every fall progress value. The pivot lifts by exactly
## the bark radius at the current angle plus a small clearance, so the cylinder
## never cuts into the terrain while it sweeps down.
func _apply_fall_progress(progress: float) -> void:
	var clamped := clampf(progress, 0.0, 1.0)
	_fall_angle = deg_to_rad(FALL_DEGREES) * clamped
	if pivot != null:
		var axis := Vector3.UP.cross(fall_direction)
		if axis.length_squared() < 0.000001:
			axis = Vector3.RIGHT
		pivot.basis = Basis(axis.normalized(), _fall_angle)
		var lift := TRUNK_RADIUS * sin(_fall_angle) + TRUNK_GROUND_CLEARANCE * clamped
		pivot.position = Vector3(0.0, lift, 0.0)
	if crown != null:
		var crown_position := _crown_standing_position.lerp(_crown_rest_position, clamped)
		crown_position.y += CROWN_ARC_HEIGHT * sin(PI * clamped)
		crown.position = crown_position
		crown.scale = Vector3(1.0, lerpf(1.0, CROWN_SQUASH, clamped), 1.0)


func _stop_fall() -> void:
	if _fall_tween != null and _fall_tween.is_valid():
		_fall_tween.kill()
	_fall_tween = null
